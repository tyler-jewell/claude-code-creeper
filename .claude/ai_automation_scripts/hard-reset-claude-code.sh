#!/bin/bash
# Hard reset Claude Code automation to aggressive baseline
# Usage: .claude/ai_automation_scripts/hard-reset-claude-code.sh [--confirm] [TARGET_DIR]
# TARGET_DIR defaults to current working directory if not specified

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BASELINE="$SOURCE_DIR/.claude/creeper/migrations/baseline.json"

# TARGET_DIR is where we apply the reset (supports worktrees)
# Defaults to current directory if not provided as last arg
TARGET_DIR="$(pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [[ ! -f "$BASELINE" ]]; then
    echo -e "${RED}Error: Baseline not found at $BASELINE${NC}"
    exit 1
fi

# Parse args - look for --confirm and optional target dir
CONFIRM=false
for arg in "$@"; do
    if [[ "$arg" == "--confirm" ]]; then
        CONFIRM=true
    elif [[ -d "$arg" ]]; then
        TARGET_DIR="$arg"
    fi
done

# Confirmation unless --confirm passed
if [[ "$CONFIRM" != "true" ]]; then
    echo -e "${YELLOW}WARNING: AGGRESSIVE RESET - This nukes everything!${NC}"
    echo ""
    echo "Target: $TARGET_DIR"
    echo ""
    echo "Will DELETE:"
    echo "  - ALL .claude/hooks/*.sh"
    echo "  - ALL .claude/commands/*.md"
    echo "  - ALL .claude/skills/*"
    echo ""
    echo "Will RESET to minimal:"
    echo "  - CLAUDE.md (bare bones)"
    echo "  - .claude/CHANGELOG.md (clean)"
    echo "  - .claude/settings.json (empty hooks, no permissions)"
    echo ""
    read -p "Type 'nuke' to confirm: " confirm
    if [[ "$confirm" != "nuke" ]]; then
        echo "Aborted."
        exit 1
    fi
fi

echo -e "${GREEN}Nuking to baseline...${NC}"
echo "Target: $TARGET_DIR"

# DELETE all hooks
rm -f "$TARGET_DIR"/.claude/hooks/*.sh 2>/dev/null || true

# DELETE all commands
rm -f "$TARGET_DIR"/.claude/commands/*.md 2>/dev/null || true

# DELETE all skills
rm -rf "$TARGET_DIR"/.claude/skills/* 2>/dev/null || true

# Ensure directories exist
mkdir -p "$TARGET_DIR/.claude/hooks"
mkdir -p "$TARGET_DIR/.claude/commands"
mkdir -p "$TARGET_DIR/.claude/skills"

# Reset CLAUDE.md from baseline
CLAUDE_MD=$(jq -r '.files["CLAUDE.md"]' "$BASELINE")
echo "$CLAUDE_MD" > "$TARGET_DIR/CLAUDE.md"

# Reset CHANGELOG.md from baseline
CHANGELOG=$(jq -r '.files[".claude/CHANGELOG.md"]' "$BASELINE")
echo "$CHANGELOG" > "$TARGET_DIR/.claude/CHANGELOG.md"

# Reset settings.json completely from baseline
jq '.files[".claude/settings.json"]' "$BASELINE" > "$TARGET_DIR/.claude/settings.json"

echo -e "${GREEN}NUKED!${NC}"
echo ""
echo "Current state:"
echo "  - CLAUDE.md: bare bones"
echo "  - settings.json: empty hooks, no permissions"
echo "  - hooks/: empty"
echo "  - commands/: empty"
echo "  - skills/: empty"
echo ""
echo "To replay migrations: dart run bin/creeper.dart replay --model=haiku"
