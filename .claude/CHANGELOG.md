# Automation Changelog

## 2024-11-30 - Project Restructure

### Added
- **example/** - Isolated test project for migration testing
- **example/.claude/migrations/** - Version-controlled migrations
- **example/.claude/transcripts/** - Test transcripts
- **scripts/hard-reset.sh** - Reset example to baseline
- **scripts/verify-migrations.sh** - Run migration verification
- **test/test_migrations.dart** - Dart test runner
- **.claude/commands/reset.md** - Reset slash command
- **.claude/commands/verify.md** - Verify slash command
- **.claude/commands/test.md** - Test slash command
- **.claude/skills/creeper-development/** - Development guide

### Changed
- Moved migrations from .claude/creeper/ to example/.claude/migrations/
- Moved transcripts from .claude/creeper/ to example/.claude/transcripts/
- Moved automation scripts from .claude/ai_automation_scripts/ to .claude/scripts/
- Updated scripts to work with example directory

### Removed
- .claude/creeper/ directory
- .claude/ai_automation_scripts/ directory

## Baseline
- Clean slate
