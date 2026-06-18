#!/bin/bash
# Claude Code status line.
# Line 1: [Model] 🖥️ host 📁 dir | 🌿 branch | 🪙 tokens | ⏱️ elapsed
# Line 2: <context bar> NN% | ⚡ 5h usage | 📅 7d usage
#         (the ⚡/📅 usage gauges appear only on Pro/Max, after the 1st API call)
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

# Subscription rate limits (absent until the first API response; "// empty" => blank)
FIVE_PCT=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
FIVE_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
WEEK_PCT=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
WEEK_RESET=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; MAGENTA='\033[35m'; RESET='\033[0m'

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

# Color a 0-100 usage value: green <70, yellow 70-89, red >=90
pct_color() {
    if [ "$1" -ge 90 ]; then printf '%s' "$RED"
    elif [ "$1" -ge 70 ]; then printf '%s' "$YELLOW"
    else printf '%s' "$GREEN"; fi
}

# Human countdown to an epoch timestamp, e.g. "2h13m" / "47m"
fmt_reset() {
    [ -z "$1" ] && { printf '?'; return; }
    local diff=$(( $1 - $(date +%s) ))
    [ "$diff" -lt 0 ] && diff=0
    local d=$((diff / 86400)) h=$(((diff % 86400) / 3600)) m=$(((diff % 3600) / 60))
    if [ "$d" -gt 0 ]; then printf '%dd%dh' "$d" "$h"
    elif [ "$h" -gt 0 ]; then printf '%dh%dm' "$h" "$m"
    else printf '%dm' "$m"; fi
}

# Build the usage segment only when the subscription data is present
USAGE=""
if [ -n "$FIVE_PCT" ]; then
    FP=$(printf '%.0f' "$FIVE_PCT")
    WARN=""; [ "$FP" -ge 90 ] && WARN="⚠️ "
    USAGE="${WARN}⚡ $(pct_color "$FP")5h ${FP}%${RESET} (↻ $(fmt_reset "$FIVE_RESET"))"
fi
if [ -n "$WEEK_PCT" ]; then
    WP=$(printf '%.0f' "$WEEK_PCT")
    [ -n "$USAGE" ] && USAGE="$USAGE | "
    USAGE="${USAGE}📅 $(pct_color "$WP")7d ${WP}%${RESET} (↻ $(fmt_reset "$WEEK_RESET"))"
fi

LINE1="${CYAN}[$MODEL]${RESET} ${GREEN}🖥️ ${HOST}${RESET} 📁 ${DIR##*/}${BRANCH} | 🪙 ${TOKENS} | ⏱️ ${MINS}m ${SECS}s"
LINE2="${BAR_COLOR}${BAR}${RESET} ${PCT}%"
[ -n "$USAGE" ] && LINE2="${LINE2} | ${USAGE}"

echo -e "$LINE1"
echo -e "$LINE2"
