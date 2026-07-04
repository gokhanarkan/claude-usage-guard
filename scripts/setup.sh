#!/usr/bin/env bash
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/capture-statusline.sh"
DEST_DIR="$HOME/.claude/usage-guard"
DEST="$DEST_DIR/capture-statusline.sh"
SETTINGS="$HOME/.claude/settings.json"

command -v jq >/dev/null 2>&1 || { echo "usage-guard: jq is required, install it and re-run."; exit 1; }
[ -f "$SRC" ] || { echo "usage-guard: could not find capture-statusline.sh next to setup.sh."; exit 1; }

mkdir -p "$DEST_DIR"
cp "$SRC" "$DEST"
chmod +x "$DEST"

existing=""
[ -f "$SETTINGS" ] && existing=$(jq -r '.statusLine.command // ""' "$SETTINGS")

if [ -n "$existing" ] && ! printf '%s' "$existing" | grep -q "capture-statusline.sh"; then
  echo "usage-guard: you already have a statusline:"
  echo "  $existing"
  echo "usage-guard: leaving it untouched. To run both, set your statusLine command to:"
  echo "  USAGE_GUARD_INNER_STATUSLINE='<your current command>' bash $DEST"
  exit 0
fi

[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
tmp="${SETTINGS}.tmp.$$"
jq --arg cmd "bash $DEST" '.statusLine = {type: "command", command: $cmd}' "$SETTINGS" > "$tmp" && mv -f "$tmp" "$SETTINGS"

echo "usage-guard: statusline wired to $DEST"
echo "usage-guard: restart Claude Code, or it takes effect on the next statusline tick."
