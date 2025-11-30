# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Self-improving Claude Code automation system. Creeper watches Claude Code sessions and optimizes `.claude/` configuration based on observed patterns.

## Commands

```bash
dart pub get                    # Install dependencies
dart analyze                    # Static analysis
dart test                       # Run tests
dart test --coverage-path=coverage/lcov.info  # Run tests with coverage

# Run creeper (development)
dart run bin/creeper.dart start /path/to/project          # Start daemon
dart run bin/creeper.dart stop                            # Stop daemon
dart run bin/creeper.dart creep                           # Check status
dart run bin/creeper.dart test --migration=FILE PROJECT   # Test migration
dart run bin/creeper.dart replay PROJECT                  # Replay all migrations
```

## Slash Commands

| Command | Purpose |
|---------|---------|
| `/hard-reset` | Reset example project to baseline state |
| `/verify-migrations` | Run static analysis and verify migrations |

## Architecture

**Domain-based analysis system:**
- `lib/creeper.dart` - Main orchestration, `Creeper` class runs domains against `AnalysisContext`
- `lib/domains/domain.dart` - Base `CreeperDomain` interface with `shouldActivate()` and `analyze()`
- `lib/domains/claude_code_automation/domain.dart` - Claude Code optimization domain

**Transcript parsing:**
- `lib/models/transcript_types.dart` - Sealed class hierarchy for Claude Code transcript events (UserEvent, AssistantEvent, SystemEvent, ResultEvent)
- `TranscriptAnalysis.fromEvents()` - Extracts tool usage, bash commands, errors, user directives

**Constants:**
- `lib/utils/constants.dart` - Default model, file extensions, retry limits

## Migration Format

Each migration is a `.jsonl` file in `example/.claude/migrations/`:
- **Line 1**: Metadata with `_migration`, `description`, `model`, `verify` fields
- **Lines 2+**: Transcript events for replay

## Development Notes

- Test migrations against `example/` directory, not main project
- The `example/` directory simulates a real project that creeper would optimize
- PostToolUse hooks run dart fix, analyze, and test on every Edit/Write

## Roadmap

See [ROADMAP.md](./ROADMAP.md) for pre-release checklist and future plans.
