#!/usr/bin/env dart

/// Claude Creeper CLI
///
/// Watches codebase changes and asks Claude to optimize .claude/ configuration.
///
/// Usage:
///   dart run bin/creeper.dart [command] [options]
///
/// Commands:
///   watch             Watch for changes and auto-analyze (default)
///   test              Run single analysis with provided migration
///   replay            Replay migrations from baseline
///   reset             Hard reset to baseline (requires --confirm)
///
/// Options:
///   --interval=N      Minutes to wait after changes before analysis (default: 10)
///   --auto-apply      Apply changes automatically (default: plan mode)
///   --migration=PATH  Path to migration .jsonl file (for test command)
///   --dry-run         Show prompts without running Claude
///   --model=MODEL     Model to use (overrides migration default)
///   --to=N            Replay up to migration N
///   --only=N          Run only migration N
///   --confirm         Skip confirmation prompts
library creeper;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:claude_code_creeper/creeper.dart';

const defaultIntervalMinutes = 10;

late Directory projectDir;
late Directory claudeProjectsDir;
late String creeperSessionId;

int intervalMinutes = defaultIntervalMinutes;
bool autoApply = false;
String? migrationPath;
bool dryRun = false;
String? model;
int? replayTo;
int? replayOnly;
bool confirm = false;

Timer? analysisTimer;
bool isAnalyzing = false;

// Track file modification times
final Map<String, DateTime> fileModTimes = {};

// Track changed files since last analysis
final List<String> pendingChanges = [];

void main(List<String> args) async {
  var projectPath = Directory.current.path;
  var command = 'watch';

  // Parse command (first non-flag arg)
  for (final arg in args) {
    if (!arg.startsWith('-')) {
      if (['watch', 'test', 'replay', 'reset'].contains(arg)) {
        command = arg;
      } else {
        projectPath = arg;
      }
    }
  }

  // Parse flags
  for (final arg in args) {
    if (arg.startsWith('--interval=')) {
      intervalMinutes =
          int.tryParse(arg.split('=')[1]) ?? defaultIntervalMinutes;
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
    case 'watch':
    default:
      await _runWatchMode();
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

/// Run in watch mode
Future<void> _runWatchMode() async {
  // Generate session ID
  creeperSessionId = _generateSessionId();

  print('Claude Creeper started');
  print('Watching: ${projectDir.path}');
  print('Analysis delay: $intervalMinutes minutes after changes');
  print('Auto-apply: ${autoApply ? 'enabled' : 'disabled (plan mode)'}');
  print('Session: $creeperSessionId');
  print('');
  print('Press Ctrl+C to stop\n');

  // Initial scan
  await _scanFiles();

  // Watch for changes
  await _watchForChanges();
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
      print(
        '${changes.length} file(s) changed - analysis in $intervalMinutes min',
      );

      // Reset/start the timer
      analysisTimer?.cancel();
      analysisTimer = Timer(Duration(minutes: intervalMinutes), _runAnalysis);
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
    }

    final context = await creeper.gatherContext(
      changedFiles: pendingChanges.toSet().toList(),
      transcriptContent: transcriptContent,
    );

    await creeper.runAnalysis(context);
  } catch (e) {
    print('Error during analysis: $e');
  }

  // Clear pending changes
  pendingChanges.clear();

  isAnalyzing = false;
  print('\nWatching for changes...\n');
}

Future<String?> _findRecentTranscript() async {
  if (!claudeProjectsDir.existsSync()) return null;

  try {
    File? mostRecent;
    DateTime? mostRecentTime;

    await for (final dir in claudeProjectsDir.list()) {
      if (dir is Directory) {
        await for (final file in dir.list()) {
          if (file is File && file.path.endsWith('.jsonl')) {
            final stat = await file.stat();
            if (mostRecentTime == null ||
                stat.modified.isAfter(mostRecentTime)) {
              mostRecent = file;
              mostRecentTime = stat.modified;
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
