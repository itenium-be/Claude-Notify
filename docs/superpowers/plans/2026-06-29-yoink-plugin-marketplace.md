# Yoink Plugin + Marketplace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Yoink installable as a Claude Code plugin from a marketplace hosted in the same repo, without breaking the existing WSL/PowerShell notification behavior.

**Architecture:** One repo = marketplace + plugin (source `./`). Two roots: `${CLAUDE_PLUGIN_ROOT}` (scripts/sounds/bundled defaults, overwritten on update) and `~/.claude/yoink/` (user `settings.json`, sessions, log, sound overrides — survives updates). Hooks declared in `hooks/hooks.json` via exec form.

**Tech Stack:** Claude Code plugin manifests (JSON), bash hooks, PowerShell renderer, existing bash test harness.

---

### Task 1: Fix the test harness hook path

**Files:**
- Modify: `tests/run.sh` (line `HOOKS="$HOME/.claude/hooks"`)

- [ ] **Step 1:** Point `HOOKS` at the repo's own `hooks/` dir so the hook tests exercise the real scripts:
  ```bash
  HOOKS="$(cd "$(dirname "$0")/.." && pwd)/hooks"
  ```
- [ ] **Step 2:** Run `bash tests/run.sh` — the 6 previously-failing hook tests now run (and pass against current scripts).
- [ ] **Step 3:** Commit: `fix(tests): point harness at repo hooks dir`

---

### Task 2: Add plugin + marketplace manifests

**Files:**
- Create: `.claude-plugin/marketplace.json`
- Create: `.claude-plugin/plugin.json`
- Create: `hooks/hooks.json`

- [ ] **Step 1:** Write `.claude-plugin/marketplace.json`, `.claude-plugin/plugin.json`, `hooks/hooks.json` (contents per spec, exec-form hooks with `${CLAUDE_PLUGIN_ROOT}`).
- [ ] **Step 2:** Validate JSON parses: `for f in .claude-plugin/*.json hooks/hooks.json; do jq . "$f" >/dev/null && echo "ok $f"; done`
- [ ] **Step 3:** If `claude` CLI available: `claude plugin validate .` (best-effort; note if unavailable).
- [ ] **Step 4:** Commit: `feat: add plugin and marketplace manifests`

---

### Task 3: Split plugin-root vs user-dir in the hooks

**Files:**
- Modify: `hooks/notify-fire.sh`
- Modify: `hooks/notify-capture.sh`

- [ ] **Step 1:** In both scripts add `PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"`. Keep `YOINK_DIR="${YOINK_DIR:-$HOME/.claude/yoink}"` as the state/settings dir.
- [ ] **Step 2:** Resolve `show-notification.ps1`, `capture-window.ps1`, `notify-context.sh` from `$PLUGIN_ROOT` (keep `YOINK_PS_SHOW` / `YOINK_PS_CAPTURE` env overrides for tests).
- [ ] **Step 3:** In `notify-fire.sh`, pass the user dir to PowerShell: append `-SettingsDir "$(wslpath -w "$YOINK_DIR" 2>/dev/null)"`.
- [ ] **Step 4:** Run `bash tests/run.sh` — all hook tests still pass (new `-SettingsDir` arg is additive; existing greps unaffected).
- [ ] **Step 5:** Commit: `feat(hooks): separate plugin root from user state dir`

---

### Task 4: Load user settings + sounds with bundled fallback

**Files:**
- Modify: `notify-lib.ps1` (`Get-NotifyConfig`)
- Modify: `show-notification.ps1` (param block, config load line 51, sound path line 80)

- [ ] **Step 1:** Extend `Get-NotifyConfig([string]$Dir, [string]$UserDir = "")`: if `$UserDir/settings.json` exists, load it; else fall back to `$Dir/settings.json`; else built-in defaults. Backward compatible (optional 2nd arg).
- [ ] **Step 2:** Add `[string]$SettingsDir = ""` to `show-notification.ps1` param block. Change config load to `Get-NotifyConfig $PSScriptRoot $SettingsDir`.
- [ ] **Step 3:** Sound override: after computing bundled `$sndPath`, if `$SettingsDir` and `$SettingsDir/sounds/$sndFile` exists, use that instead.
- [ ] **Step 4:** Run `pwsh`/`powershell.exe` notify-lib tests via `bash tests/run.sh` — settings model test still passes.
- [ ] **Step 5:** Commit: `feat: prefer user settings dir over bundled defaults`

---

### Task 5: README install instructions

**Files:**
- Modify: `README.md`

- [ ] **Step 1:** Replace the manual `~/.claude/settings.json` "Wire up" block with the two install commands; keep manual wiring as a "without the plugin (dev)" note. Document `~/.claude/yoink/settings.json` and the editor copy-out flow.
- [ ] **Step 2:** Commit: `docs: plugin install instructions`

---

## Verification

- `bash tests/run.sh` → all pass.
- `jq` parses all three new JSON files.
- `claude plugin validate .` if available.
- Manual: `echo '{"session_id":"t","cwd":"/x"}' | bash hooks/notify-fire.sh done` runs without error using the `PLUGIN_ROOT` fallback.
