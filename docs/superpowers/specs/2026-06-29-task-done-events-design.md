# Task-aware done events: `task-done`, `your-turn`, stdin-based coalescing

## Goal

A long-running, multi-agent job currently pops a `done` card every time a
background agent finishes. Make `done` fire **once, when all work is done**, add
an opt-in **`task-done`** card for per-agent progress, and split the final stop
into **`done`** (deliverable) vs **`your-turn`** (Claude is handing back to you).

Also replaces the fragile coalescing source: the hook reads the **undocumented**
`pendingBackgroundAgentCount` from the *transcript*; the documented signal is the
`background_tasks` array delivered in the Stop hook's **stdin** (Claude Code
v2.1.145+; confirmed on 2.1.195).

## Why the current coalescing is wrong

`notify-fire.sh` suppresses `done` when the transcript's last `turn_duration`
record has `pendingBackgroundAgentCount` matching `^[1-9]`. That field is
undocumented, and its `1` was already read two ways: `notify-context.sh` treats
`1` as "main thread alone, zero subagents" (subtracts 1 for the badge), while the
coalescing treats `1` as "still busy → suppress". In real sessions the value sits
at `1` for the whole run, so `done` is suppressed in ordinary single-thread work.
The off-by-one disappears entirely once we key off `background_tasks` length.

## Event model

| Event         | Trigger                                                            | Default | Mascot          |
|---------------|-------------------------------------------------------------------|---------|-----------------|
| `done`        | `Stop`; `background_tasks` + `session_crons` empty; last msg not a hand-off | built-in | walk + confetti |
| `your-turn`   | `Stop`; both empty; last msg **is** a hand-off                     | built-in | walk + flag     |
| `task-done`   | `SubagentStop`; tasks still remain                                 | opt-in  | walk + gym      |
| `needs-input` | `Notification` hook (unchanged)                                   | built-in | walk + flag     |

## Signal sources (hook wiring)

`~/.claude/settings.json` hooks (all call the repo `notify-fire.sh`):

| Hook event     | Command arg   | Notes                                  |
|----------------|---------------|----------------------------------------|
| `Stop`         | `done`        | resolves to `done` or `your-turn`      |
| `SubagentStop` | `task-done`   | **new** hook wiring                    |
| `Notification` | `needs-input` | unchanged                              |
| `SessionStart` | (capture)     | unchanged                              |

The Stop and SubagentStop payloads carry `background_tasks` (array of
`{id,type,status,description,agent_type,…}`), `session_crons`, and
`last_assistant_message` on stdin — no transcript parsing needed for coalescing.

## Control flow

### `notify-fire.sh` — `done` (from `Stop`)

1. Parse `background_tasks` and `session_crons` lengths from stdin (`$INPUT`).
2. If **either is non-empty** → an intermediate wake; `exit 0` (suppress). The
   final Stop, when both are empty, fires the card.
3. Both empty → run the **hand-off heuristic** on `last_assistant_message`:
   resolve event to `your-turn` (hand-off) or `done`. Continue to render.

### `notify-fire.sh` — `task-done` (from `SubagentStop`)

Always proceed to launch `show-notification.ps1 -Event task-done`. The opt-in
suppression lives in PowerShell (below), so the bash hook needs no JSONC parsing.

### Hand-off heuristic

`last_assistant_message`, trimmed of trailing whitespace and markdown
punctuation, is a hand-off when **any** holds:

- ends with `?`
- matches (case-insensitive) one of: `let me know`, `want me to`, `which do you`,
  `should i`, `your call`, `up to you`, `over to you`.

A pure-bash function (`is_handoff`) so it is unit-testable without PowerShell.
The phrase list lives in one place; tuning it is a one-line edit.

## Suppression semantics (opt-in events)

`Resolve-Event` gains a **disabled** result:

- Event has a built-in default (`done`, `your-turn`, `needs-input`) → always
  resolves normally.
- Event has **no** default (`task-done`) and is **absent or literally `false`**
  in `settings.json` → resolves to a `disabled` marker.

`show-notification.ps1`: when `Resolve-Event` returns `disabled`, `exit 0` before
building the window (no card, no sound, no PID marker). `task-done` is therefore
silent until the user adds a full block; `events.task-done: false` is the same as
absent.

## New body/footer tokens (task-done)

From the `SubagentStop` stdin payload, gathered in `notify-context.sh`:

| Token           | Resolves to                                            |
|-----------------|--------------------------------------------------------|
| `{{remaining}}` | count of `background_tasks` still running              |
| `{{agent_type}}`| the finishing agent's `agent_type` (e.g. `Explore`)    |
| `{{task}}`      | the finishing agent's `description` / last message     |

Existing tokens stay valid in any event. A line whose tokens all resolve empty is
dropped (unchanged behavior).

## Built-in defaults (notify-lib.ps1)

`Get-NotifyDefaults`:

- add **`your-turn`**: needs-input-like (label e.g. `Your turn`, accent reused,
  `mascot { move: walk, end: flag }`, sound `exclamation`, body `{{folder}}`).
- **no** `task-done` default — opt-in only.

`Resolve-Event`: events absent from defaults resolve to `disabled` instead of
falling back to `done` (current behavior silently mis-renders an unknown event as
`done`).

## Settings + schema

- `settings.json` — add a `your-turn` block; ship `task-done: false` with an
  example enabled block in an adjacent `//` comment.
- `settings.schema.json` — add `your-turn` and `task-done` event shapes
  (`task-done` accepts `false` **or** an event block); document new tokens.
- `~/.claude/settings.json` — add the `SubagentStop` hook.

## README

Document: the four events and their triggers; the `SubagentStop` hook line;
`task-done` opt-in (`false`/absent = silent); the hand-off heuristic for
`your-turn`; the three new tokens.

## Testing

New bash harness `tests/notify-fire.Tests.sh` (stubs `powershell.exe`, as
`tests/run.sh` does) for the hook-logic cases; PowerShell cases extend
`tests/notify-lib.Tests.ps1`.

| Test                                              | File                          |
|---------------------------------------------------|-------------------------------|
| coalescing: non-empty `background_tasks` → suppress; empty → fire | `tests/notify-fire.Tests.sh`  |
| `is_handoff`: `?`/phrases → 1; plain deliverable → 0 | `tests/notify-fire.Tests.sh`  |
| new tokens from a `SubagentStop` fixture          | `tests/notify-context.Tests.sh` |
| `Resolve-Event`: `task-done` absent/`false` → disabled; block → enabled | `tests/notify-lib.Tests.ps1` |
| `Resolve-Event`: `your-turn` default present       | `tests/notify-lib.Tests.ps1` |

Fixtures: a `Stop` stdin with empty vs non-empty `background_tasks`; a
`SubagentStop` stdin with `agent_type` + remaining tasks.

## Known boundaries (not fixed now)

- `task-done` keys off `SubagentStop`, so it fires for **subagent**-type tasks
  (parallel agents, workflow agents). Pure shell / `&` background tasks still get
  a correct final `done`, just no per-task card.
- The hand-off heuristic is best-effort (~80%); there is no official stop-reason
  signal. Misfires degrade gracefully (`your-turn` vs `done` — both are cards).
- `background_tasks` requires Claude Code ≥ 2.1.145. Older versions: the array is
  absent → both lengths read 0 → every Stop fires `done` (i.e. no coalescing, the
  pre-feature behavior), never a wrong suppression.
