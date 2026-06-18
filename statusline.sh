#!/bin/bash
# Claude Code status line.
# Line 1: [Model] 🖥️ host 📁 dir | 🌿 branch
# Line 2: <context bar> NN% | 🪙 used/total tokens | ⏱️ elapsed
input=$(cat)

# Hardcoded machine label
HOST="nexus"

MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
IN_TOK=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
OUT_TOK=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
WIN=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')

CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; MAGENTA='\033[35m';
RESET='\033[0m'

# Threshold-based color for the context bar
if [ "$PCT" -ge 90 ]; then BAR_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"; fi

# 10-char progress bar: filled = █, empty = ░
FILLED=$((PCT / 10)); EMPTY=$((10 - FILLED))
printf -v FILL "%${FILLED}s"; printf -v PAD "%${EMPTY}s"
BAR="${FILL// /█}${PAD// /░}"

# Tokens currently in context vs window size, formatted compactly (e.g. 84k, 1.0M)
fmt() {
    local n=$1
    if [ "$n" -ge 1000000 ]; then printf '%d.%dM' $((n / 1000000)) $(((n % 1000000) / 100000))
    elif [ "$n" -ge 1000 ]; then printf '%dk' $((n / 1000))
    else printf '%d' "$n"; fi
}
USED_TOK=$((IN_TOK + OUT_TOK))
TOKENS="$(fmt "$USED_TOK")/$(fmt "$WIN")"

# Elapsed wall-clock time
MINS=$((DURATION_MS / 60000)); SECS=$(((DURATION_MS % 60000) / 1000))

# Git branch (only when inside a repo)
BRANCH=""
git rev-parse --git-dir > /dev/null 2>&1 && BRANCH=" | 🌿 $(git branch --show-current 2>/dev/null)"

echo -e "${CYAN}[$MODEL]${RESET} ${GREEN}🖥️ ${HOST}${RESET} 📁 ${DIR##*/}$BRANCH"
echo -e "${BAR_COLOR}${BAR}${RESET} ${PCT}% | 🪙 ${TOKENS} | ⏱️ ${MINS}m ${SECS}s"
