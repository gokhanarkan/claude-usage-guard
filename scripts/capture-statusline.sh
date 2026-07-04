#!/usr/bin/env bash
set -euo pipefail

STATE="${USAGE_GUARD_STATE:-$HOME/.claude/usage-guard/state.json}"
INNER="${USAGE_GUARD_INNER_STATUSLINE:-}"

input=$(cat)

if command -v jq >/dev/null 2>&1; then
  mkdir -p "$(dirname "$STATE")"
  tmp="${STATE}.tmp.$$"
  if echo "$input" | jq '{rate_limits: .rate_limits, captured_at: now}' > "$tmp" 2>/dev/null; then
    mv -f "$tmp" "$STATE"
  else
    rm -f "$tmp"
  fi
fi

if [ -n "$INNER" ]; then
  echo "$input" | eval "$INNER"
  exit 0
fi

if command -v jq >/dev/null 2>&1; then
  now=$(date +%s)
  model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
  ctx=$(echo "$input" | jq -r '.context_window.used_percentage // empty' | cut -d. -f1)
  p5=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' | cut -d. -f1)
  r5=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
  p7=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' | cut -d. -f1)
  r7=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

  fmt_left() {
    local ts=${1%.*}
    [ -n "$ts" ] || return 0
    local diff=$(( ts - now ))
    if (( diff < 0 )); then diff=0; fi
    local d=$(( diff / 86400 ))
    local h=$(( (diff % 86400) / 3600 ))
    local m=$(( (diff % 3600) / 60 ))
    if (( d > 0 )); then
      printf '%dd %dh left' "$d" "$h"
    elif (( h > 0 )); then
      printf '%dh %dm left' "$h" "$m"
    else
      printf '%dm left' "$m"
    fi
  }

  out="$model"
  [ -n "$ctx" ] && out="$out | ctx ${ctx}%"
  if [ -n "$p5" ]; then
    out="$out | 5h ${p5}%"
    left5=$(fmt_left "$r5")
    [ -n "$left5" ] && out="$out ($left5)"
  fi
  if [ -n "$p7" ]; then
    out="$out | 7d ${p7}%"
    left7=$(fmt_left "$r7")
    [ -n "$left7" ] && out="$out ($left7)"
  fi
  echo "$out"
else
  echo "usage-guard: install jq for usage capture"
fi
