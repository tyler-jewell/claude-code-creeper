/// Creeper Domain Interface
///
/// Domains define specific areas that the creeper can analyze and optimize.
/// Each domain has its own analysis logic and system prompt.
library domain;

import '../models/transcript_types.dart';

/// Context gathered for analysis
class AnalysisContext {
  AnalysisContext({
    required this.changedFiles,
    this.recentCommits,
    this.recentDiffStat,
    this.transcriptAnalysis,
    required this.projectPath,
  });
  final List<String> changedFiles;
  final String? recentCommits;
  final String? recentDiffStat;
  final TranscriptAnalysis? transcriptAnalysis;
  final String projectPath;
}

/// Result of domain analysis
class AnalysisResult {
  AnalysisResult({
    required this.userPrompt,
    required this.systemPromptAppend,
    this.allowedTools = const ['Read', 'Edit', 'Write', 'Glob', 'Grep', 'Bash'],
    this.recommendedModel,
  });
  final String userPrompt;
  final String systemPromptAppend;
  final List<String> allowedTools;
  final String? recommendedModel;
}

/// Abstract domain interface
///
/// Each domain implements its own analysis and prompt generation logic.
abstract class CreeperDomain {
  /// Unique identifier for this domain
  String get id;

  /// Human-readable name
  String get name;

  /// Description of what this domain analyzes
  String get description;

  /// Analyze context and generate prompts for Claude
  AnalysisResult analyze(AnalysisContext context);

  /// Whether this domain should be active given the context
  bool shouldActivate(AnalysisContext context);
}
