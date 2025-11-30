/// State persistence service
///
/// Manages reading/writing creeper state to ~/.claude-creeper/
library state_service;

import 'dart:convert';
import 'dart:io';

import '../models/state.dart';

/// Service for persisting creeper state
class StateService {
  StateService._();

  static final String _baseDir = _getBaseDir();
  static final String _stateFile = '$_baseDir/state.json';
  static final String _pidFile = '$_baseDir/creeper.pid';

  static String _getBaseDir() {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/.claude-creeper';
  }

  /// Get project-specific state directory
  static String _projectDir(String projectPath) {
    final hash = _hashPath(projectPath);
    return '$_baseDir/projects/$hash';
  }

  /// Hash a path to a short identifier
  static String _hashPath(String path) {
    var hash = 0;
    for (final c in path.codeUnits) {
      hash = ((hash << 5) - hash) + c;
      hash = hash & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// Ensure base directory exists
  static Future<void> _ensureBaseDir() async {
    final dir = Directory(_baseDir);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
  }

  /// Ensure project directory exists
  static Future<void> _ensureProjectDir(String projectPath) async {
    final dir = Directory(_projectDir(projectPath));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
  }

  // ===== Global State =====

  /// Load global creeper state
  static Future<CreeperState?> loadGlobalState() async {
    final file = File(_stateFile);
    if (!file.existsSync()) return null;

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return CreeperState.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Save global creeper state
  static Future<void> saveGlobalState(CreeperState state) async {
    await _ensureBaseDir();
    final file = File(_stateFile);
    await file.writeAsString(jsonEncode(state.toJson()));
  }

  // ===== PID Management =====

  /// Write daemon PID
  static Future<void> writePid(int pid) async {
    await _ensureBaseDir();
    final file = File(_pidFile);
    await file.writeAsString(pid.toString());
  }

  /// Read daemon PID
  static Future<int?> readPid() async {
    final file = File(_pidFile);
    if (!file.existsSync()) return null;

    try {
      final content = await file.readAsString();
      return int.tryParse(content.trim());
    } catch (_) {
      return null;
    }
  }

  /// Delete PID file
  static Future<void> deletePid() async {
    final file = File(_pidFile);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  /// Check if daemon is running
  static Future<bool> isDaemonRunning() async {
    final pid = await readPid();
    if (pid == null) return false;

    try {
      // Send signal 0 to check if process exists
      return Process.killPid(pid, ProcessSignal.sigcont);
    } catch (_) {
      // Process doesn't exist, clean up stale PID
      await deletePid();
      return false;
    }
  }

  // ===== Project State =====

  /// Load project-specific state
  static Future<ProjectState?> loadProjectState(String projectPath) async {
    final file = File('${_projectDir(projectPath)}/state.json');
    if (!file.existsSync()) return null;

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return ProjectState.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Save project-specific state
  static Future<void> saveProjectState(ProjectState state) async {
    await _ensureProjectDir(state.projectPath);
    final file = File('${_projectDir(state.projectPath)}/state.json');
    await file.writeAsString(jsonEncode(state.toJson()));
  }

  /// Append to project history
  static Future<void> appendHistory(
    String projectPath,
    AnalysisRecord record,
  ) async {
    await _ensureProjectDir(projectPath);
    final file = File('${_projectDir(projectPath)}/history.jsonl');
    await file.writeAsString(
      '${jsonEncode(record.toJson())}\n',
      mode: FileMode.append,
    );
  }

  /// Load project history (last N records)
  static Future<List<AnalysisRecord>> loadHistory(
    String projectPath, {
    int limit = 50,
  }) async {
    final file = File('${_projectDir(projectPath)}/history.jsonl');
    if (!file.existsSync()) return [];

    try {
      final lines = await file.readAsLines();
      return lines
          .where((l) => l.trim().isNotEmpty)
          .map(
            (l) =>
                AnalysisRecord.fromJson(jsonDecode(l) as Map<String, dynamic>),
          )
          .toList()
          .reversed
          .take(limit)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Get state directory path (for debugging)
  static String get baseDir => _baseDir;
}
