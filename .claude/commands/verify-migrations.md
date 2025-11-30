---
description: Run static analysis and verify migrations against example project
allowed-tools: Bash, Read, Glob
---

Verify the creeper system works correctly.

## Steps

1. Run `dart analyze` - fail if issues found
2. Reset example to baseline using `/hard-reset`
3. For each `.jsonl` migration in `example/.claude/migrations/`:
   - Parse metadata from line 1 (JSON with `description`, `model`, `verify` fields)
   - Run: `dart run bin/creeper.dart test --migration=<path> --model=haiku --auto-apply example`
   - Verify results based on `verify` criteria in metadata
4. Report pass/fail for each migration

## Verification Criteria

Each migration's metadata line contains a `verify` object. Check these conditions:

| Criteria | How to Verify |
|----------|---------------|
| `command_created: true` | `example/.claude/commands/` has `.md` files (excluding .gitkeep) |
| `claude_md_commands_table_updated: true` | `example/CLAUDE.md` contains lines matching `^\| /` |
| `changelog_updated: true` | `example/.claude/CHANGELOG.md` has 2+ `## ` headers |
| `hooks_created: true` | `example/.claude/hooks/` has `.sh` files |
| `settings_json_has_hooks: true` | `example/.claude/settings.json` hooks object has keys |
| `claude_md_contains: [...]` | Each term appears in `example/CLAUDE.md` |

## Output Format

Report results as:
```
✓ migration-name (Xs)
✗ migration-name (Xs) - reason
```
