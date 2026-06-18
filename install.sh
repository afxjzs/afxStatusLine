#!/bin/bash
# Installer for afxStatusLine.
# Copies statusline.sh into ~/.claude/ and merges the statusLine key into
# ~/.claude/settings.json (preserving any existing settings).
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"
SCRIPT_DEST="${CLAUDE_DIR}/statusline.sh"
SETTINGS="${CLAUDE_DIR}/settings.json"

command -v jq >/dev/null 2>&1 || { echo "Error: jq is required but not installed." >&2; exit 1; }

mkdir -p "$CLAUDE_DIR"

echo "Installing statusline.sh -> $SCRIPT_DEST"
cp "${SRC_DIR}/statusline.sh" "$SCRIPT_DEST"
chmod +x "$SCRIPT_DEST"

STATUSLINE_JSON='{"statusLine":{"type":"command","command":"~/.claude/statusline.sh","padding":2,"refreshInterval":1}}'

if [ -f "$SETTINGS" ]; then
  echo "Merging statusLine key into existing $SETTINGS"
  tmp="$(mktemp)"
  jq -s '.[0] * .[1]' "$SETTINGS" <(echo "$STATUSLINE_JSON") > "$tmp"
  mv "$tmp" "$SETTINGS"
else
  echo "Creating $SETTINGS"
  echo "$STATUSLINE_JSON" | jq . > "$SETTINGS"
fi

echo "Done. Restart Claude Code (or start a new session) to see the status line."
