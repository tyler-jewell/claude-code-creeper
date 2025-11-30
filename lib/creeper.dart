/// Claude Creeper Library
///
/// Main library that orchestrates domain-based analysis and Claude CLI invocation.

library creeper;

export 'models/hook_types.dart';
export 'models/transcript_types.dart';
export 'domains/domain.dart';
export 'domains/claude_code_automation/domain.dart';
export 'utils/constants.dart';

import 'dart:io';

import 'models/transcript_types.dart';
import 'domains/domain.dart';
import 'domains/claude_code_automation/domain.dart';

/// Creeper configuration
class CreeperConfig {
  final String projectPath;
  final bool autoApply;
  final bool dryRun;
  final String? model;
  final List<CreeperDomain> domains;

  CreeperConfig({
    required this.projectPath,
    this.autoApply = false,
    this.dryRun = false,
    this.model,
    List<CreeperDomain>? domains,
  }) : domains = domains ?? [ClaudeCodeAutomationDomain()];
}

/// Main creeper class
class Creeper {
  final CreeperConfig config;

  Creeper(this.config);

  /// Gather context for analysis
  Future<AnalysisContext> gatherContext({
    List<String>? changedFiles,
    String? transcriptContent,
  }) async {
    final projectDir = Directory(config.projectPath);

    // Get git log
    String? recentCommits;
    try {
      final result = await Process.run(
        'git',
        ['log', '--oneline', '-15', '--no-decorate'],
        workingDirectory: projectDir.path,
      );
      recentCommits = result.stdout.toString().trim();
      if (recentCommits.isEmpty) recentCommits = null;
    } catch (_) {}

    // Get git diff stat
    String? recentDiffStat;
    try {
      final result = await Process.run(
        'git',
        ['diff', '--stat', 'HEAD~3'],
        workingDirectory: projectDir.path,
      );
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
  Future<void> runAnalysis(AnalysisContext context) async {
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

      // Build Claude CLI args
      final args = _buildClaudeArgs(result);

      print('Running Claude analysis...');
      print('Command: claude ${args.take(3).join(' ')} ...\n');

      final processResult = await Process.run(
        'claude',
        args,
        workingDirectory: config.projectPath,
      );

      _handleResult(processResult);
    }
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
    args.addAll([
      '--allowed-tools',
      result.allowedTools.join(','),
    ]);

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
