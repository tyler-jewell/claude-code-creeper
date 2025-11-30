/// State models for Creeper daemon
///
/// Tracks analysis history, pending improvements, and daemon status.
library state;

import 'dart:convert';

/// Global creeper state
class CreeperState {
  CreeperState({
    this.daemonPid,
    this.daemonStartedAt,
    this.projectPath,
    this.waitDuration,
    this.autoApply = false,
  });

  factory CreeperState.fromJson(Map<String, dynamic> json) => CreeperState(
        daemonPid: json['daemon_pid'] as int?,
        daemonStartedAt: json['daemon_started_at'] != null
            ? DateTime.parse(json['daemon_started_at'] as String)
            : null,
        projectPath: json['project_path'] as String?,
        waitDuration: json['wait_duration'] != null
            ? Duration(milliseconds: json['wait_duration'] as int)
            : null,
        autoApply: json['auto_apply'] as bool? ?? false,
      );

  final int? daemonPid;
  final DateTime? daemonStartedAt;
  final String? projectPath;
  final Duration? waitDuration;
  final bool autoApply;

  Map<String, dynamic> toJson() => {
        'daemon_pid': daemonPid,
        'daemon_started_at': daemonStartedAt?.toIso8601String(),
        'project_path': projectPath,
        'wait_duration': waitDuration?.inMilliseconds,
        'auto_apply': autoApply,
      };

  @override
  String toString() => jsonEncode(toJson());
}

/// Project-specific state
class ProjectState {
  ProjectState({
    required this.projectPath,
    this.lastAnalysis,
    this.nextScheduled,
    this.currentBranch,
    this.pending = const [],
    this.history = const [],
  });

  factory ProjectState.fromJson(Map<String, dynamic> json) => ProjectState(
        projectPath: json['project_path'] as String,
        lastAnalysis: json['last_analysis'] != null
            ? DateTime.parse(json['last_analysis'] as String)
            : null,
        nextScheduled: json['next_scheduled'] != null
            ? DateTime.parse(json['next_scheduled'] as String)
            : null,
        currentBranch: json['current_branch'] as String?,
        pending: (json['pending'] as List<dynamic>?)
                ?.map(
                  (e) =>
                      PendingImprovement.fromJson(e as Map<String, dynamic>),
                )
                .toList() ??
            [],
        history: (json['history'] as List<dynamic>?)
                ?.map((e) => AnalysisRecord.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  final String projectPath;
  final DateTime? lastAnalysis;
  final DateTime? nextScheduled;
  final String? currentBranch;
  final List<PendingImprovement> pending;
  final List<AnalysisRecord> history;

  Map<String, dynamic> toJson() => {
        'project_path': projectPath,
        'last_analysis': lastAnalysis?.toIso8601String(),
        'next_scheduled': nextScheduled?.toIso8601String(),
        'current_branch': currentBranch,
        'pending': pending.map((e) => e.toJson()).toList(),
        'history': history.map((e) => e.toJson()).toList(),
      };

  ProjectState copyWith({
    String? projectPath,
    DateTime? lastAnalysis,
    DateTime? nextScheduled,
    String? currentBranch,
    List<PendingImprovement>? pending,
    List<AnalysisRecord>? history,
  }) =>
      ProjectState(
        projectPath: projectPath ?? this.projectPath,
        lastAnalysis: lastAnalysis ?? this.lastAnalysis,
        nextScheduled: nextScheduled ?? this.nextScheduled,
        currentBranch: currentBranch ?? this.currentBranch,
        pending: pending ?? this.pending,
        history: history ?? this.history,
      );
}

/// A pending improvement detected but not yet applied
class PendingImprovement {
  PendingImprovement({
    required this.type,
    required this.description,
    required this.detected,
    this.prUrl,
  });

  factory PendingImprovement.fromJson(Map<String, dynamic> json) =>
      PendingImprovement(
        type: json['type'] as String,
        description: json['description'] as String,
        detected: DateTime.parse(json['detected'] as String),
        prUrl: json['pr_url'] as String?,
      );

  /// Type: 'hook', 'command', 'directive', 'skill'
  final String type;
  final String description;
  final DateTime detected;
  final String? prUrl;

  Map<String, dynamic> toJson() => {
        'type': type,
        'description': description,
        'detected': detected.toIso8601String(),
        'pr_url': prUrl,
      };
}

/// Record of a completed analysis
class AnalysisRecord {
  AnalysisRecord({
    required this.timestamp,
    required this.transcriptHash,
    this.patternsDetected = const [],
    this.changesApplied = const [],
    this.prUrl,
  });

  factory AnalysisRecord.fromJson(Map<String, dynamic> json) => AnalysisRecord(
        timestamp: DateTime.parse(json['timestamp'] as String),
        transcriptHash: json['transcript_hash'] as String,
        patternsDetected: (json['patterns_detected'] as List<dynamic>?)
                ?.cast<String>() ??
            [],
        changesApplied:
            (json['changes_applied'] as List<dynamic>?)?.cast<String>() ?? [],
        prUrl: json['pr_url'] as String?,
      );

  final DateTime timestamp;
  final String transcriptHash;
  final List<String> patternsDetected;
  final List<String> changesApplied;
  final String? prUrl;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'transcript_hash': transcriptHash,
        'patterns_detected': patternsDetected,
        'changes_applied': changesApplied,
        'pr_url': prUrl,
      };
}
