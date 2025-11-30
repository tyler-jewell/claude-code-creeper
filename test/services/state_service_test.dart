import 'dart:io';

import 'package:claude_code_creeper/creeper.dart';
import 'package:test/test.dart';

void main() {
  group('StateService', () {
    late Directory tempHome;

    setUp(() async {
      // Create temp directory for tests
      tempHome = await Directory.systemTemp.createTemp('state_service_test_');
    });

    tearDown(() async {
      // Clean up temp directory
      if (tempHome.existsSync()) {
        await tempHome.delete(recursive: true);
      }
    });

    test('baseDir returns correct path', () {
      expect(StateService.baseDir, contains('.claude-creeper'));
    });

    group('data model serialization', () {
      test('CreeperState serialization roundtrip', () {
        final state = CreeperState(
          daemonPid: 12345,
          daemonStartedAt: DateTime(2024, 1, 15, 10, 30),
          projectPath: '/test/project',
          waitDuration: Duration(minutes: 10),
          autoApply: true,
        );

        final json = state.toJson();
        final restored = CreeperState.fromJson(json);

        expect(restored.daemonPid, equals(12345));
        expect(restored.projectPath, equals('/test/project'));
        expect(restored.autoApply, isTrue);
      });

      test('ProjectState serialization roundtrip', () {
        final state = ProjectState(
          projectPath: '/test/project',
          lastAnalysis: DateTime(2024, 1, 15),
          pending: [
            PendingImprovement(
              type: 'hook',
              description: 'Add tests',
              detected: DateTime(2024, 1, 10),
            ),
          ],
          history: [
            AnalysisRecord(
              timestamp: DateTime(2024, 1, 12),
              transcriptHash: 'abc123',
              changesApplied: ['file.dart'],
            ),
          ],
        );

        final json = state.toJson();
        final restored = ProjectState.fromJson(json);

        expect(restored.projectPath, equals('/test/project'));
        expect(restored.pending.length, equals(1));
        expect(restored.pending.first.type, equals('hook'));
        expect(restored.history.length, equals(1));
      });

      test('AnalysisRecord serialization roundtrip', () {
        final record = AnalysisRecord(
          timestamp: DateTime(2024, 1, 15),
          transcriptHash: 'hash123',
          patternsDetected: ['pattern1', 'pattern2'],
          changesApplied: ['file1.dart', 'file2.dart'],
          prUrl: 'https://github.com/test/pr/1',
        );

        final json = record.toJson();
        final restored = AnalysisRecord.fromJson(json);

        expect(restored.transcriptHash, equals('hash123'));
        expect(restored.patternsDetected.length, equals(2));
        expect(restored.changesApplied.length, equals(2));
        expect(restored.prUrl, equals('https://github.com/test/pr/1'));
      });

      test('PendingImprovement serialization roundtrip', () {
        final improvement = PendingImprovement(
          type: 'command',
          description: 'Add new slash command',
          detected: DateTime(2024, 1, 20),
          prUrl: 'https://github.com/test/pr/2',
        );

        final json = improvement.toJson();
        final restored = PendingImprovement.fromJson(json);

        expect(restored.type, equals('command'));
        expect(restored.description, equals('Add new slash command'));
        expect(restored.prUrl, equals('https://github.com/test/pr/2'));
      });
    });
  });

  group('StateService file operations', () {
    // Integration tests that actually test file operations
    // These modify ~/.claude-creeper so use with caution

    test('integration: write and read PID file', () async {
      // This test actually writes to ~/.claude-creeper/creeper.pid
      // Skip in CI or if you don't want to modify the file system
      final testPid = 99999;

      await StateService.writePid(testPid);
      final readPid = await StateService.readPid();

      expect(readPid, equals(testPid));

      // Clean up
      await StateService.deletePid();
      final deletedPid = await StateService.readPid();
      expect(deletedPid, isNull);
    }, skip: Platform.environment['CI'] == 'true');

    test('integration: isDaemonRunning returns false for non-existent PID',
        () async {
      // Write a PID that doesn't exist
      await StateService.writePid(999999999);
      final running = await StateService.isDaemonRunning();

      // Should return false and clean up the stale PID
      expect(running, isFalse);
    }, skip: Platform.environment['CI'] == 'true');

    test('integration: save and load global state', () async {
      final state = CreeperState(
        daemonPid: 88888,
        daemonStartedAt: DateTime.now(),
        projectPath: '/test/integration',
        waitDuration: Duration(minutes: 5),
      );

      await StateService.saveGlobalState(state);
      final loaded = await StateService.loadGlobalState();

      expect(loaded, isNotNull);
      expect(loaded!.daemonPid, equals(88888));
      expect(loaded.projectPath, equals('/test/integration'));

      // Clean up - save empty state
      await StateService.deletePid();
    }, skip: Platform.environment['CI'] == 'true');

    test('integration: save and load project state', () async {
      final projectPath = '/test/project/path';
      final state = ProjectState(
        projectPath: projectPath,
        lastAnalysis: DateTime.now(),
        pending: [],
        history: [],
      );

      await StateService.saveProjectState(state);
      final loaded = await StateService.loadProjectState(projectPath);

      expect(loaded, isNotNull);
      expect(loaded!.projectPath, equals(projectPath));
    }, skip: Platform.environment['CI'] == 'true');

    test('integration: append and load history', () async {
      final projectPath = '/test/project/history';
      final record = AnalysisRecord(
        timestamp: DateTime.now(),
        transcriptHash: 'test_hash',
        changesApplied: ['file.dart'],
      );

      await StateService.appendHistory(projectPath, record);
      final history = await StateService.loadHistory(projectPath);

      expect(history, isNotEmpty);
      expect(history.first.transcriptHash, equals('test_hash'));
    }, skip: Platform.environment['CI'] == 'true');

    test('loadGlobalState returns CreeperState or null', () async {
      // This should return null when the file doesn't exist,
      // or a valid CreeperState if a state file exists
      final state = await StateService.loadGlobalState();
      // Simply verify we can call the method without error
      expect(state, anyOf(isNull, isA<CreeperState>()));
    });

    test('loadProjectState returns null for missing project', () async {
      final state =
          await StateService.loadProjectState('/nonexistent/project/path');
      expect(state, isNull);
    });

    test('loadHistory returns empty list for missing project', () async {
      final history =
          await StateService.loadHistory('/nonexistent/project/path');
      expect(history, isEmpty);
    });
  });
}
