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
r7=$(jq -r '.rate_limits.seven_day.resets_at // empty' "$STATE" 2>/dev/null || true)
[ -n "$p5" ] || exit 0

fmt_left() {
  local ts=${1%.*}
  [ -n "$ts" ] && [ "$ts" != "null" ] || return 0
  local diff=$(( ts - now ))
  if (( diff < 0 )); then diff=0; fi
  local d=$(( diff / 86400 ))
  local h=$(( (diff % 86400) / 3600 ))
  local m=$(( (diff % 3600) / 60 ))
  if (( d > 0 )); then
    printf '%dd %dh' "$d" "$h"
  elif (( h > 0 )); then
    printf '%dh %dm' "$h" "$m"
  else
    printf '%dm' "$m"
  fi
}

fmt_clock() {
  [ -n "$1" ] && [ "$1" != "null" ] || return 0
  date -d "@${1%.*}" '+%a %H:%M' 2>/dev/null || date -r "${1%.*}" '+%a %H:%M' 2>/dev/null || true
}

seg() {
  local dur clock
  dur=$(fmt_left "$1")
  clock=$(fmt_clock "$1")
  if [ -n "$dur" ] && [ -n "$clock" ]; then
    printf ', resets in %s (%s)' "$dur" "$clock"
  elif [ -n "$dur" ]; then
    printf ', resets in %s' "$dur"
  elif [ -n "$clock" ]; then
    printf ', resets %s' "$clock"
  fi
}

echo "[usage-guard] Subscription usage: 5h window ${p5}% used$(seg "$r5"); 7d window ${p7:-?}% used$(seg "$r7"). If the 5h window is above ~90%, prefer finishing or checkpointing the current step over starting large new work."
exit 0
