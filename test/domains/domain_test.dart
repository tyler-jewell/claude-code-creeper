import 'package:claude_code_creeper/domains/domain.dart';
import 'package:test/test.dart';

void main() {
  group('AnalysisContext', () {
    test('creates with all fields', () {
      final context = AnalysisContext(
        changedFiles: ['file1.dart', 'file2.dart'],
        recentCommits: 'abc123 commit 1\ndef456 commit 2',
        recentDiffStat: '2 files changed',
        projectPath: '/project',
      );

      expect(context.changedFiles, hasLength(2));
      expect(context.recentCommits, contains('abc123'));
      expect(context.recentDiffStat, equals('2 files changed'));
      expect(context.transcriptAnalysis, isNull);
      expect(context.projectPath, equals('/project'));
    });

    test('creates with empty changed files', () {
      final context = AnalysisContext(
        changedFiles: [],
        projectPath: '/project',
      );

      expect(context.changedFiles, isEmpty);
      expect(context.recentCommits, isNull);
    });
  });

  group('AnalysisResult', () {
    test('creates with all fields', () {
      final result = AnalysisResult(
        userPrompt: 'Analyze this',
        systemPromptAppend: 'System instructions',
        allowedTools: ['Read', 'Edit'],
        recommendedModel: 'sonnet',
      );

      expect(result.userPrompt, equals('Analyze this'));
      expect(result.systemPromptAppend, equals('System instructions'));
      expect(result.allowedTools, contains('Read'));
      expect(result.recommendedModel, equals('sonnet'));
    });

    test('creates with default values', () {
      final result = AnalysisResult(
        userPrompt: 'prompt',
        systemPromptAppend: 'system',
      );

      // Default allowed tools
      expect(result.allowedTools, contains('Read'));
      expect(result.allowedTools, contains('Edit'));
      expect(result.recommendedModel, isNull);
    });

    test('creates with custom allowed tools', () {
      final result = AnalysisResult(
        userPrompt: 'prompt',
        systemPromptAppend: 'system',
        allowedTools: ['Read'],
      );

      expect(result.allowedTools, equals(['Read']));
    });
  });
}
