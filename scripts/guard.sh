#!/usr/bin/env bash
set -euo pipefail

STATE="${USAGE_GUARD_STATE:-$HOME/.claude/usage-guard/state.json}"
THRESHOLD="${USAGE_GUARD_THRESHOLD:-98}"
MODE="${USAGE_GUARD_MODE:-wait}"
MAX_WAIT="${USAGE_GUARD_MAX_WAIT:-19800}"
STALE_AFTER="${USAGE_GUARD_STALE_AFTER:-900}"
BUFFER="${USAGE_GUARD_RESET_BUFFER:-60}"

command -v jq >/dev/null 2>&1 || exit 0
[ -f "$STATE" ] || exit 0

now=$(date +%s)
mtime=$(stat -c %Y "$STATE" 2>/dev/null || stat -f %m "$STATE" 2>/dev/null) || exit 0
if (( now - mtime > STALE_AFTER )); then
  exit 0
fi

pct=$(jq -r '.rate_limits.five_hour.used_percentage // empty' "$STATE" 2>/dev/null || true)
resets=$(jq -r '.rate_limits.five_hour.resets_at // empty' "$STATE" 2>/dev/null || true)
[ -n "$pct" ] || exit 0

pct_int=${pct%.*}
if (( pct_int < THRESHOLD )); then
  exit 0
fi

deny() {
  local reason="$1"
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "$reason"
  }
}
EOF
  exit 0
}

if [ "$MODE" = "block" ] || [ -z "$resets" ] || [ "$resets" = "null" ]; then
  reset_h=""
  if [ -n "$resets" ] && [ "$resets" != "null" ]; then
    reset_h=$(date -d "@$resets" '+%H:%M' 2>/dev/null || date -r "$resets" '+%H:%M' 2>/dev/null || echo "$resets")
  fi
  deny "usage-guard: 5-hour usage is at ${pct}% (threshold ${THRESHOLD}%). Pause work until the window resets${reset_h:+ at $reset_h}. Do not retry tool calls until then; summarise progress for the user instead."
fi

wait_s=$(( resets - now + BUFFER ))
if (( wait_s <= 0 )); then
  rm -f "$STATE"
  exit 0
fi
if (( wait_s > MAX_WAIT )); then
  wait_s=$MAX_WAIT
fi

echo "usage-guard: 5h window at ${pct}% >= ${THRESHOLD}%. Pausing ${wait_s}s until reset..." >&2
sleep "$wait_s"

rm -f "$STATE"
exit 0
