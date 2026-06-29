# Yoink as a Claude Code marketplace + plugin

## Goal

Make Yoink installable with two commands instead of hand-editing
`~/.claude/settings.json`:

```
/plugin marketplace add itenium-be/Yoink
/plugin install yoink@yoink-marketplace
```

Scope is **packaging only** — no file moves, no behavior changes beyond what
plugin distribution requires. The repo serves as *both* the marketplace and the
single plugin, sourced from its root.

## Key constraint: surviving plugin updates

A plugin installed via marketplace lives under
`~/.claude/plugins/cache/...` and is **overwritten on every update**. Yoink's
`settings.json` (theme choice, custom sounds) must therefore not live in the
install dir. Two distinct roots:

| Root                       | Holds                                                              | Lifecycle                     |
|----------------------------|-------------------------------------------------------------------|-------------------------------|
| `${CLAUDE_PLUGIN_ROOT}`    | scripts, `lib/`, bundled `sounds/`, bundled default `settings.json` | overwritten on plugin update  |
| `~/.claude/yoink/`         | user `settings.json`, `sessions/`, `notify.log`, optional `sounds/` overrides | never touched by updates       |

## Architecture

One repo, two manifests under `.claude-plugin/`. Nothing moves on disk; the
existing `hooks/`, root PowerShell scripts, `lib/`, `sounds/`, `mascots/`, the
Pages site, and `pages.yml` stay where they are.

### Data flow

1. Claude Code fires a hook → runs `${CLAUDE_PLUGIN_ROOT}/hooks/notify-*.sh`
   (exec form, so the path passes as one arg with no quoting).
2. The bash script resolves `PLUGIN_ROOT` (install dir, for scripts/sounds) and
   `YOINK_DIR` (user dir, for state + settings) separately.
3. It invokes `show-notification.ps1` from `PLUGIN_ROOT`, passing the user dir's
   Windows path as `-SettingsDir`.
4. `show-notification.ps1` loads settings: user `settings.json` if present →
   bundled default (`$PSScriptRoot`) → built-in defaults. Sounds resolve user
   `sounds/` first, then bundled.

## New files

### `.claude-plugin/marketplace.json`
```json
{
  "name": "yoink-marketplace",
  "owner": { "name": "itenium", "url": "https://github.com/itenium-be" },
  "plugins": [{ "name": "yoink", "source": "./" }]
}
```

### `.claude-plugin/plugin.json`
```json
{
  "name": "yoink",
  "version": "1.0.0",
  "description": "Themed Windows/WSL notifications for Claude Code — unicorn, sakura, dragon, Matrix & more.",
  "author": { "name": "itenium", "email": "wouter.van.schandevijl@itenium.be" },
  "homepage": "https://itenium-be.github.io/Yoink/",
  "hooks": "./hooks/hooks.json"
}
```
`name` is the only required field; `version` is pinned so users aren't
auto-bumped to every commit SHA.

### `hooks/hooks.json`
Exec form — recommended for `${CLAUDE_PLUGIN_ROOT}` plus a literal event arg.
```json
{
  "hooks": {
    "SessionStart": [{ "hooks": [{ "type": "command", "command": "bash",
      "args": ["${CLAUDE_PLUGIN_ROOT}/hooks/notify-capture.sh"] }] }],
    "Stop": [{ "hooks": [{ "type": "command", "command": "bash",
      "args": ["${CLAUDE_PLUGIN_ROOT}/hooks/notify-fire.sh", "done"] }] }],
    "Notification": [{ "hooks": [{ "type": "command", "command": "bash",
      "args": ["${CLAUDE_PLUGIN_ROOT}/hooks/notify-fire.sh", "needs-input"] }] }]
  }
}
```

## Edited files

1. **`hooks/notify-fire.sh`**, **`hooks/notify-capture.sh`** — split the roots:
   - `PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"`
     (fallback keeps manual/dev runs working outside a plugin install).
   - `YOINK_DIR="${YOINK_DIR:-$HOME/.claude/yoink}"` now means **state only**.
   - Resolve `show-notification.ps1`, `capture-window.ps1`, `notify-context.sh`
     from `PLUGIN_ROOT`.
   - Pass `wslpath -w "$YOINK_DIR"` to `show-notification.ps1` as `-SettingsDir`.

2. **`show-notification.ps1`** — add `-SettingsDir` param. Prefer user
   `settings.json` there; else bundled (`$PSScriptRoot`); else built-in. Sound
   lookup: user `sounds/` first, then bundled `sounds/`.

3. **`notify-lib.ps1`** — extend `Get-NotifyConfig` to take the user dir with a
   bundled-default fallback (built-in defaults remain the final fallback). ~3 lines.

## Unchanged

`lib/`, `mascots/`, `sounds/`, the Pages site, `pages.yml`, and
**`settings-editor.ps1`** (a dev tool that still writes next to itself). README
documents the flow: run the editor in a checkout, then copy the resulting
`settings.json` into `~/.claude/yoink/`.

## README changes

Replace the manual `~/.claude/settings.json` hook-wiring block with the two
install commands. Keep the manual wiring as a "run without the plugin (dev)"
note. Document the user config dir `~/.claude/yoink/settings.json` and the
editor copy-out flow.

## Testing / verification

- `/plugin validate .` — validates both manifests.
- Manual dev run: `bash hooks/notify-fire.sh done` (uses the `PLUGIN_ROOT`
  fallback) still produces a notification.
- Existing `tests/run.sh` continues to pass.
- End-to-end: install from a local marketplace
  (`/plugin marketplace add ./`), confirm a real session fires a card and that a
  user `~/.claude/yoink/settings.json` overrides the bundled default.

## Out of scope

- Cross-platform (macOS/Linux native) notifications.
- Moving scripts into a nested plugin subdir.
- Changing where `settings-editor.ps1` writes.
