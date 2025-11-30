#!/bin/bash
#
# Claude Code Status Line
# Shows git info, Dart version, and coverage
#
# Target: < 2 seconds execution time
#

# Read input from Claude Code
input=$(cat)
dir=$(echo "$input" | jq -r '.workspace.current_dir' 2>/dev/null)
git_root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || echo "$dir")

# ANSI colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
RESET='\033[0m'

# Temp files for parallel execution
tmp_dir=$(mktemp -d)
trap "rm -rf $tmp_dir" EXIT

# Run version check in background
{
    v=$(dart --version 2>/dev/null | awk '{print $4}')
    echo "${v:-?}" > "$tmp_dir/dart"
} &

# Git info (fast, run in main thread)
branch=$(git -C "$git_root" branch --show-current 2>/dev/null || echo "?")
diff_stat=$(git -C "$git_root" diff --shortstat 2>/dev/null)

# Parse insertions/deletions from git diff
insertions=$(echo "$diff_stat" | grep -oE '[0-9]+ insertion' | awk '{print $1}')
deletions=$(echo "$diff_stat" | grep -oE '[0-9]+ deletion' | awk '{print $1}')
insertions=${insertions:-0}
deletions=${deletions:-0}

# Calculate coverage from lcov.info
calc_coverage() {
    local lcov_file="$git_root/coverage/lcov.info"

    if [[ ! -f "$lcov_file" ]]; then
        echo "no data|0|0"
        return
    fi

    lf=$(grep "^LF:" "$lcov_file" | cut -d: -f2 | awk '{sum+=$1} END {print sum+0}')
    lh=$(grep "^LH:" "$lcov_file" | cut -d: -f2 | awk '{sum+=$1} END {print sum+0}')

    if [[ $lf -eq 0 ]]; then
        echo "no data|0|0"
        return
    fi

    pct=$(awk "BEGIN { printf \"%.1f\", ($lh * 100 / $lf) }")
    echo "$pct|$lh|$lf"
}

coverage_result=$(calc_coverage)
cov_pct=$(echo "$coverage_result" | cut -d'|' -f1)
cov_lh=$(echo "$coverage_result" | cut -d'|' -f2)
cov_lf=$(echo "$coverage_result" | cut -d'|' -f3)

# Wait for background version check
wait

# Read version result
dart_v=$(cat "$tmp_dir/dart" 2>/dev/null || echo "?")

# Color the coverage based on percentage
if [[ "$cov_pct" == "no data" ]]; then
    cov_color="$GRAY"
    cov_display="no data"
elif (( $(echo "$cov_pct >= 100" | bc -l 2>/dev/null || echo 0) )); then
    cov_color="$GREEN"
    cov_display="${cov_lh}/${cov_lf} (${cov_pct}%)"
elif (( $(echo "$cov_pct >= 80" | bc -l 2>/dev/null || echo 0) )); then
    cov_color="$YELLOW"
    cov_display="${cov_lh}/${cov_lf} (${cov_pct}%)"
else
    cov_color="$RED"
    cov_display="${cov_lh}/${cov_lf} (${cov_pct}%)"
fi

# Build status line with colored git changes
printf "${CYAN}%s${RESET} (" "$branch"
if [[ $deletions -gt 0 ]]; then
    printf "${RED}-%s${RESET}" "$deletions"
else
    printf "${GRAY}-%s${RESET}" "$deletions"
fi
printf "/"
if [[ $insertions -gt 0 ]]; then
    printf "${GREEN}+%s${RESET}" "$insertions"
else
    printf "${GRAY}+%s${RESET}" "$insertions"
fi
printf ") | "
printf "dart ${BLUE}%s${RESET} | " "$dart_v"
printf "cov ${cov_color}%s${RESET}\n" "$cov_display"
