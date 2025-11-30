#!/usr/bin/env dart

/// Claude Creeper CLI
///
/// Self-improving automation daemon for Claude Code.
///
/// Usage:
///   creeper [command] [options] [project-path]
///
/// Commands:
///   start             Start the daemon (default)
///   stop              Stop the running daemon
///   creep             Show status and pending improvements
///   test              Run single analysis with provided migration
///   replay            Replay migrations from baseline
///   reset             Hard reset to baseline (requires --confirm)
///
/// Options:
///   --wait=DURATION   Time between analysis cycles (default: 10m)
///                     Examples: 10m, 1h, 30s
///   --auto-apply      Apply changes directly (skip worktree/PR)
///   --dry-run         Analyze only, don't make changes
///   --model=MODEL     Claude model to use (default: haiku)
///   --migration=PATH  Path to migration .jsonl file (for test command)
///   --to=N            Replay up to migration N
///   --only=N          Run only migration N
///   --confirm         Skip confirmation prompts
library creeper;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:claude_code_creeper/creeper.dart';

const defaultWaitDuration = Duration(minutes: 10);

late Directory projectDir;
late Directory claudeProjectsDir;
late String creeperSessionId;

Duration waitDuration = defaultWaitDuration;
bool autoApply = false;
String? migrationPath;
bool dryRun = false;
String? model;
int? replayTo;
int? replayOnly;
bool confirm = false;

/// Parse duration string like "10m", "1h", "30s"
Duration _parseDuration(String input) {
  final match = RegExp(r'^(\d+)(s|m|h)$').firstMatch(input.toLowerCase());
  if (match == null) return defaultWaitDuration;

  final value = int.parse(match.group(1)!);
  return switch (match.group(2)) {
    's' => Duration(seconds: value),
    'm' => Duration(minutes: value),
    'h' => Duration(hours: value),
    _ => defaultWaitDuration,
  };
}

Timer? analysisTimer;
bool isAnalyzing = false;

// Track file modification times
final Map<String, DateTime> fileModTimes = {};

// Track changed files since last analysis
final List<String> pendingChanges = [];

void main(List<String> args) async {
  var projectPath = Directory.current.path;
  var command = 'start';

  // Parse command (first non-flag arg)
  for (final arg in args) {
    if (!arg.startsWith('-')) {
      if (['start', 'stop', 'creep', 'test', 'replay', 'reset'].contains(arg)) {
        command = arg;
      } else {
        projectPath = arg;
      }
    }
  }

  // Parse flags
  for (final arg in args) {
    if (arg.startsWith('--wait=')) {
      waitDuration = _parseDuration(arg.split('=')[1]);
    } else if (arg == '--auto-apply') {
      autoApply = true;
    } else if (arg.startsWith('--migration=')) {
      migrationPath = arg.split('=')[1];
    } else if (arg == '--dry-run') {
      dryRun = true;
    } else if (arg.startsWith('--model=')) {
      model = arg.split('=')[1];
    } else if (arg.startsWith('--to=')) {
      replayTo = int.tryParse(arg.split('=')[1]);
    } else if (arg.startsWith('--only=')) {
      replayOnly = int.tryParse(arg.split('=')[1]);
    } else if (arg == '--confirm') {
      confirm = true;
    }
  }

  projectDir = Directory(projectPath);

  // Find Claude projects dir
  final home = Platform.environment['HOME'] ?? '';
  claudeProjectsDir = Directory('$home/.claude/projects');

  if (!projectDir.existsSync()) {
    print('Error: Project directory not found: ${projectDir.path}');
    exit(1);
  }

  switch (command) {
    case 'start':
      await _runStartMode();
    case 'stop':
      await _runStopMode();
    case 'creep':
      await _runCreepMode();
    case 'test':
      if (migrationPath == null) {
        print('Error: test requires --migration=<path>');
        exit(1);
      }
      await _runTestMode();
    case 'replay':
      await _runReplayMode();
    case 'reset':
      await _runResetMode();
  }
}

/// Parse a migration .jsonl file
/// First line = metadata, remaining lines = transcript
Future<MigrationData> _parseMigration(String path) async {
  final file = File(path);
  final lines = await file.readAsLines();

  if (lines.isEmpty) {
    throw Exception('Migration file is empty: $path');
  }

  // First line is metadata
  final metadata = jsonDecode(lines.first) as Map<String, dynamic>;

  // Remaining lines are transcript
  final transcriptLines = lines
      .skip(1)
      .where((l) => l.trim().isNotEmpty)
      .toList();

  return MigrationData(
    description: metadata['description'] as String? ?? 'Unknown',
    model: metadata['model'] as String? ?? 'haiku',
    verify: metadata['verify'] as Map<String, dynamic>? ?? {},
    transcriptContent: transcriptLines.join('\n'),
  );
}

/// Run in test mode with provided migration
Future<void> _runTestMode() async {
  final migration = await _parseMigration(migrationPath!);

  print('Claude Creeper TEST MODE');
  print('Project: ${projectDir.path}');
  print('Migration: $migrationPath');
  print('Description: ${migration.description}');
  print('Model: ${model ?? migration.model}');
  print('Auto-apply: ${autoApply ? 'enabled' : 'disabled'}');
  print('Dry-run: ${dryRun ? 'enabled' : 'disabled'}');
  print('');

  final config = CreeperConfig(
    projectPath: projectDir.path,
    autoApply: autoApply,
    dryRun: dryRun,
    model: model ?? migration.model,
  );

  final creeper = Creeper(config);

  final context = await creeper.gatherContext(
    transcriptContent: migration.transcriptContent,
  );

  await creeper.runAnalysis(context);
}

/// Run in start mode (daemon)
Future<void> _runStartMode() async {
  // Generate session ID
  creeperSessionId = _generateSessionId();

  final waitStr = _formatDuration(waitDuration);
  print('Claude Creeper started');
  print('Watching: ${projectDir.path}');
  print('Analysis delay: $waitStr after changes');
  print('Auto-apply: ${autoApply ? 'enabled' : 'disabled (PR mode)'}');
  print('Session: $creeperSessionId');
  print('');
  print('Press Ctrl+C to stop\n');

  // Initial scan
  await _scanFiles();

  // Watch for changes
  await _watchForChanges();
}

/// Format duration for display
String _formatDuration(Duration d) {
  if (d.inHours > 0) return '${d.inHours}h';
  if (d.inMinutes > 0) return '${d.inMinutes}m';
  return '${d.inSeconds}s';
}

/// Run stop mode - stop the daemon
Future<void> _runStopMode() async {
  final status = await DaemonService.status();

  if (!status.running) {
    print('No daemon is running');
    exit(0);
  }

  print('Stopping daemon (PID: ${status.pid})...');
  final stopped = await DaemonService.stop();

  if (stopped) {
    print('Daemon stopped');
  } else {
    print('Failed to stop daemon');
    exit(1);
  }
}

/// Run creep mode - show status
Future<void> _runCreepMode() async {
  print('Claude Creeper Status');
  print('=' * 50);

  // Check daemon status
  final status = await DaemonService.status();

  if (status.running) {
    print('Daemon: running (PID ${status.pid})');
    if (status.uptime != null) print('Uptime: ${status.uptime}');
    if (status.projectPath != null) print('Watching: ${status.projectPath}');
    if (status.waitDuration != null) {
      print('Interval: ${_formatDuration(status.waitDuration!)}');
    }
    print('Mode: ${status.autoApply ? 'auto-apply' : 'PR mode'}');
  } else {
    print('Daemon: not running');
  }

  print('');

  // Load project state
  final projectState = await StateService.loadProjectState(projectDir.path);

  if (projectState != null) {
    if (projectState.lastAnalysis != null) {
      print('Last analysis: ${_timeAgo(projectState.lastAnalysis!)}');
    }

    if (projectState.pending.isNotEmpty) {
      print('');
      print('Pending Improvements:');
      for (var i = 0; i < projectState.pending.length; i++) {
        final p = projectState.pending[i];
        print('  ${i + 1}. [${p.type}] ${p.description}');
        if (p.prUrl != null) print('     PR: ${p.prUrl}');
      }
    }

    // Load recent history
    final history = await StateService.loadHistory(projectDir.path, limit: 5);
    if (history.isNotEmpty) {
      print('');
      print('Recent Activity:');
      for (final record in history) {
        final ago = _timeAgo(record.timestamp);
        final changes = record.changesApplied.length;
        final patterns = record.patternsDetected.length;
        print('  • $ago: $patterns patterns, $changes changes');
      }
    }
  } else {
    print('No analysis history for this project');
  }

  print('');
  if (!status.running) {
    print("Run 'creeper start' to begin watching.");
  }
}

/// Format time difference as human-readable string
String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inDays > 0) return '${diff.inDays} day(s) ago';
  if (diff.inHours > 0) return '${diff.inHours} hour(s) ago';
  if (diff.inMinutes > 0) return '${diff.inMinutes} minute(s) ago';
  return 'just now';
}

String _generateSessionId() {
  final bytes = projectDir.path.codeUnits;
  var hash = 0;
  for (final b in bytes) {
    hash = ((hash << 5) - hash) + b;
    hash = hash & 0xFFFFFFFF;
  }
  return 'creeper-${hash.toRadixString(16).padLeft(8, '0')}';
}

Future<void> _scanFiles() async {
  fileModTimes.clear();

  await for (final entity in projectDir.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is File && !_shouldIgnore(entity.path)) {
      try {
        final stat = await entity.stat();
        fileModTimes[entity.path] = stat.modified;
      } catch (_) {}
    }
  }
}

bool _shouldIgnore(String path) {
  final ignorePaths = [
    '.git/',
    '.dart_tool/',
    '.creeper-work/',
    'build/',
    '.flutter-plugins',
    '.packages',
    'node_modules/',
    'pubspec.lock',
    'coverage/',
  ];

  return ignorePaths.any((p) => path.contains(p));
}

Future<void> _watchForChanges() async {
  while (true) {
    await Future<void>.delayed(Duration(seconds: 5));

    final changes = await _detectChanges();

    if (changes.isNotEmpty && !isAnalyzing) {
      pendingChanges.addAll(changes);
      final waitStr = _formatDuration(waitDuration);
      print('${changes.length} file(s) changed - analysis in $waitStr');

      // Reset/start the timer
      analysisTimer?.cancel();
      analysisTimer = Timer(waitDuration, _runAnalysis);
    }
  }
}

Future<List<String>> _detectChanges() async {
  final changes = <String>[];

  await for (final entity in projectDir.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is File && !_shouldIgnore(entity.path)) {
      try {
        final stat = await entity.stat();
        final lastMod = fileModTimes[entity.path];

        if (lastMod == null || stat.modified.isAfter(lastMod)) {
          final relPath = entity.path.replaceFirst('${projectDir.path}/', '');
          changes.add(relPath);
          fileModTimes[entity.path] = stat.modified;
        }
      } catch (_) {}
    }
  }

  return changes;
}

Future<void> _runAnalysis() async {
  if (isAnalyzing) return;
  isAnalyzing = true;

  print('\n${'=' * 60}');
  print('Running analysis - ${DateTime.now()}');
  print('${'=' * 60}\n');

  final absProjectPath = projectDir.absolute.path;
  final patternsDetected = <String>[];
  final changesApplied = <String>[];
  String? transcriptHash;

  try {
    final config = CreeperConfig(
      projectPath: projectDir.path,
      autoApply: autoApply,
      dryRun: dryRun,
      model: model,
    );

    final creeper = Creeper(config);

    // Find most recent transcript
    final transcriptPath = await _findRecentTranscript();
    String? transcriptContent;
    if (transcriptPath != null) {
      transcriptContent = await File(transcriptPath).readAsString();
      transcriptHash = transcriptPath.split('/').last;
    }

    final context = await creeper.gatherContext(
      changedFiles: pendingChanges.toSet().toList(),
      transcriptContent: transcriptContent,
    );

    // Extract patterns for state tracking
    final analysis = context.transcriptAnalysis;
    if (analysis != null) {
      if (analysis.userDirectives.isNotEmpty) {
        patternsDetected.add('${analysis.userDirectives.length} user directives');
      }
      final repeatedBash =
          analysis.bashCommands.entries.where((e) => e.value >= 3).length;
      if (repeatedBash > 0) {
        patternsDetected.add('$repeatedBash repeated commands');
      }
      if (analysis.errors.isNotEmpty) {
        patternsDetected.add('${analysis.errors.length} errors');
      }
    }

    await creeper.runAnalysis(context);

    // TODO: Parse Claude output to determine actual changes made
    // For now, just log that analysis ran
    changesApplied.add('Analysis completed');
  } catch (e) {
    print('Error during analysis: $e');
    patternsDetected.add('Error: $e');
  }

  // Save analysis record
  try {
    final record = AnalysisRecord(
      timestamp: DateTime.now(),
      transcriptHash: transcriptHash ?? 'no-transcript',
      patternsDetected: patternsDetected,
      changesApplied: changesApplied,
    );
    await StateService.appendHistory(absProjectPath, record);

    // Update project state
    final existingState = await StateService.loadProjectState(absProjectPath);
    final newState = (existingState ?? ProjectState(projectPath: absProjectPath))
        .copyWith(lastAnalysis: DateTime.now());
    await StateService.saveProjectState(newState);
  } catch (e) {
    print('Error saving state: $e');
  }

  // Clear pending changes
  pendingChanges.clear();

  isAnalyzing = false;
  print('\nWatching for changes...\n');
}

/// Find the most recent Claude Code transcript for the current project
///
/// Claude Code stores transcripts in ~/.claude/projects/<hash>/<session>.jsonl
/// where <hash> is derived from the absolute project path.
Future<String?> _findRecentTranscript() async {
  if (!claudeProjectsDir.existsSync()) return null;

  try {
    // Get the absolute path for the project
    final absProjectPath = projectDir.absolute.path;

    // Look for transcripts in all project directories
    // We check all because we might not know Claude's exact hashing algorithm
    File? mostRecent;
    DateTime? mostRecentTime;

    // Load project state to check last analysis time
    final projectState = await StateService.loadProjectState(absProjectPath);
    final lastAnalysis = projectState?.lastAnalysis;

    await for (final dir in claudeProjectsDir.list()) {
      if (dir is Directory) {
        await for (final file in dir.list()) {
          if (file is File && file.path.endsWith('.jsonl')) {
            final stat = await file.stat();

            // Skip if older than last analysis (already processed)
            if (lastAnalysis != null && stat.modified.isBefore(lastAnalysis)) {
              continue;
            }

            // Check if this transcript is for our project
            // Read first few lines to look for project path indicators
            final isForProject = await _transcriptIsForProject(
              file,
              absProjectPath,
            );

            if (isForProject) {
              if (mostRecentTime == null ||
                  stat.modified.isAfter(mostRecentTime)) {
                mostRecent = file;
                mostRecentTime = stat.modified;
              }
            }
          }
        }
      }
    }

    return mostRecent?.path;
  } catch (_) {
    return null;
  }
}

/// Check if a transcript file is for the given project
Future<bool> _transcriptIsForProject(File file, String projectPath) async {
  try {
    // Read first 20 lines to look for project indicators
    final lines = await file
        .openRead()
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .take(20)
        .toList();

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      // Look for working directory or file paths that match project
      if (line.contains(projectPath)) {
        return true;
      }

      // Also check for project name in paths
      final projectName = projectPath.split('/').last;
      if (line.contains('/$projectName/')) {
        return true;
      }
    }

    return false;
  } catch (_) {
    return false;
  }
}

/// Run reset mode - use the script
Future<void> _runResetMode() async {
  print('Use: .claude/scripts/hard-reset.sh');
  exit(0);
}

/// Run replay mode - replay migrations sequentially
Future<void> _runReplayMode() async {
  final migrationsDir = Directory('${projectDir.path}/.claude/migrations');

  if (!migrationsDir.existsSync()) {
    print('Error: No migrations directory found at ${migrationsDir.path}');
    exit(1);
  }

  // Get migration files (.jsonl only)
  final migrations = await migrationsDir
      .list()
      .where((f) => f.path.endsWith('.jsonl'))
      .map((f) => f as File)
      .toList();

  // Sort alphabetically for consistent ordering
  migrations.sort((a, b) => a.path.compareTo(b.path));

  if (migrations.isEmpty) {
    print('No migrations to replay');
    exit(0);
  }

  print('Claude Creeper REPLAY MODE');
  print('Project: ${projectDir.path}');
  print('Model: ${model ?? '(from migration)'}');
  print('Dry-run: ${dryRun ? 'enabled' : 'disabled'}');
  print('Auto-apply: enabled (required for replay)');
  print('');

  // Filter migrations based on --to or --only
  var toRun = migrations;
  if (replayOnly != null) {
    toRun = migrations.where((m) {
      final num = _extractMigrationNumber(m.path);
      return num == replayOnly;
    }).toList();
  } else if (replayTo != null) {
    toRun = migrations.where((m) {
      final num = _extractMigrationNumber(m.path);
      return num != null && num <= replayTo!;
    }).toList();
  }

  print('Migrations to replay: ${toRun.length}');
  for (final m in toRun) {
    print('  - ${m.uri.pathSegments.last}');
  }
  print('');

  // Run each migration sequentially
  for (final migrationFile in toRun) {
    final migration = await _parseMigration(migrationFile.path);
    final migrationModel = model ?? migration.model;

    print('=' * 60);
    print('Migration: ${migrationFile.uri.pathSegments.last}');
    print('Description: ${migration.description}');
    print('Model: $migrationModel');
    print('=' * 60);

    final config = CreeperConfig(
      projectPath: projectDir.path,
      autoApply: true, // Always auto-apply for replay
      dryRun: dryRun,
      model: migrationModel,
    );

    final creeper = Creeper(config);

    final context = await creeper.gatherContext(
      transcriptContent: migration.transcriptContent,
    );

    await creeper.runAnalysis(context);

    print('');
  }

  print('Replay complete!');
}

int? _extractMigrationNumber(String path) {
  final filename = path.split('/').last;
  final match = RegExp(r'^(\d+)-').firstMatch(filename);
  return match != null ? int.tryParse(match.group(1)!) : null;
}

/// Migration data parsed from .jsonl file
class MigrationData {
  MigrationData({
    required this.description,
    required this.model,
    required this.verify,
    required this.transcriptContent,
  });
  final String description;
  final String model;

  /// Verification data from migration format (reserved for future use)
  // ignore: unreachable_from_main
  final Map<String, dynamic> verify;
  final String transcriptContent;
}
