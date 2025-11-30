# Claude Code Creeper

A self-improving automation daemon for Claude Code. Creeper watches your coding sessions, learns patterns, and automatically optimizes your `.claude/` configuration—hooks, commands, skills, and settings—by creating PRs you can review.

Built on Dart and the Claude Code SDK. Nothing else.

## Install

```bash
dart pub global activate claude_code_creeper
```

## Usage

Start the creeper daemon:

```bash
claude-code-creeper start --wait 10m
```

This runs in the background and:

1. **Watches** your Claude Code sessions for patterns
2. **Detects** opportunities to improve automation (repeated commands, user directives, common errors)
3. **Creates a worktree** to isolate changes
4. **Implements** improvements with full testing and documentation
5. **Opens a PR** for your review
6. **Cleans up** and waits before creeping again

### Stop the Daemon

```bash
claude-code-creeper stop
```

### Check Status

See what the creeper has been up to:

```bash
claude-code-creeper creep
```

Returns a human-readable (and Claude Code agent-friendly) summary of recent analysis, changes, and pending improvements.

### Options

```bash
claude-code-creeper start [OPTIONS]

  --wait <duration>    Time between analysis cycles (default: 10m)
  --auto-apply         Skip PRs, apply changes directly (use with caution)
  --dry-run            Analyze only, don't make changes
  --model <model>      Claude model to use (default: haiku)
```

## How It Works

Creeper analyzes your Claude Code transcripts to find:

- **Repeated commands** → Creates hooks to automate them
- **User directives** ("NEVER do X", "ALWAYS do Y") → Adds to CLAUDE.md
- **Common errors** → Creates validation hooks to prevent them
- **Workflow patterns** → Generates slash commands and skills

All changes go through PRs so you stay in control.

## Example

You've been running `dart fix --apply && dart analyze` after every edit. Creeper notices this pattern and:

1. Creates `.claude/hooks/post-edit-dart.sh`
2. Registers it in `.claude/settings.json`
3. Updates `.claude/CHANGELOG.md`
4. Opens a PR: "Add PostToolUse hook for automatic Dart fixes"

Next time you edit a Dart file, it happens automatically.

## License

MIT
