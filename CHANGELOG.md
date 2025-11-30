# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Background daemon mode with `start` command
- Git worktree isolation for safe changes
- Automatic PR creation workflow
- Status reporting with `creep` command

## [0.1.0] - 2025-11-30

### Added
- Initial release
- Domain-based analysis system (`CreeperDomain` interface)
- Transcript parsing with sealed class hierarchy
  - `UserEvent`, `AssistantEvent`, `SystemEvent`, `ResultEvent`
- Pattern detection
  - Repeated Bash commands (3+ occurrences)
  - User directives (NEVER, ALWAYS, MUST, etc.)
  - Error patterns from tool results
- Claude Code automation domain
  - Hook generation (PreToolUse, PostToolUse)
  - Slash command suggestions
  - CLAUDE.md updates
- CLI with `watch` and `test` modes
- Dart 3.10 features (dot shorthands, strict analysis)
- GitHub Actions CI/CD
  - Format checking
  - Static analysis
  - Test coverage with Codecov
  - Automated pub.dev publishing
- Dependabot configuration for weekly updates
