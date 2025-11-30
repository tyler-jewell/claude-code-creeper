#!/bin/bash
# Parallel Migration Verification with Profiling
# Runs each migration in parallel worktrees with token/time profiling
#
# Usage: .claude/ai_automation_scripts/verify-migrations.sh [--model=haiku]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
MIGRATIONS_DIR="$PROJECT_DIR/.claude/creeper/migrations"
TRANSCRIPTS_DIR="$PROJECT_DIR/.claude/creeper/transcripts"
WORKTREES_DIR="/tmp/creeper-worktrees"
RESULTS_DIR="/tmp/creeper-results"
MODEL="haiku"

# Parse args
for arg in "$@"; do
    case $arg in
        --model=*) MODEL="${arg#*=}" ;;
    esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "═══════════════════════════════════════════════════════════════"
echo "  PARALLEL MIGRATION VERIFICATION"
echo "═══════════════════════════════════════════════════════════════"
echo "Model: $MODEL"
echo ""

START_TIME=$(date +%s)

# Clean up
rm -rf "$WORKTREES_DIR" "$RESULTS_DIR"
mkdir -p "$WORKTREES_DIR" "$RESULTS_DIR"

# Get migrations (skip baseline)
MIGRATIONS=$(ls "$MIGRATIONS_DIR"/*.json 2>/dev/null | grep -v baseline.json || true)
MIGRATION_COUNT=$(echo "$MIGRATIONS" | grep -c . || echo 0)

if [[ "$MIGRATION_COUNT" -eq 0 ]]; then
    echo -e "${RED}No migrations found${NC}"
    exit 1
fi

echo "Found $MIGRATION_COUNT migrations - running in parallel"
echo ""

# Run each migration in parallel worktree
PIDS=()
for migration in $MIGRATIONS; do
    name=$(basename "$migration" .json)
    worktree="$WORKTREES_DIR/$name"
    result_file="$RESULTS_DIR/$name.json"
    log_file="$RESULTS_DIR/$name.log"

    echo -e "${CYAN}Starting: $name${NC}"

    (
        cd "$PROJECT_DIR"

        # Create worktree
        git worktree remove -f "$worktree" 2>/dev/null || true
        git worktree add -q "$worktree" HEAD 2>/dev/null

        cd "$worktree"

        # Reset to baseline
        bash "$PROJECT_DIR/.claude/ai_automation_scripts/hard-reset-claude-code.sh" --confirm > /dev/null 2>&1

        # Get transcript
        transcript=$(jq -r '.transcript' "$migration")
        transcript_path="$TRANSCRIPTS_DIR/$transcript"

        if [[ ! -f "$transcript_path" ]]; then
            echo '{"error":"transcript not found","passed":false}' > "$result_file"
            exit 1
        fi

        # Run migration (auto-apply enabled for testing)
        migration_start=$(date +%s)

        dart run "$PROJECT_DIR/bin/creeper.dart" test \
            --transcript="$transcript_path" \
            --model="$MODEL" \
            --auto-apply \
            "$worktree" > "$log_file" 2>&1 || true

        migration_end=$(date +%s)
        duration=$((migration_end - migration_start))

        # Extract tokens from JSON output
        input_tokens=$(grep -o '"inputTokens":[0-9]*' "$log_file" 2>/dev/null | tail -1 | grep -o '[0-9]*' || echo 0)
        output_tokens=$(grep -o '"outputTokens":[0-9]*' "$log_file" 2>/dev/null | tail -1 | grep -o '[0-9]*' || echo 0)
        cached_tokens=$(grep -o '"cacheReadInputTokens":[0-9]*' "$log_file" 2>/dev/null | tail -1 | grep -o '[0-9]*' || echo 0)

        # Verify results based on migration's verify spec
        verify=$(jq -r '.verify // {}' "$migration")
        all_pass=true

        # Check CLAUDE.md contains
        if [[ $(echo "$verify" | jq 'has("claude_md_contains")') == "true" ]]; then
            for term in $(echo "$verify" | jq -r '.claude_md_contains[]' 2>/dev/null); do
                if ! grep -q "$term" "$worktree/CLAUDE.md" 2>/dev/null; then
                    all_pass=false
                fi
            done
        fi

        # Check hooks created
        if [[ $(echo "$verify" | jq -r '.hooks_created // false') == "true" ]]; then
            if [[ -z "$(ls "$worktree/.claude/hooks/"*.sh 2>/dev/null)" ]]; then
                all_pass=false
            fi
        fi

        # Check command created
        if [[ $(echo "$verify" | jq -r '.command_created // false') == "true" ]]; then
            if [[ -z "$(ls "$worktree/.claude/commands/"*.md 2>/dev/null | grep -v test.md)" ]]; then
                all_pass=false
            fi
        fi

        # Check CLAUDE.md commands table updated
        if [[ $(echo "$verify" | jq -r '.claude_md_commands_table_updated // false') == "true" ]]; then
            # Check if Commands table has any entries (more than just the header)
            # Allow for backticks around command: | `/cmd` | or | /cmd |
            if ! grep -qE '^\| [`]?/' "$worktree/CLAUDE.md" 2>/dev/null; then
                all_pass=false
            fi
        fi

        # Check settings.json has hooks
        if [[ $(echo "$verify" | jq -r '.settings_json_has_hooks // false') == "true" ]]; then
            if [[ $(jq '.hooks | keys | length' "$worktree/.claude/settings.json" 2>/dev/null) == "0" ]]; then
                all_pass=false
            fi
        fi

        # Check changelog updated
        if [[ $(echo "$verify" | jq -r '.changelog_updated // false') == "true" ]]; then
            if [[ $(grep -c "^##" "$worktree/.claude/CHANGELOG.md" 2>/dev/null) -lt 2 ]]; then
                all_pass=false
            fi
        fi

        # Save result
        cat > "$result_file" <<EOF
{
  "migration": "$name",
  "duration_seconds": $duration,
  "input_tokens": ${input_tokens:-0},
  "output_tokens": ${output_tokens:-0},
  "cached_tokens": ${cached_tokens:-0},
  "passed": $all_pass
}
EOF
    ) &

    PIDS+=($!)
done

# Wait for all to complete
echo ""
echo "Waiting for parallel execution..."
for pid in "${PIDS[@]}"; do
    wait "$pid" || true
done

# Aggregate results
END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  RESULTS"
echo "═══════════════════════════════════════════════════════════════"
echo ""

PASS=0
FAIL=0
TOTAL_INPUT=0
TOTAL_OUTPUT=0
TOTAL_CACHED=0

for result in "$RESULTS_DIR"/*.json; do
    [[ -f "$result" ]] || continue

    name=$(jq -r '.migration' "$result")
    passed=$(jq -r '.passed' "$result")
    duration=$(jq -r '.duration_seconds' "$result")
    input=$(jq -r '.input_tokens // 0' "$result")
    output=$(jq -r '.output_tokens // 0' "$result")
    cached=$(jq -r '.cached_tokens // 0' "$result")

    TOTAL_INPUT=$((TOTAL_INPUT + input))
    TOTAL_OUTPUT=$((TOTAL_OUTPUT + output))
    TOTAL_CACHED=$((TOTAL_CACHED + cached))

    if [[ "$passed" == "true" ]]; then
        echo -e "${GREEN}✓${NC} $name (${duration}s | in:$input out:$output cache:$cached)"
        ((PASS++))
    else
        echo -e "${RED}✗${NC} $name (${duration}s | in:$input out:$output cache:$cached)"
        ((FAIL++))
        # Show what was created
        worktree="$WORKTREES_DIR/$name"
        echo "    CLAUDE.md reminders: $(grep -c '^-' "$worktree/CLAUDE.md" 2>/dev/null || echo 0)"
        echo "    Hooks: $(ls "$worktree/.claude/hooks/"*.sh 2>/dev/null | wc -l | tr -d ' ')"
        echo "    Commands: $(ls "$worktree/.claude/commands/"*.md 2>/dev/null | grep -v test.md | wc -l | tr -d ' ')"
    fi
done

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  PROFILING"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Total Time:    ${TOTAL_TIME}s (parallel)"
echo "Migrations:    $MIGRATION_COUNT"
echo "Passed:        $PASS"
echo "Failed:        $FAIL"
echo ""
echo "Tokens:"
echo "  Input:       $TOTAL_INPUT"
echo "  Output:      $TOTAL_OUTPUT"
echo "  Cached:      $TOTAL_CACHED"
echo "  Total:       $((TOTAL_INPUT + TOTAL_OUTPUT + TOTAL_CACHED))"
echo ""

# Claude Grading with Sonnet
echo "═══════════════════════════════════════════════════════════════"
echo "  CLAUDE GRADING (sonnet)"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Collect all migration outputs for grading (do this before cleanup)
GRADE_INPUT=""
for result in "$RESULTS_DIR"/*.json; do
    [[ -f "$result" ]] || continue
    name=$(jq -r '.migration' "$result")
    worktree="$WORKTREES_DIR/$name"

    GRADE_INPUT+="=== Migration: $name ===\n"
    GRADE_INPUT+="CLAUDE.md:\n$(cat "$worktree/CLAUDE.md" 2>/dev/null | head -50)\n\n"
    GRADE_INPUT+="settings.json:\n$(cat "$worktree/.claude/settings.json" 2>/dev/null)\n\n"
    GRADE_INPUT+="Hooks:\n$(ls "$worktree/.claude/hooks/"*.sh 2>/dev/null || echo 'none')\n\n"
    GRADE_INPUT+="Commands:\n$(ls "$worktree/.claude/commands/"*.md 2>/dev/null || echo 'none')\n\n"
    GRADE_INPUT+="CHANGELOG:\n$(cat "$worktree/.claude/CHANGELOG.md" 2>/dev/null)\n\n"
done

# Skip grading if no worktree data was collected
if [[ -z "$GRADE_INPUT" ]]; then
    echo "No migration data to grade (worktrees may be empty)"
    GRADE_RESULT='{"score": 0, "reasoning": "no data collected"}'
else
    # Use Claude to grade with structured output
    GRADE_PROMPT="You are grading Claude Code automation migrations.

For each migration, evaluate:
1. Did it update CLAUDE.md correctly?
2. Did it create/register hooks in settings.json?
3. Did it create slash commands and update the Commands table?
4. Did it update CHANGELOG.md?
5. Is the overall output well-structured and useful?

Grade the OVERALL system on a scale of 0-100.

Respond with ONLY valid JSON in this exact format:
{
  \"score\": <number 0-100>,
  \"reasoning\": \"<brief explanation>\",
  \"per_migration\": {
    \"<migration_name>\": {\"score\": <0-100>, \"notes\": \"<brief notes>\"}
  }
}

Here are the migration outputs to grade:

$GRADE_INPUT"

    # Run Claude grading - use plain text output for reliability
    RAW_RESULT=$(echo -e "$GRADE_PROMPT" | claude -p --model sonnet 2>&1) || RAW_RESULT=""

    # Try to extract JSON from the response (Claude often wraps in code fences)
    # Look for JSON pattern with score field
    if echo "$RAW_RESULT" | grep -q '"score"'; then
        # Extract everything between first { and last }
        GRADE_RESULT=$(echo "$RAW_RESULT" | grep -oE '\{[^{}]*"score"[^{}]*\}' | head -1)
        if [[ -z "$GRADE_RESULT" ]]; then
            # Try multiline extraction
            GRADE_RESULT=$(echo "$RAW_RESULT" | sed -n '/{/,/}/p' | tr '\n' ' ' | grep -oE '\{.*\}' | head -1)
        fi
    fi

    # Validate it's valid JSON, default if not
    if ! echo "$GRADE_RESULT" | jq '.' >/dev/null 2>&1; then
        # Fallback: try to extract just score number
        EXTRACTED_SCORE=$(echo "$RAW_RESULT" | grep -oE '"score"[[:space:]]*:[[:space:]]*[0-9]+' | grep -oE '[0-9]+' | head -1)
        if [[ -n "$EXTRACTED_SCORE" ]]; then
            GRADE_RESULT="{\"score\": $EXTRACTED_SCORE, \"reasoning\": \"extracted from response\"}"
        else
            GRADE_RESULT='{"score": 0, "reasoning": "could not parse response"}'
        fi
    fi
fi

# Extract and display grade
SCORE=$(echo "$GRADE_RESULT" | jq -r '.score // 0' 2>/dev/null || echo 0)
REASONING=$(echo "$GRADE_RESULT" | jq -r '.reasoning // "N/A"' 2>/dev/null || echo "N/A")

echo "Overall Score: $SCORE/100"
echo ""
echo "Reasoning: $REASONING"
echo ""

# Show per-migration scores
echo "Per-Migration Scores:"
echo "$GRADE_RESULT" | jq -r '.per_migration // {} | to_entries[] | "  \(.key): \(.value.score)/100 - \(.value.notes)"' 2>/dev/null || true
echo ""

# Cleanup worktrees
cd "$PROJECT_DIR"
for wt in "$WORKTREES_DIR"/*; do
    [[ -d "$wt" ]] && git worktree remove -f "$wt" 2>/dev/null || true
done

# Final verdict
echo "═══════════════════════════════════════════════════════════════"
if [[ $SCORE -ge 80 ]]; then
    echo -e "${GREEN}GRADE: $SCORE/100 - PASS${NC}"
elif [[ $SCORE -ge 50 ]]; then
    echo -e "${YELLOW}GRADE: $SCORE/100 - NEEDS IMPROVEMENT${NC}"
else
    echo -e "${RED}GRADE: $SCORE/100 - FAIL${NC}"
fi
echo "═══════════════════════════════════════════════════════════════"

[[ $FAIL -gt 0 || $SCORE -lt 50 ]] && exit 1 || exit 0
