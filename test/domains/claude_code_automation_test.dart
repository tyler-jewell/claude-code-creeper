import 'package:claude_code_creeper/domains/claude_code_automation/domain.dart';
import 'package:claude_code_creeper/domains/domain.dart';
import 'package:claude_code_creeper/models/transcript_types.dart';
import 'package:test/test.dart';

void main() {
  late ClaudeCodeAutomationDomain domain;

  setUp(() {
    domain = ClaudeCodeAutomationDomain();
  });

  group('ClaudeCodeAutomationDomain', () {
    test('has correct id', () {
      expect(domain.id, equals('claude_code_automation'));
    });

    test('has correct name', () {
      expect(domain.name, equals('Claude Code Automation'));
    });

    test('has description', () {
      expect(domain.description, isNotEmpty);
    });

    test('shouldActivate always returns true', () {
      final context = AnalysisContext(
        changedFiles: [],
        projectPath: '/project',
      );
      expect(domain.shouldActivate(context), isTrue);
    });

    test('analyze returns AnalysisResult', () {
      final context = AnalysisContext(
        changedFiles: ['file.dart'],
        projectPath: '/project',
      );

      final result = domain.analyze(context);

      expect(result, isA<AnalysisResult>());
      expect(result.userPrompt, isNotEmpty);
      expect(result.systemPromptAppend, isNotEmpty);
      expect(result.allowedTools, isNotEmpty);
      expect(result.recommendedModel, equals('sonnet'));
    });

    test('analyze includes changed files in prompt', () {
      final context = AnalysisContext(
        changedFiles: ['lib/main.dart', 'test/main_test.dart'],
        projectPath: '/project',
      );

      final result = domain.analyze(context);

      expect(result.userPrompt, contains('lib/main.dart'));
      expect(result.userPrompt, contains('test/main_test.dart'));
    });

    test('analyze includes recent commits in prompt', () {
      final context = AnalysisContext(
        changedFiles: [],
        recentCommits: 'abc123 Add feature\ndef456 Fix bug',
        projectPath: '/project',
      );

      final result = domain.analyze(context);

      expect(result.userPrompt, contains('abc123'));
      expect(result.userPrompt, contains('Recent Commits'));
    });

    test('analyze includes diff stat in prompt', () {
      final context = AnalysisContext(
        changedFiles: [],
        recentDiffStat: '5 files changed, 100 insertions(+)',
        projectPath: '/project',
      );

      final result = domain.analyze(context);

      expect(result.userPrompt, contains('5 files changed'));
    });

    test('analyze includes transcript analysis', () {
      final events = [
        UserEvent(
          message: UserMessage(
            role: 'user',
            content: 'NEVER edit vendor files',
          ),
        ),
        AssistantEvent(
          message: AssistantMessage(role: 'assistant', content: [
            ToolUse(id: '1', name: 'Bash', input: {'command': 'dart test'}),
            ToolUse(id: '2', name: 'Bash', input: {'command': 'dart test'}),
            ToolUse(id: '3', name: 'Bash', input: {'command': 'dart test'}),
          ]),
        ),
      ];

      final analysis = TranscriptAnalysis.fromEvents(events);

      final context = AnalysisContext(
        changedFiles: [],
        transcriptAnalysis: analysis,
        projectPath: '/project',
      );

      final result = domain.analyze(context);

      expect(result.userPrompt, contains('USER DIRECTIVES'));
      expect(result.userPrompt, contains('NEVER edit vendor files'));
      expect(result.userPrompt, contains('REPEATED BASH COMMANDS'));
    });

    test('analyze includes allowed tools', () {
      final context = AnalysisContext(
        changedFiles: [],
        projectPath: '/project',
      );

      final result = domain.analyze(context);

      expect(result.allowedTools, contains('Read'));
      expect(result.allowedTools, contains('Edit'));
      expect(result.allowedTools, contains('Write'));
      expect(result.allowedTools, contains('Glob'));
      expect(result.allowedTools, contains('Grep'));
      expect(result.allowedTools, contains('Bash'));
    });

    test('analyze system prompt contains instructions', () {
      final context = AnalysisContext(
        changedFiles: [],
        projectPath: '/project',
      );

      final result = domain.analyze(context);

      expect(result.systemPromptAppend, contains('CREEPER MODE'));
      expect(result.systemPromptAppend, contains('STEP 1'));
      expect(result.systemPromptAppend, contains('STEP 2'));
      expect(result.systemPromptAppend, contains('STEP 3'));
    });

    test('analyze truncates long file lists', () {
      final context = AnalysisContext(
        changedFiles: List.generate(30, (i) => 'file$i.dart'),
        projectPath: '/project',
      );

      final result = domain.analyze(context);

      expect(result.userPrompt, contains('file0.dart'));
      expect(result.userPrompt, contains('file19.dart'));
      expect(result.userPrompt, contains('and 10 more'));
    });
  });
}
