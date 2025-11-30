import 'package:claude_code_creeper/models/transcript_types.dart';
import 'package:test/test.dart';

void main() {
  group('TranscriptEvent', () {
    test('parseTranscript handles empty input', () {
      final events = TranscriptEvent.parseTranscript('');
      expect(events, isEmpty);
    });

    test('parseTranscript handles whitespace-only input', () {
      final events = TranscriptEvent.parseTranscript('   \n\n   ');
      expect(events, isEmpty);
    });

    test('parseTranscript parses user event', () {
      const json = '{"type":"user","message":{"role":"user","content":"Hello"}}';
      final events = TranscriptEvent.parseTranscript(json);

      expect(events.length, equals(1));
      expect(events[0], isA<UserEvent>());

      final userEvent = events[0] as UserEvent;
      expect(userEvent.message.textContent, equals('Hello'));
    });

    test('parseTranscript parses assistant event', () {
      const json =
          '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Hello back"}]}}';
      final events = TranscriptEvent.parseTranscript(json);

      expect(events.length, equals(1));
      expect(events[0], isA<AssistantEvent>());

      final assistantEvent = events[0] as AssistantEvent;
      expect(assistantEvent.message.textContent, equals('Hello back'));
    });

    test('parseTranscript parses system event', () {
      const json = '{"type":"system","subtype":"init","session_id":"abc123"}';
      final events = TranscriptEvent.parseTranscript(json);

      expect(events.length, equals(1));
      expect(events[0], isA<SystemEvent>());

      final systemEvent = events[0] as SystemEvent;
      expect(systemEvent.subtype, equals('init'));
      expect(systemEvent.sessionId, equals('abc123'));
    });

    test('parseTranscript parses result event', () {
      const json =
          '{"type":"result","subtype":"success","is_error":false,"duration_ms":1000,"num_turns":5}';
      final events = TranscriptEvent.parseTranscript(json);

      expect(events.length, equals(1));
      expect(events[0], isA<ResultEvent>());

      final resultEvent = events[0] as ResultEvent;
      expect(resultEvent.isError, isFalse);
      expect(resultEvent.durationMs, equals(1000));
      expect(resultEvent.numTurns, equals(5));
    });

    test('parseTranscript returns UnknownEvent for unknown type', () {
      const json = '{"type":"custom","data":"something"}';
      final events = TranscriptEvent.parseTranscript(json);

      expect(events.length, equals(1));
      expect(events[0], isA<UnknownEvent>());
    });

    test('parseTranscript handles invalid JSON gracefully', () {
      const json = 'not valid json\n{"type":"user","message":{"role":"user","content":"Hi"}}';
      final events = TranscriptEvent.parseTranscript(json);

      // Should skip invalid line and parse valid one
      expect(events.length, equals(1));
      expect(events[0], isA<UserEvent>());
    });

    test('parseTranscript handles multiple events', () {
      const json = '''
{"type":"user","message":{"role":"user","content":"Hello"}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Hi"}]}}
{"type":"user","message":{"role":"user","content":"How are you?"}}
''';
      final events = TranscriptEvent.parseTranscript(json);

      expect(events.length, equals(3));
      expect(events[0], isA<UserEvent>());
      expect(events[1], isA<AssistantEvent>());
      expect(events[2], isA<UserEvent>());
    });
  });

  group('UserMessage', () {
    test('textContent returns string content directly', () {
      final message = UserMessage(role: 'user', content: 'Hello world');
      expect(message.textContent, equals('Hello world'));
    });

    test('isToolResult returns false for string content', () {
      final message = UserMessage(role: 'user', content: 'test');
      expect(message.isToolResult, isFalse);
    });

    test('isToolResult returns true for tool result list', () {
      final message = UserMessage(role: 'user', content: [
        {'type': 'tool_result', 'tool_use_id': '123', 'content': 'result'},
      ]);
      expect(message.isToolResult, isTrue);
    });

    test('toolResults returns empty list for non-tool content', () {
      final message = UserMessage(role: 'user', content: 'Hello');
      expect(message.toolResults, isEmpty);
    });

    test('toolResults parses tool result list', () {
      final message = UserMessage(role: 'user', content: [
        {'type': 'tool_result', 'tool_use_id': '123', 'content': 'result'},
      ]);
      expect(message.toolResults, hasLength(1));
      expect(message.toolResults[0].toolUseId, equals('123'));
    });

    test('textContent extracts text from tool results', () {
      final message = UserMessage(role: 'user', content: [
        {'type': 'tool_result', 'content': 'output text'},
      ]);
      expect(message.textContent, contains('output text'));
    });
  });

  group('AssistantMessage', () {
    test('textContent concatenates all text content', () {
      final message = AssistantMessage(role: 'assistant', content: [
        TextContent(text: 'Hello'),
        TextContent(text: 'world'),
      ]);
      // textContent joins with newline separator
      expect(message.textContent, equals('Hello\nworld'));
    });

    test('toolUses returns only ToolUse items', () {
      final message = AssistantMessage(role: 'assistant', content: [
        TextContent(text: 'Let me help'),
        ToolUse(id: '1', name: 'Read', input: {'path': '/file'}),
        TextContent(text: 'Done'),
      ]);
      expect(message.toolUses.length, equals(1));
      expect(message.toolUses[0].name, equals('Read'));
    });

    test('handles empty content list', () {
      final message = AssistantMessage(role: 'assistant', content: []);
      expect(message.textContent, isEmpty);
      expect(message.toolUses, isEmpty);
    });
  });

  group('ToolUse', () {
    test('bashCommand extracts command from Bash tool', () {
      final toolUse = ToolUse(
        id: '1',
        name: 'Bash',
        input: {'command': 'dart test'},
      );
      expect(toolUse.bashCommand, equals('dart test'));
    });

    test('bashCommand returns null for non-Bash tool', () {
      final toolUse = ToolUse(
        id: '1',
        name: 'Read',
        input: {'file_path': '/path'},
      );
      expect(toolUse.bashCommand, isNull);
    });

    test('filePath extracts file_path from input', () {
      final toolUse = ToolUse(
        id: '1',
        name: 'Read',
        input: {'file_path': '/path/to/file.dart'},
      );
      expect(toolUse.filePath, equals('/path/to/file.dart'));
    });

    test('filePath returns null when not present', () {
      final toolUse = ToolUse(
        id: '1',
        name: 'Bash',
        input: {'command': 'ls'},
      );
      expect(toolUse.filePath, isNull);
    });
  });

  group('ToolResult', () {
    test('parses all fields', () {
      final json = {
        'type': 'tool_result',
        'tool_use_id': '123',
        'content': 'Success',
        'is_error': false,
      };
      final result = ToolResult.fromJson(json);

      expect(result.type, equals('tool_result'));
      expect(result.toolUseId, equals('123'));
      expect(result.content, equals('Success'));
      expect(result.isError, isFalse);
    });

    test('defaults isError to false', () {
      final json = {
        'type': 'tool_result',
        'tool_use_id': '123',
        'content': 'Output',
      };
      final result = ToolResult.fromJson(json);
      expect(result.isError, isFalse);
    });
  });

  group('TranscriptAnalysis', () {
    test('fromEvents extracts tool usage counts', () {
      final events = [
        UserEvent(
          message: UserMessage(role: 'user', content: 'Read this file'),
        ),
        AssistantEvent(
          message: AssistantMessage(role: 'assistant', content: [
            ToolUse(id: '1', name: 'Read', input: {'file_path': '/a'}),
            ToolUse(id: '2', name: 'Read', input: {'file_path': '/b'}),
            ToolUse(id: '3', name: 'Edit', input: {'file_path': '/a'}),
          ]),
        ),
      ];

      final analysis = TranscriptAnalysis.fromEvents(events);

      expect(analysis.toolUsage['Read'], equals(2));
      expect(analysis.toolUsage['Edit'], equals(1));
    });

    test('fromEvents extracts bash commands', () {
      final events = [
        AssistantEvent(
          message: AssistantMessage(role: 'assistant', content: [
            ToolUse(id: '1', name: 'Bash', input: {'command': 'dart test'}),
            ToolUse(id: '2', name: 'Bash', input: {'command': 'dart test'}),
            ToolUse(id: '3', name: 'Bash', input: {'command': 'dart analyze'}),
          ]),
        ),
      ];

      final analysis = TranscriptAnalysis.fromEvents(events);

      // bashCommands stores full normalized command, not just first word
      expect(analysis.bashCommands['dart test'], equals(2));
      expect(analysis.bashCommands['dart analyze'], equals(1));
    });

    test('fromEvents extracts user directives', () {
      final events = [
        UserEvent(
          message: UserMessage(
            role: 'user',
            content: 'NEVER edit vendor files',
          ),
        ),
        UserEvent(
          message: UserMessage(
            role: 'user',
            content: 'ALWAYS run tests first',
          ),
        ),
        UserEvent(
          message: UserMessage(
            role: 'user',
            content: 'Just a normal message',
          ),
        ),
      ];

      final analysis = TranscriptAnalysis.fromEvents(events);

      expect(analysis.userDirectives.length, equals(2));
      expect(analysis.userDirectives, contains('NEVER edit vendor files'));
      expect(analysis.userDirectives, contains('ALWAYS run tests first'));
    });

    test('fromEvents handles empty events', () {
      final analysis = TranscriptAnalysis.fromEvents([]);

      expect(analysis.toolUsage, isEmpty);
      expect(analysis.bashCommands, isEmpty);
      expect(analysis.errors, isEmpty);
      expect(analysis.userPrompts, isEmpty);
      expect(analysis.userDirectives, isEmpty);
      expect(analysis.totalEvents, equals(0));
    });

    test('fromEvents collects user prompts', () {
      final events = [
        UserEvent(
          message: UserMessage(role: 'user', content: 'Help me fix this bug'),
        ),
        UserEvent(
          message: UserMessage(role: 'user', content: 'Now add a feature'),
        ),
      ];

      final analysis = TranscriptAnalysis.fromEvents(events);

      expect(analysis.userPrompts.length, equals(2));
    });

    test('fromEvents counts total events', () {
      final events = [
        UserEvent(message: UserMessage(role: 'user', content: 'Hi')),
        AssistantEvent(message: AssistantMessage(role: 'assistant', content: [])),
        SystemEvent(subtype: 'init', sessionId: '123', model: 'test', raw: {}),
        ResultEvent(subtype: 'success', isError: false, durationMs: 100, numTurns: 1, raw: {}),
      ];

      final analysis = TranscriptAnalysis.fromEvents(events);

      expect(analysis.totalEvents, equals(4));
    });
  });

  group('AssistantContent', () {
    test('TextContent holds text', () {
      final content = TextContent(text: 'Hello');
      expect(content.text, equals('Hello'));
    });

    test('TextContent.fromJson parses text', () {
      final content = TextContent.fromJson({'text': 'Hello world'});
      expect(content.text, equals('Hello world'));
      expect(content.type, equals('text'));
    });

    test('ToolUse.fromJson parses all fields', () {
      final toolUse = ToolUse.fromJson({
        'id': 'tool_123',
        'name': 'Read',
        'input': {'file_path': '/path/to/file'},
      });
      expect(toolUse.id, equals('tool_123'));
      expect(toolUse.name, equals('Read'));
      expect(toolUse.input['file_path'], equals('/path/to/file'));
      expect(toolUse.type, equals('tool_use'));
    });

    test('ToolUse.fromJson handles missing fields', () {
      final toolUse = ToolUse.fromJson({});
      expect(toolUse.id, equals(''));
      expect(toolUse.name, equals(''));
      expect(toolUse.input, isEmpty);
    });

    test('AssistantContent.fromJson handles tool_use type', () {
      final content = AssistantContent.fromJson({
        'type': 'tool_use',
        'id': '123',
        'name': 'Bash',
        'input': {'command': 'ls'},
      });
      expect(content, isA<ToolUse>());
      final toolUse = content as ToolUse;
      expect(toolUse.name, equals('Bash'));
    });

    test('AssistantContent.fromJson handles unknown type', () {
      final content = AssistantContent.fromJson({
        'type': 'thinking',
        'data': 'some data',
      });
      expect(content, isA<UnknownContent>());
      final unknown = content as UnknownContent;
      expect(unknown.type, equals('thinking'));
      expect(unknown.raw['data'], equals('some data'));
    });

    test('UnknownContent holds raw JSON', () {
      final content = UnknownContent(type: 'custom', raw: {'data': 'value'});
      expect(content.raw['data'], equals('value'));
      expect(content.type, equals('custom'));
    });
  });

  group('TranscriptAnalysis', () {
    test('toJson serializes all fields', () {
      final analysis = TranscriptAnalysis(
        toolUsage: {'Read': 5, 'Edit': 3},
        bashCommands: {'dart test': 2},
        errors: ['Error: file not found'],
        userPrompts: ['Fix the bug'],
        userDirectives: ['NEVER edit vendor'],
        totalEvents: 10,
      );

      final json = analysis.toJson();

      expect(json['tool_usage'], equals({'Read': 5, 'Edit': 3}));
      expect(json['bash_commands'], equals({'dart test': 2}));
      expect(json['recent_errors'], equals(['Error: file not found']));
      expect(json['user_prompts'], equals(['Fix the bug']));
      expect(json['user_directives'], equals(['NEVER edit vendor']));
      expect(json['total_events'], equals(10));
    });

    test('fromEvents extracts errors from user messages', () {
      final events = [
        UserEvent(
          message: UserMessage(
            role: 'user',
            content: 'I got this Error: undefined method',
          ),
        ),
        UserEvent(
          message: UserMessage(
            role: 'user',
            content: 'The build error: missing semicolon',
          ),
        ),
        UserEvent(
          message: UserMessage(
            role: 'user',
            content: 'Test failed for some reason',
          ),
        ),
      ];

      final analysis = TranscriptAnalysis.fromEvents(events);

      expect(analysis.errors.length, equals(3));
      expect(analysis.errors[0], contains('Error'));
      expect(analysis.errors[1], contains('error:'));
      expect(analysis.errors[2], contains('failed'));
    });

    test('fromEvents extracts errors from tool results', () {
      final events = [
        UserEvent(
          message: UserMessage(role: 'user', content: [
            {
              'type': 'tool_result',
              'tool_use_id': '123',
              'content': 'Error: compilation failed',
              'is_error': true,
            },
          ]),
        ),
      ];

      final analysis = TranscriptAnalysis.fromEvents(events);

      expect(analysis.errors.length, equals(1));
      expect(analysis.errors[0], contains('Error'));
    });

    test('fromEvents limits errors to 5', () {
      final events = List.generate(
        10,
        (i) => UserEvent(
          message: UserMessage(role: 'user', content: 'Error number $i'),
        ),
      );

      final analysis = TranscriptAnalysis.fromEvents(events);

      expect(analysis.errors.length, equals(5));
    });
  });
}
