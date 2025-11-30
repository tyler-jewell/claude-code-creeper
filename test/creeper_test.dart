import 'dart:io';

import 'package:claude_code_creeper/creeper.dart';
import 'package:test/test.dart';

void main() {
  group('AnalysisOutcome', () {
    test('creates with default values', () {
      final outcome = AnalysisOutcome();

      expect(outcome.prUrl, isNull);
      expect(outcome.changesApplied, isEmpty);
      expect(outcome.hasChanges, isFalse);
    });

    test('creates with provided values', () {
      final outcome = AnalysisOutcome(
        prUrl: 'https://github.com/test/pr/1',
        changesApplied: ['file1.dart', 'file2.dart'],
      );

      expect(outcome.prUrl, equals('https://github.com/test/pr/1'));
      expect(outcome.changesApplied, hasLength(2));
      expect(outcome.hasChanges, isTrue);
    });

    test('hasChanges returns true when changes exist', () {
      final outcome = AnalysisOutcome(
        changesApplied: ['file.dart'],
      );

      expect(outcome.hasChanges, isTrue);
    });

    test('hasChanges returns false when no changes', () {
      final outcome = AnalysisOutcome();

      expect(outcome.hasChanges, isFalse);
    });

    test('changesApplied can be modified', () {
      final outcome = AnalysisOutcome();
      outcome.changesApplied.add('new_file.dart');

      expect(outcome.changesApplied, contains('new_file.dart'));
      expect(outcome.hasChanges, isTrue);
    });

    test('prUrl can be set', () {
      final outcome = AnalysisOutcome();
      outcome.prUrl = 'https://github.com/test/pr/2';

      expect(outcome.prUrl, equals('https://github.com/test/pr/2'));
    });
  });

  group('CreeperConfig', () {
    test('creates with required fields only', () {
      final config = CreeperConfig(projectPath: '/project');

      expect(config.projectPath, equals('/project'));
      expect(config.autoApply, isFalse);
      expect(config.dryRun, isFalse);
      expect(config.model, isNull);
      expect(config.domains, isNotEmpty);
    });

    test('creates with all fields', () {
      final config = CreeperConfig(
        projectPath: '/project',
        autoApply: true,
        dryRun: true,
        model: 'opus',
        domains: [],
      );

      expect(config.projectPath, equals('/project'));
      expect(config.autoApply, isTrue);
      expect(config.dryRun, isTrue);
      expect(config.model, equals('opus'));
      expect(config.domains, isEmpty);
    });

    test('defaults to ClaudeCodeAutomationDomain', () {
      final config = CreeperConfig(projectPath: '/project');

      expect(config.domains, hasLength(1));
      expect(config.domains[0], isA<ClaudeCodeAutomationDomain>());
    });
  });

  group('Creeper', () {
    test('creates with config', () {
      final config = CreeperConfig(projectPath: '/project');
      final creeper = Creeper(config);

      expect(creeper.config, equals(config));
    });

    group('gatherContext', () {
      late Directory tempDir;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('creeper_test_');
        // Initialize a git repo in temp directory
        await Process.run('git', ['init'], workingDirectory: tempDir.path);
        await Process.run(
          'git',
          ['config', 'user.email', 'test@test.com'],
          workingDirectory: tempDir.path,
        );
        await Process.run(
          'git',
          ['config', 'user.name', 'Test'],
          workingDirectory: tempDir.path,
        );
        // Create a file and commit
        final file = File('${tempDir.path}/test.txt');
        await file.writeAsString('test content');
        await Process.run(
          'git',
          ['add', '.'],
          workingDirectory: tempDir.path,
        );
        await Process.run(
          'git',
          ['commit', '-m', 'Initial commit'],
          workingDirectory: tempDir.path,
        );
      });

      tearDown(() async {
        await tempDir.delete(recursive: true);
      });

      test('gathers context from git repo', () async {
        final config = CreeperConfig(projectPath: tempDir.path);
        final creeper = Creeper(config);

        final context = await creeper.gatherContext();

        expect(context.projectPath, equals(tempDir.path));
        expect(context.recentCommits, contains('Initial commit'));
      });

      test('gathers context with changed files', () async {
        final config = CreeperConfig(projectPath: tempDir.path);
        final creeper = Creeper(config);

        final context = await creeper.gatherContext(
          changedFiles: ['file1.dart', 'file2.dart'],
        );

        expect(context.changedFiles, contains('file1.dart'));
        expect(context.changedFiles, contains('file2.dart'));
      });

      test('gathers context with transcript content', () async {
        final config = CreeperConfig(projectPath: tempDir.path);
        final creeper = Creeper(config);

        final context = await creeper.gatherContext(
          transcriptContent:
              '{"type":"user","message":{"role":"user","content":"Hello"}}',
        );

        expect(context.transcriptAnalysis, isNotNull);
        expect(context.transcriptAnalysis!.totalEvents, equals(1));
      });

      test('gathers context with empty transcript', () async {
        final config = CreeperConfig(projectPath: tempDir.path);
        final creeper = Creeper(config);

        final context = await creeper.gatherContext(
          transcriptContent: '',
        );

        expect(context.transcriptAnalysis, isNull);
      });
    });
  });
}
