# Notification context — what we can inject

Everything the `done` / `needs-input` notification can surface, and where it comes from.
Three sources, cheapest first: **hook stdin** (already piped into `notify-fire.sh`), the
**transcript JSONL** (`transcript_path` from stdin), and the **session record** we write at
SessionStart (`sessions/$SID.json`).

## 1. Hook stdin — free, no parsing

`notify-fire.sh` already does `INPUT="$(cat)"`. Claude Code feeds these fields on stdin.

| Field              | Events            | Value / example                                              |
|--------------------|-------------------|--------------------------------------------------------------|
| `session_id`       | Stop, Notification| `366d60dc-…` — key into the session record                   |
| `cwd`              | Stop, Notification| `/mnt/c/temp/notify` — `folder` is just its basename         |
| `transcript_path`  | Stop, Notification| Path to the session JSONL — unlocks everything in §2         |
| `hook_event_name`  | Stop, Notification| `Stop` or `Notification`                                     |
| `permission_mode`  | Stop, Notification| `auto` / `default` / `plan` / `acceptEdits`                  |
| `message`          | **Notification**  | The literal reason — see below. The single best field for the `needs-input` card |
| `stop_hook_active` | **Stop**          | `true` when the Stop hook itself re-triggered                |

`message` text is one of (Claude-Code-authored, not customizable):
- `Claude needs your permission to use <Tool>`
- `Claude is waiting for your input`

> `notification_type` is documented but currently unreliable (often missing) —
> [anthropics/claude-code#11964]. Branch on `message` text instead.

[anthropics/claude-code#11964]: https://github.com/anthropics/claude-code/issues/11964

## 2. Transcript JSONL — parse `transcript_path`

`TR="$(jq -r '.transcript_path' <<<"$INPUT")"`. One JSON object per line. Read the **tail**;
`tail -1` of a filtered stream is the latest. Highest-value fields:

| What                    | jq                                                                                                  |
|-------------------------|-----------------------------------------------------------------------------------------------------|
| Last user prompt        | `jq -r 'select(.type=="last-prompt").lastPrompt' "$TR" \| tail -1`                                   |
| Last assistant message  | `jq -r 'select(.type=="assistant").message.content[]?\|select(.type=="text").text' "$TR" \| tail -1`|
| Model id                | `jq -r 'select(.type=="assistant").message.model' "$TR" \| tail -1`                                 |
| Git branch              | `jq -r 'select(.gitBranch!=null).gitBranch' "$TR" \| tail -1`                                       |
| CC version              | `jq -r 'select(.version!=null).version' "$TR" \| tail -1`                                           |
| Permission mode         | `jq -r 'select(.permissionMode!=null).permissionMode' "$TR" \| tail -1`                             |
| Background agents live  | `jq -r 'select(.pendingBackgroundAgentCount!=null).pendingBackgroundAgentCount' "$TR" \| tail -1`   |
| Pending tool name       | `jq -r 'select(.type=="assistant").message.content[]?\|select(.type=="tool_use").name' "$TR"\|tail -1`|

Notes / footguns:
- **Last user prompt**: prefer the dedicated `last-prompt` record over filtering `user`
  messages — `user` entries also include tool-results and meta turns.
- **Last assistant message**: assistant content is a block array; filter `type=="text"`
  (a turn that ended on a `tool_use` has no trailing text — fall back to the previous one).
- The newest assistant record also carries `durationMs` (last API call), `requestId`,
  `messageId` if ever useful.

## 3. Session record — `sessions/$SID.json`

Written by `notify-capture.sh` at SessionStart; currently `{hwnd, cwd}`. This is *our* file —
anything we want stable for the session's lifetime (start time, terminal title, initial
prompt) can be stashed here and read back at fire time.

## 4. Derived from `cwd`

| What        | How                                                                 |
|-------------|---------------------------------------------------------------------|
| Folder      | `basename "$cwd"` (already shown)                                    |
| Git branch  | transcript (§2), or `git -C "$cwd" branch --show-current`            |
| Repo name   | `basename "$(git -C "$cwd" rev-parse --show-toplevel)"`             |
| Dirty state | `git -C "$cwd" status --porcelain` (non-empty = uncommitted changes) |

## Suggested body per event

- **needs-input**: `message` (the reason) → headline; folder + branch → subline;
  last user prompt → muted detail.
- **done**: last assistant message → headline (what just finished); folder + branch → subline;
  background-agent count if `> 0` ("3 agents still running").
