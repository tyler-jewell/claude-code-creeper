# Claude Code Creeper

Self-improving Claude Code automation that learns from your sessions and optimizes your `.claude/` configuration.

## What is Creeper?

Creeper is a meta-agent that watches your Claude Code sessions and automatically:

- **Learns your preferences** - Extracts user directives ("NEVER", "ALWAYS") and adds them to CLAUDE.md
- **Automates repeated tasks** - Detects frequently used commands and creates slash commands or hooks
- **Maintains configuration** - Keeps CLAUDE.md, settings.json, and CHANGELOG.md in sync
- **Tests itself** - Includes a migration verification system with parallel worktree testing

## Quick Start

```bash
# Clone the repo
git clone https://github.com/tyler-jewell/claude-code-creeper.git
cd claude-code-creeper

# Install dependencies
dart pub get

# Run in watch mode (monitors your project for changes)
dart run bin/creeper.dart watch /path/to/your/project

# Or run a single analysis with a transcript
dart run bin/creeper.dart test --transcript=/path/to/transcript.jsonl /path/to/project
```

## Commands

| Command | Description |
|---------|-------------|
| `watch` | Watch for changes and auto-analyze (default) |
| `test` | Run single analysis with provided transcript |
| `replay` | Replay migrations from baseline |
| `reset` | Hard reset to baseline (requires --confirm) |

## Options

| Option | Description |
|--------|-------------|
| `--interval=N` | Minutes to wait after changes before analysis (default: 10) |
| `--auto-apply` | Apply changes automatically (default: plan mode) |
| `--transcript=PATH` | Path to transcript file (required with test) |
| `--dry-run` | Show prompts without running Claude |
| `--model=MODEL` | Model to use (default: sonnet) |
| `--confirm` | Skip confirmation prompts |

## How It Works

### Domain Architecture

Creeper uses a domain-based architecture for extensibility:

```
lib/
├── creeper.dart           # Main library
├── domains/
│   ├── domain.dart        # Base domain interface
│   └── claude_code_automation/
│       └── domain.dart    # Claude Code optimization domain
├── models/
│   ├── hook_types.dart    # Claude Code hook type definitions
│   └── transcript_types.dart  # Transcript parsing
└── schemas/
    └── claude_code_hooks_schema.json  # JSON schema for hooks
```

### Migration System

Creeper includes a rewindable migration system for testing:

```
.claude/creeper/
├── migrations/
│   ├── baseline.json       # Clean slate configuration
│   ├── user-directive.json # Test: user directives → CLAUDE.md
│   └── slash-command.json  # Test: repeated commands → slash commands
└── transcripts/
    ├── user-directive.jsonl
    └── slash-command.jsonl
```

Run migration verification:

```bash
bash .claude/ai_automation_scripts/verify-migrations.sh --model=haiku
```

This:
1. Creates parallel git worktrees for each migration
2. Resets each worktree to baseline
3. Runs migrations in parallel
4. Verifies expected changes were made
5. Uses Claude (sonnet) to grade the results (0-100)

## Configuration Files

### `.claude/settings.json`

Creeper manages hook registration:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [{"type": "command", "command": "..."}]
      }
    ]
  }
}
```

### `CLAUDE.md`

Creeper maintains:
- Commands table for slash commands
- Important Reminders section for user directives
- Tech stack and project context

### `.claude/CHANGELOG.md`

All automation changes are logged with timestamps.

## License

MIT
