import 'package:claude_code_creeper/models/state.dart';
import 'package:test/test.dart';

void main() {
  group('CreeperState', () {
    test('fromJson parses all fields', () {
      final json = {
        'daemon_pid': 12345,
        'daemon_started_at': '2024-01-15T10:30:00.000Z',
        'project_path': '/path/to/project',
        'wait_duration': 600000,
        'auto_apply': true,
      };

      final state = CreeperState.fromJson(json);

      expect(state.daemonPid, equals(12345));
      expect(state.daemonStartedAt, isNotNull);
      expect(state.projectPath, equals('/path/to/project'));
      expect(state.waitDuration, equals(Duration(milliseconds: 600000)));
      expect(state.autoApply, isTrue);
    });

    test('fromJson handles null fields', () {
      final json = <String, dynamic>{};
      final state = CreeperState.fromJson(json);

      expect(state.daemonPid, isNull);
      expect(state.daemonStartedAt, isNull);
      expect(state.projectPath, isNull);
      expect(state.waitDuration, isNull);
      expect(state.autoApply, isFalse);
    });

    test('toJson serializes all fields', () {
      final state = CreeperState(
        daemonPid: 12345,
        daemonStartedAt: DateTime.utc(2024, 1, 15, 10, 30),
        projectPath: '/path/to/project',
        waitDuration: Duration(minutes: 10),
        autoApply: true,
      );

      final json = state.toJson();

      expect(json['daemon_pid'], equals(12345));
      expect(json['daemon_started_at'], equals('2024-01-15T10:30:00.000Z'));
      expect(json['project_path'], equals('/path/to/project'));
      expect(json['wait_duration'], equals(600000));
      expect(json['auto_apply'], isTrue);
    });

    test('toString returns JSON string', () {
      final state = CreeperState(daemonPid: 123);
      expect(state.toString(), contains('123'));
    });
  });

  group('ProjectState', () {
    test('fromJson parses all fields', () {
      final json = {
        'project_path': '/path/to/project',
        'last_analysis': '2024-01-15T10:30:00.000Z',
        'next_scheduled': '2024-01-15T10:40:00.000Z',
        'current_branch': 'creeper/123',
        'pending': [
          {
            'type': 'hook',
            'description': 'Add dart fix hook',
            'detected': '2024-01-15T10:30:00.000Z',
            'pr_url': 'https://github.com/test/pr/1',
          }
        ],
        'history': [
          {
            'timestamp': '2024-01-15T10:30:00.000Z',
            'transcript_hash': 'abc123',
            'patterns_detected': ['directive'],
            'changes_applied': ['CLAUDE.md'],
            'pr_url': 'https://github.com/test/pr/1',
          }
        ],
      };

      final state = ProjectState.fromJson(json);

      expect(state.projectPath, equals('/path/to/project'));
      expect(state.lastAnalysis, isNotNull);
      expect(state.nextScheduled, isNotNull);
      expect(state.currentBranch, equals('creeper/123'));
      expect(state.pending.length, equals(1));
      expect(state.history.length, equals(1));
    });

    test('fromJson handles empty lists', () {
      final json = {
        'project_path': '/path',
      };

      final state = ProjectState.fromJson(json);

      expect(state.pending, isEmpty);
      expect(state.history, isEmpty);
    });

    test('toJson serializes all fields', () {
      final state = ProjectState(
        projectPath: '/path',
        lastAnalysis: DateTime.utc(2024, 1, 15),
        pending: [
          PendingImprovement(
            type: 'hook',
            description: 'test',
            detected: DateTime.utc(2024, 1, 15),
          ),
        ],
        history: [
          AnalysisRecord(
            timestamp: DateTime.utc(2024, 1, 15),
            transcriptHash: 'hash',
          ),
        ],
      );

      final json = state.toJson();

      expect(json['project_path'], equals('/path'));
      expect(json['pending'], isA<List<dynamic>>());
      expect(json['history'], isA<List<dynamic>>());
    });

    test('copyWith creates modified copy', () {
      final state = ProjectState(
        projectPath: '/path',
        lastAnalysis: DateTime.utc(2024, 1, 15),
      );

      final newState = state.copyWith(
        lastAnalysis: DateTime.utc(2024, 1, 16),
      );

      expect(newState.projectPath, equals('/path'));
      expect(newState.lastAnalysis!.day, equals(16));
    });
  });

  group('PendingImprovement', () {
    test('fromJson parses all fields', () {
      final json = {
        'type': 'hook',
        'description': 'Add dart fix hook',
        'detected': '2024-01-15T10:30:00.000Z',
        'pr_url': 'https://github.com/test/pr/1',
      };

      final improvement = PendingImprovement.fromJson(json);

      expect(improvement.type, equals('hook'));
      expect(improvement.description, equals('Add dart fix hook'));
      expect(improvement.detected, isNotNull);
      expect(improvement.prUrl, equals('https://github.com/test/pr/1'));
    });

    test('toJson serializes all fields', () {
      final improvement = PendingImprovement(
        type: 'command',
        description: 'Create build command',
        detected: DateTime.utc(2024, 1, 15),
        prUrl: 'https://github.com/test/pr/2',
      );

      final json = improvement.toJson();

      expect(json['type'], equals('command'));
      expect(json['description'], equals('Create build command'));
      expect(json['detected'], isNotNull);
      expect(json['pr_url'], equals('https://github.com/test/pr/2'));
    });
  });

  group('AnalysisRecord', () {
    test('fromJson parses all fields', () {
      final json = {
        'timestamp': '2024-01-15T10:30:00.000Z',
        'transcript_hash': 'abc123',
        'patterns_detected': ['directive', 'repeated_command'],
        'changes_applied': ['CLAUDE.md', 'hooks/fix.sh'],
        'pr_url': 'https://github.com/test/pr/1',
      };

      final record = AnalysisRecord.fromJson(json);

      expect(record.timestamp, isNotNull);
      expect(record.transcriptHash, equals('abc123'));
      expect(record.patternsDetected, hasLength(2));
      expect(record.changesApplied, hasLength(2));
      expect(record.prUrl, equals('https://github.com/test/pr/1'));
    });

    test('fromJson handles missing lists', () {
      final json = {
        'timestamp': '2024-01-15T10:30:00.000Z',
        'transcript_hash': 'abc123',
      };

      final record = AnalysisRecord.fromJson(json);

      expect(record.patternsDetected, isEmpty);
      expect(record.changesApplied, isEmpty);
    });

    test('toJson serializes all fields', () {
      final record = AnalysisRecord(
        timestamp: DateTime.utc(2024, 1, 15),
        transcriptHash: 'hash123',
        patternsDetected: ['error'],
        changesApplied: ['file.dart'],
        prUrl: 'https://github.com/test/pr/3',
      );

      final json = record.toJson();

      expect(json['timestamp'], isNotNull);
      expect(json['transcript_hash'], equals('hash123'));
      expect(json['patterns_detected'], contains('error'));
      expect(json['changes_applied'], contains('file.dart'));
      expect(json['pr_url'], equals('https://github.com/test/pr/3'));
    });
  });
}
