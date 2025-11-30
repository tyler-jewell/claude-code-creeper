/// Claude Code Automation Domain
///
/// Analyzes Claude Code session patterns and optimizes .claude/ configuration:
/// - Hooks (PreToolUse, PostToolUse, etc.)
/// - CLAUDE.md content
/// - Slash commands
/// - Skills

import '../domain.dart';

/// Claude Code Automation domain implementation
class ClaudeCodeAutomationDomain implements CreeperDomain {
  @override
  String get id => 'claude_code_automation';

  @override
  String get name => 'Claude Code Automation';

  @override
  String get description =>
      'Optimizes .claude/ configuration based on session patterns';

  @override
  bool shouldActivate(AnalysisContext context) {
    // Always active - this is the primary domain
    return true;
  }

  @override
  AnalysisResult analyze(AnalysisContext context) {
    final userPrompt = _buildUserPrompt(context);
    final systemPrompt = _buildSystemPrompt();

    return AnalysisResult(
      userPrompt: userPrompt,
      systemPromptAppend: systemPrompt,
      allowedTools: ['Read', 'Edit', 'Write', 'Glob', 'Grep', 'Bash'],
      recommendedModel: 'sonnet',
    );
  }

  String _buildUserPrompt(AnalysisContext context) {
    final buffer = StringBuffer();

    buffer.writeln('CREEPER ANALYSIS REQUEST');
    buffer.writeln('========================');
    buffer.writeln('Domain: $name\n');

    // Changed files
    if (context.changedFiles.isNotEmpty) {
      buffer.writeln('## Files Changed Since Last Analysis:');
      for (final f in context.changedFiles.take(20)) {
        buffer.writeln('- $f');
      }
      if (context.changedFiles.length > 20) {
        buffer.writeln('- ... and ${context.changedFiles.length - 20} more');
      }
      buffer.writeln();
    }

    // Recent commits
    if (context.recentCommits != null) {
      buffer.writeln('## Recent Commits:');
      buffer.writeln(context.recentCommits);
      buffer.writeln();
    }

    // Diff stat
    if (context.recentDiffStat != null) {
      buffer.writeln('## Recent Changes Summary:');
      buffer.writeln(context.recentDiffStat);
      buffer.writeln();
    }

    // Transcript analysis
    final analysis = context.transcriptAnalysis;
    if (analysis != null) {
      buffer.writeln('## Session Patterns from Transcript:');

      if (analysis.toolUsage.isNotEmpty) {
        buffer.writeln(
          'Tool usage: ${analysis.toolUsage.entries.map((e) => '${e.key}(${e.value})').join(', ')}',
        );
      }

      // Repeated Bash commands (automation opportunity)
      final repeatedBash = analysis.bashCommands.entries
          .where((e) => e.value >= 3)
          .toList();
      if (repeatedBash.isNotEmpty) {
        buffer.writeln('\n## REPEATED BASH COMMANDS (Automation Opportunity):');
        buffer.writeln(
          'These commands were run 3+ times and should be considered for automation:',
        );
        for (final cmd in repeatedBash) {
          buffer.writeln('- `${cmd.key}` (${cmd.value} times)');
        }
        buffer.writeln();
      }

      // User directives (highest priority)
      if (analysis.userDirectives.isNotEmpty) {
        buffer.writeln('\n## USER DIRECTIVES (HIGH PRIORITY):');
        buffer.writeln(
          'The user expressed these strong preferences that should be added to CLAUDE.md:',
        );
        for (final d in analysis.userDirectives) {
          buffer.writeln('- "$d"');
        }
        buffer.writeln();
      }

      // Errors
      if (analysis.errors.isNotEmpty) {
        buffer.writeln('\nRecent errors encountered:');
        for (final e in analysis.errors) {
          buffer.writeln('- $e');
        }
      }

      // User prompts
      if (analysis.userPrompts.isNotEmpty) {
        buffer.writeln('\nUser prompt themes:');
        for (final p in analysis.userPrompts.take(5)) {
          buffer.writeln('- $p...');
        }
      }
      buffer.writeln();
    }

    buffer.writeln('---');
    buffer.writeln(
      'Analyze this context and improve the .claude/ configuration as needed.',
    );

    return buffer.toString();
  }

  String _buildSystemPrompt() {
    return '''

## CREEPER MODE INSTRUCTIONS - Claude Code Automation Domain

You are running as "Claude Creeper" - a background meta-agent that optimizes .claude/ configuration based on observed usage patterns.

## STEP 1: EXPLORE CURRENT SETUP (Required First)

Before making any changes, you MUST understand the current automation system:

1. Read CLAUDE.md to understand project context and existing rules
2. Read .claude/CHANGELOG.md to understand automation history and evolution
3. Read .claude/settings.json to see registered hooks and permissions
4. Glob .claude/hooks/*.sh to see existing hooks
5. Glob .claude/commands/*.md to see existing slash commands
6. Glob .claude/skills/*.md to see existing skills

This exploration ensures you don't duplicate existing functionality or contradict established patterns.

## STEP 2: ANALYZE SESSION CONTEXT

After understanding the current setup, analyze the provided context:
- Changed files and recent commits
- Transcript patterns (tool usage, errors, user directives)
- Compare observed patterns against existing automation

## STEP 3: MAKE TARGETED IMPROVEMENTS

Make MINIMAL changes that complement (not duplicate) existing automation.

## Priority Actions (in order):

### 1. USER DIRECTIVES (Highest Priority)
If the transcript contains user directives (NEVER, ALWAYS, DO NOT, MUST), you MUST:
- Add them to the "Important Reminders" section of CLAUDE.md
- Use the exact wording the user specified
- These are non-negotiable user preferences

### 2. Repeated Commands
If Bash commands appear 3+ times in tool usage:
- Consider adding a PostToolUse hook to automate them
- Or create a slash command if it's an on-demand operation
- Or add guidance to CLAUDE.md if automation isn't appropriate

### 3. Repeated Errors
If errors recur:
- Add PreToolUse validation hooks to prevent them
- Or add warnings to CLAUDE.md

### 4. Stale Information
If CLAUDE.md references files/commands that don't exist:
- Remove or update the stale references

## FILE CREATION TEMPLATES

### Creating a Hook (.claude/hooks/example.sh)
```bash
#!/bin/bash
set -euo pipefail
INPUT=\$(cat)
FILE_PATH=\$(echo "\$INPUT" | jq -r '.tool_input.file_path // empty')
# Your logic here
exit 0  # 0=success, 2=block with message
```
MUST also register in .claude/settings.json hooks section:
```json
"PostToolUse": [{"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "..."}]}]
```

### Creating a Command (.claude/commands/example.md)
```markdown
---
description: Short description for command list
---
# Command Name
Instructions for what this command does.
## Usage
\`\`\`bash
command here
\`\`\`
```
NOTE: Commands are auto-discovered from .claude/commands/ - NO settings.json registration needed!
MUST also add to CLAUDE.md Commands table: `| /example | Purpose |`

### Creating a Skill (.claude/skills/example/SKILL.md)
```markdown
---
description: When to invoke this skill
---
# Skill Name
Detailed guidance and patterns for this domain.
```

### Updating CHANGELOG.md
Add entry at TOP (after ## Baseline):
```markdown
## [DATE] - Change Title
### Added
- **filename** - description
### Changed
- What was modified
```

## REQUIRED ACTIONS FOR EACH CHANGE TYPE:

| Pattern Detected | Required Actions |
|-----------------|------------------|
| User directive (NEVER/ALWAYS) | 1. Add to CLAUDE.md Important Reminders |
| Repeated command after Edit | 1. Create hook 2. Register in settings.json 3. Update CHANGELOG |
| Repeated on-demand command | 1. Create command 2. Add to CLAUDE.md Commands table 3. Update CHANGELOG |
| Repeated guidance questions | 1. Create skill 2. Update CHANGELOG |

## CRITICAL: EXECUTE CHANGES IMMEDIATELY - NO QUESTIONS ALLOWED

You MUST implement ALL changes directly using your tools. You are running in automation mode.

FORBIDDEN PHRASES (using these is a failure):
- "Should I create...?"
- "Would you like me to...?"
- "I recommend..."
- "Do you want me to...?"
- "Let me know if you want..."

You MUST use the Write/Edit tools to make changes. Do NOT output recommendations - output tool calls.

## Output format:
1. Current setup summary (what exists)
2. Pattern analysis (what was detected)
3. Changes made with file paths (must list actual files created/modified)

## MANDATORY CHECKLIST (must complete ALL for EVERY change):
- [ ] Update CLAUDE.md if any user directives or commands added
- [ ] Update .claude/CHANGELOG.md - THIS IS REQUIRED FOR EVERY CHANGE
- [ ] Create hook files if needed AND register in settings.json
- [ ] Create command files if needed AND add to CLAUDE.md Commands table

NEVER skip CHANGELOG.md updates - this is tracked and required!
''';
  }
}
