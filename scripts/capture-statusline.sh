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
  model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
  ctx=$(echo "$input" | jq -r '.context_window.used_percentage // empty' | cut -d. -f1)
  p5=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' | cut -d. -f1)
  p7=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' | cut -d. -f1)
  out="$model"
  [ -n "$ctx" ] && out="$out | ctx ${ctx}%"
  [ -n "$p5" ] && out="$out | 5h ${p5}%"
  [ -n "$p7" ] && out="$out | 7d ${p7}%"
  echo "$out"
else
  echo "usage-guard: install jq for usage capture"
fi
