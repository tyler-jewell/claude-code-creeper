/// Daemon management service
///
/// Handles starting/stopping the creeper daemon as a background process.
library daemon_service;

import 'dart:io';

import '../models/state.dart';
import 'state_service.dart';

/// Service for managing the creeper daemon process
class DaemonService {
  DaemonService._();

  /// Start the daemon in the background
  ///
  /// Spawns a new process that detaches from the terminal.
  /// Returns the PID of the new process.
  static Future<int> start({
    required String projectPath,
    required Duration waitDuration,
    required bool autoApply,
    String? model,
    bool dryRun = false,
  }) async {
    // Check if already running
    if (await StateService.isDaemonRunning()) {
      final pid = await StateService.readPid();
      throw DaemonAlreadyRunningException(pid ?? 0);
    }

    // Build command args
    final args = <String>[
      'run',
      'bin/creeper.dart',
      'start',
      '--wait=${_formatDuration(waitDuration)}',
      projectPath,
    ];

    if (autoApply) args.add('--auto-apply');
    if (dryRun) args.add('--dry-run');
    if (model != null) args.add('--model=$model');

    // Find the package root (where pubspec.yaml is)
    final packageRoot = await _findPackageRoot();
    if (packageRoot == null) {
      throw Exception('Could not find package root (pubspec.yaml)');
    }

    // Spawn detached process
    final process = await Process.start(
      'dart',
      args,
      workingDirectory: packageRoot,
      mode: ProcessStartMode.detached,
    );

    final pid = process.pid;

    // Write PID file
    await StateService.writePid(pid);

    // Save global state
    await StateService.saveGlobalState(
      CreeperState(
        daemonPid: pid,
        daemonStartedAt: DateTime.now(),
        projectPath: projectPath,
        waitDuration: waitDuration,
        autoApply: autoApply,
      ),
    );

    return pid;
  }

  /// Stop the running daemon
  static Future<bool> stop() async {
    final pid = await StateService.readPid();
    if (pid == null) return false;

    try {
      final killed = Process.killPid(pid);
      if (killed) {
        await StateService.deletePid();
        return true;
      }
      return false;
    } catch (_) {
      // Process might already be dead
      await StateService.deletePid();
      return false;
    }
  }

  /// Check daemon status
  static Future<DaemonStatus> status() async {
    final pid = await StateService.readPid();
    if (pid == null) {
      return DaemonStatus(running: false);
    }

    final running = await StateService.isDaemonRunning();
    if (!running) {
      return DaemonStatus(running: false);
    }

    final state = await StateService.loadGlobalState();
    return DaemonStatus(
      running: true,
      pid: pid,
      startedAt: state?.daemonStartedAt,
      projectPath: state?.projectPath,
      waitDuration: state?.waitDuration,
      autoApply: state?.autoApply ?? false,
    );
  }

  /// Find package root by looking for pubspec.yaml
  static Future<String?> _findPackageRoot() async {
    var dir = Directory.current;
    while (dir.path != dir.parent.path) {
      if (File('${dir.path}/pubspec.yaml').existsSync()) {
        return dir.path;
      }
      dir = dir.parent;
    }
    return null;
  }

  static String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return '${d.inSeconds}s';
  }
}

/// Daemon status information
class DaemonStatus {
  DaemonStatus({
    required this.running,
    this.pid,
    this.startedAt,
    this.projectPath,
    this.waitDuration,
    this.autoApply = false,
  });

  final bool running;
  final int? pid;
  final DateTime? startedAt;
  final String? projectPath;
  final Duration? waitDuration;
  final bool autoApply;

  /// Format uptime as human-readable string
  String? get uptime {
    if (startedAt == null) return null;
    final diff = DateTime.now().difference(startedAt!);
    if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours % 24}h';
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return '${diff.inSeconds}s';
  }
}

/// Exception thrown when daemon is already running
class DaemonAlreadyRunningException implements Exception {
  DaemonAlreadyRunningException(this.pid);
  final int pid;

  @override
  String toString() => 'Daemon already running (PID: $pid)';
}
