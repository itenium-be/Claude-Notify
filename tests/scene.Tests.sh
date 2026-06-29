#!/usr/bin/env bash
# Emits XAML for a scened theme and a plain theme; asserts the scene Canvas is
# present only for the scened one. Swaps settings.json aside (restored on exit),
# mirroring show-notification.Tests.sh, so it never depends on the live config.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
S="$ROOT/settings.json"
BAK="$(mktemp)"; HAD=0
if [[ -f "$S" ]]; then HAD=1; cp "$S" "$BAK"; fi
restore() { if [[ "$HAD" == 1 ]]; then cp "$BAK" "$S"; else rm -f "$S"; fi; rm -f "$BAK"; }
trap restore EXIT

emit() { powershell.exe -NoProfile -ExecutionPolicy Bypass \
  -File "$(wslpath -w "$ROOT/show-notification.ps1")" -Event done -EmitXaml | tr -d '\r'; }

fail=0
check() { if eval "$2"; then echo "ok: $1"; else echo "FAIL: $1"; fail=1; fi; }

# Scened theme -> Canvas present
cat > "$S" <<'JSON'
{ "activeTheme": "t", "themes": { "t": { "scene": { "kind": "waves" } } } }
JSON
GOT="$(emit)"
check "scened theme emits scene Canvas" "grep -q 'x:Name=\"scene\"' <<<\"\$GOT\""

# Plain theme -> no Canvas
cat > "$S" <<'JSON'
{ "activeTheme": "t", "themes": { "t": {} } }
JSON
GOT="$(emit)"
check "plain theme omits scene Canvas" "! grep -q 'x:Name=\"scene\"' <<<\"\$GOT\""

exit $fail
