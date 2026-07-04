#!/usr/bin/env bash
set -euo pipefail

STATE="${USAGE_GUARD_STATE:-$HOME/.claude/usage-guard/state.json}"
STALE_AFTER="${USAGE_GUARD_STALE_AFTER:-900}"

command -v jq >/dev/null 2>&1 || exit 0
[ -f "$STATE" ] || exit 0

now=$(date +%s)
mtime=$(stat -c %Y "$STATE" 2>/dev/null || stat -f %m "$STATE" 2>/dev/null) || exit 0
(( now - mtime > STALE_AFTER )) && exit 0

p5=$(jq -r '.rate_limits.five_hour.used_percentage // empty' "$STATE" 2>/dev/null || true)
r5=$(jq -r '.rate_limits.five_hour.resets_at // empty' "$STATE" 2>/dev/null || true)
p7=$(jq -r '.rate_limits.seven_day.used_percentage // empty' "$STATE" 2>/dev/null || true)
[ -n "$p5" ] || exit 0

fmt_time() {
  [ -n "$1" ] && [ "$1" != "null" ] || { echo "unknown"; return; }
  date -d "@$1" '+%a %H:%M' 2>/dev/null || date -r "$1" '+%a %H:%M' 2>/dev/null || echo "$1"
}

echo "[usage-guard] Subscription usage: 5h window ${p5}% used (resets $(fmt_time "$r5")); 7d window ${p7:-?}% used. If the 5h window is above ~90%, prefer finishing or checkpointing the current step over starting large new work."
exit 0
