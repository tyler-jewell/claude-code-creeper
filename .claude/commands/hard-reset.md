---
description: Reset example project to baseline state
allowed-tools: Bash, Write, Read
---

Reset the example project to its baseline state for testing migrations.

## Steps

1. Delete all hooks, commands (except .gitkeep), and skills from `example/.claude/`
2. Reset files to baseline content below

## Baseline Content

### example/CLAUDE.md
```
# CLAUDE.md

Example project for testing Claude Code Creeper automation.

## Tech Stack
- Example project

## Commands
| Command | Purpose |
|---------|---------|

## Important Reminders

(none yet)
```

### example/.claude/CHANGELOG.md
```
# Automation Changelog

## Baseline
- Clean slate
```

### example/.claude/settings.json
```json
{
  "hooks": {},
  "permissions": {
    "allow": [],
    "deny": []
  }
}
```

## Cleanup Commands

Run these in parallel:
- `rm -f example/.claude/hooks/*.sh`
- `find example/.claude/commands -name "*.md" -type f -delete`
- `rm -rf example/.claude/skills/*`

Then ensure directories exist:
- `mkdir -p example/.claude/hooks example/.claude/commands example/.claude/skills example/.claude/migrations`
- `touch example/.claude/hooks/.gitkeep example/.claude/commands/.gitkeep example/.claude/skills/.gitkeep`
