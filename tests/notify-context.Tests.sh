#!/usr/bin/env bash
# Tests notify-context.sh token gathering against fixtures.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIX="$ROOT/tests/fixtures"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cp "$FIX/transcript.jsonl" "$TMP/transcript.jsonl"
# Use a non-git cwd so repo/dirty are deterministically empty.
mkdir -p /tmp/notify-ctx-test
STDIN="$(sed "s#TRANSCRIPT_PATH#$TMP/transcript.jsonl#" "$FIX/stdin-needs-input.json")"

OUT="$(printf '%s' "$STDIN" | bash "$ROOT/notify-context.sh" needs-input)"
fail=0
g() { jq -r "$1" <<<"$OUT"; }
check() { if [[ "$(g "$2")" == "$3" ]]; then echo "ok: $1"; else echo "FAIL: $1 -> [$(g "$2")]"; fail=1; fi; }

check "folder"        '.folder'         'notify-ctx-test'
check "message"       '.message'        'Claude needs your permission to use Bash'
check "branch"        '.branch'         'main'
check "model"         '.model'          'claude-sonnet-4'
check "last_prompt"   '.last_prompt'    'fix the flag mascot'
check "last_assistant" '.last_assistant' 'All done with the flag.'
check "agents blank when zero" '.agents' ''
check "event"         '.event'          'needs-input'
check "permission"    '.permission_mode' 'default'

# "1 agent" is the main thread alone; the badge counts only subagents (count - 1).
agents_for() {
  local count="$1"
  local trf="$TMP/tr-$count.jsonl"
  sed "s#\"pendingBackgroundAgentCount\":0#\"pendingBackgroundAgentCount\":$count#" "$TMP/transcript.jsonl" >"$trf"
  printf '%s' "$STDIN" | sed "s#$TMP/transcript.jsonl#$trf#" | bash "$ROOT/notify-context.sh" needs-input | jq -r '.agents'
}
checke() { if [[ "$(agents_for "$2")" == "$3" ]]; then echo "ok: $1"; else echo "FAIL: $1 -> [$(agents_for "$2")]"; fail=1; fi; }
checke "agents blank when one"  1 ''
checke "agents subtracts one"   2 '1'
checke "agents subtracts one (many)" 5 '4'

exit $fail
