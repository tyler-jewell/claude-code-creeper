/// Claude Creeper Library
///
/// Main library that orchestrates domain-based analysis and Claude CLI invocation.

library creeper;

import 'dart:io';

import 'domains/claude_code_automation/domain.dart';
import 'domains/domain.dart';
import 'models/transcript_types.dart';
import 'services/git_service.dart';

export 'domains/claude_code_automation/domain.dart';
export 'domains/domain.dart';
export 'models/hook_types.dart';
export 'models/state.dart';
export 'models/transcript_types.dart';
export 'services/daemon_service.dart';
export 'services/git_service.dart';
export 'services/state_service.dart';
export 'utils/constants.dart';

/// Result of running analysis
class AnalysisOutcome {
  AnalysisOutcome({
    this.prUrl,
    List<String>? changesApplied,
  }) : changesApplied = changesApplied ?? [];

  String? prUrl;
  final List<String> changesApplied;

  bool get hasChanges => changesApplied.isNotEmpty;
}

/// Creeper configuration
class CreeperConfig {
  CreeperConfig({
    required this.projectPath,
    this.autoApply = false,
    this.dryRun = false,
    this.model,
    List<CreeperDomain>? domains,
  }) : domains = domains ?? [ClaudeCodeAutomationDomain()];
  final String projectPath;
  final bool autoApply;
  final bool dryRun;
  final String? model;
  final List<CreeperDomain> domains;
}

/// Main creeper class
class Creeper {
  Creeper(this.config);
  final CreeperConfig config;

  /// Gather context for analysis
  Future<AnalysisContext> gatherContext({
    List<String>? changedFiles,
    String? transcriptContent,
  }) async {
    final projectDir = Directory(config.projectPath);

    // Get git log
    String? recentCommits;
    try {
      final result = await Process.run('git', [
        'log',
        '--oneline',
        '-15',
        '--no-decorate',
      ], workingDirectory: projectDir.path);
      recentCommits = result.stdout.toString().trim();
      if (recentCommits.isEmpty) recentCommits = null;
    } catch (_) {}

    // Get git diff stat
    String? recentDiffStat;
    try {
      final result = await Process.run('git', [
        'diff',
        '--stat',
        'HEAD~3',
      ], workingDirectory: projectDir.path);
      recentDiffStat = result.stdout.toString().trim();
      if (recentDiffStat.isEmpty) recentDiffStat = null;
    } catch (_) {}

    // Analyze transcript if provided
    TranscriptAnalysis? transcriptAnalysis;
    if (transcriptContent != null && transcriptContent.isNotEmpty) {
      final events = TranscriptEvent.parseTranscript(transcriptContent);
      transcriptAnalysis = TranscriptAnalysis.fromEvents(events);
    }

    return AnalysisContext(
      changedFiles: changedFiles ?? [],
      recentCommits: recentCommits,
      recentDiffStat: recentDiffStat,
      transcriptAnalysis: transcriptAnalysis,
      projectPath: config.projectPath,
    );
  }

  /// Run analysis using active domains
  ///
  /// When autoApply is false, creates a worktree, runs analysis there,
  /// and creates a PR with the changes.
  Future<AnalysisOutcome> runAnalysis(AnalysisContext context) async {
    final outcome = AnalysisOutcome();

    for (final domain in config.domains) {
      if (!domain.shouldActivate(context)) {
        print('Skipping domain: ${domain.name} (not applicable)');
        continue;
      }

      print('Running domain: ${domain.name}');
      print('=' * 60);

      final result = domain.analyze(context);

      if (config.dryRun) {
        print('\n=== USER PROMPT ===');
        print(result.userPrompt);
        print('\n=== SYSTEM PROMPT APPEND ===');
        print(result.systemPromptAppend);
        continue;
      }

      // Determine working directory
      String workingDir;
      WorktreeResult? worktree;

      if (config.autoApply) {
        // Auto-apply: work directly in project
        workingDir = config.projectPath;
      } else {
        // PR mode: create worktree
        try {
          print('Creating worktree for isolated changes...');
          worktree = await GitService.createWorktree(config.projectPath);
          workingDir = worktree.path;
          print('Worktree created: ${worktree.branchName}');
        } catch (e) {
          print('Warning: Could not create worktree: $e');
          print('Falling back to direct mode');
          workingDir = config.projectPath;
        }
      }

      // Build Claude CLI args
      final args = _buildClaudeArgs(result);

      print('Running Claude analysis...');
      print('Command: claude ${args.take(3).join(' ')} ...\n');

      final processResult = await Process.run(
        'claude',
        args,
        workingDirectory: workingDir,
      );

      _handleResult(processResult);

      // If using worktree, check for changes and create PR
      if (worktree != null) {
        try {
          if (await GitService.hasChanges(workingDir)) {
            print('\nChanges detected, creating PR...');

            final changedFiles = await GitService.getChangedFiles(workingDir);
            outcome.changesApplied.addAll(changedFiles);

            // Stage and commit
            await GitService.stageAll(workingDir);
            await GitService.commit(
              workingDir,
              'creeper: ${domain.name} improvements\n\n'
                  'Changes:\n${changedFiles.map((f) => '- $f').join('\n')}\n\n'
                  '🤖 Generated by Claude Creeper',
            );

            // Push
            await GitService.push(workingDir);

            // Create PR
            final prUrl = await GitService.createPR(
              path: workingDir,
              title: 'creeper: ${domain.name} improvements',
              body: '## Summary\n\n'
                  'Automated improvements detected by Claude Creeper.\n\n'
                  '## Changes\n\n'
                  '${changedFiles.map((f) => '- `$f`').join('\n')}\n\n'
                  '---\n\n'
                  '🤖 Generated by '
                  '[Claude Creeper](https://github.com/tylerjewell/claude-code-creeper)',
            );

            outcome.prUrl = prUrl;
            print('PR created: $prUrl');
          } else {
            print('\nNo changes made by analysis');
          }
        } catch (e) {
          print('Error creating PR: $e');
        } finally {
          // Clean up worktree
          print('Cleaning up worktree...');
          await GitService.removeWorktree(config.projectPath);
        }
      }
    }

    return outcome;
  }

  List<String> _buildClaudeArgs(AnalysisResult result) {
    final args = <String>[
      '-p',
      result.userPrompt,
      '--append-system-prompt',
      result.systemPromptAppend,
      '--output-format',
      'json',
    ];

    // Permission mode based on auto-apply setting
    if (config.autoApply) {
      args.addAll(['--permission-mode', 'acceptEdits']);
    } else {
      args.addAll(['--permission-mode', 'plan']);
    }

    // Allowed tools
    args.addAll(['--allowed-tools', result.allowedTools.join(',')]);

    // Model
    final model = config.model ?? result.recommendedModel ?? 'sonnet';
    args.addAll(['--model', model]);

    return args;
  }

  void _handleResult(ProcessResult result) {
    final stdout = result.stdout.toString();
    final stderr = result.stderr.toString();

    if (stderr.isNotEmpty) {
      print('stderr: $stderr');
    }

    if (stdout.isNotEmpty) {
      print('\nResult:\n$stdout');
    }
  }
}
