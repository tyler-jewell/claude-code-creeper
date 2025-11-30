import 'package:claude_code_creeper/models/hook_types.dart';
import 'package:test/test.dart';

void main() {
  group('PermissionMode', () {
    test('fromString returns correct enum', () {
      expect(PermissionMode.fromString('default'), equals(PermissionMode.defaultMode));
      expect(PermissionMode.fromString('plan'), equals(PermissionMode.plan));
      expect(PermissionMode.fromString('acceptEdits'), equals(PermissionMode.acceptEdits));
      expect(PermissionMode.fromString('bypassPermissions'), equals(PermissionMode.bypassPermissions));
    });

    test('fromString defaults to defaultMode for unknown', () {
      expect(PermissionMode.fromString('unknown'), equals(PermissionMode.defaultMode));
    });

    test('value returns correct string', () {
      expect(PermissionMode.plan.value, equals('plan'));
    });
  });

  group('HookEventType', () {
    test('fromString returns correct enum', () {
      expect(HookEventType.fromString('PreToolUse'), equals(HookEventType.preToolUse));
      expect(HookEventType.fromString('PostToolUse'), equals(HookEventType.postToolUse));
      expect(HookEventType.fromString('UserPromptSubmit'), equals(HookEventType.userPromptSubmit));
      expect(HookEventType.fromString('Stop'), equals(HookEventType.stop));
      expect(HookEventType.fromString('SessionStart'), equals(HookEventType.sessionStart));
      expect(HookEventType.fromString('SessionEnd'), equals(HookEventType.sessionEnd));
    });

    test('fromString throws for unknown', () {
      expect(() => HookEventType.fromString('Unknown'), throwsArgumentError);
    });

    test('value returns correct string', () {
      expect(HookEventType.preToolUse.value, equals('PreToolUse'));
    });
  });

  group('SessionStartSource', () {
    test('fromString returns correct enum', () {
      expect(SessionStartSource.fromString('startup'), equals(SessionStartSource.startup));
      expect(SessionStartSource.fromString('resume'), equals(SessionStartSource.resume));
      expect(SessionStartSource.fromString('clear'), equals(SessionStartSource.clear));
      expect(SessionStartSource.fromString('compact'), equals(SessionStartSource.compact));
    });

    test('fromString defaults to startup for unknown', () {
      expect(SessionStartSource.fromString('unknown'), equals(SessionStartSource.startup));
    });
  });

  group('SessionEndReason', () {
    test('fromString returns correct enum', () {
      expect(SessionEndReason.fromString('clear'), equals(SessionEndReason.clear));
      expect(SessionEndReason.fromString('logout'), equals(SessionEndReason.logout));
      expect(SessionEndReason.fromString('prompt_input_exit'), equals(SessionEndReason.promptInputExit));
      expect(SessionEndReason.fromString('other'), equals(SessionEndReason.other));
    });

    test('fromString defaults to other for unknown', () {
      expect(SessionEndReason.fromString('unknown'), equals(SessionEndReason.other));
    });
  });

  group('PreCompactTrigger', () {
    test('fromString returns correct enum', () {
      expect(PreCompactTrigger.fromString('manual'), equals(PreCompactTrigger.manual));
      expect(PreCompactTrigger.fromString('auto'), equals(PreCompactTrigger.auto));
    });

    test('fromString defaults to auto for unknown', () {
      expect(PreCompactTrigger.fromString('unknown'), equals(PreCompactTrigger.auto));
    });
  });

  group('NotificationType', () {
    test('fromString returns correct enum', () {
      expect(NotificationType.fromString('permission_prompt'), equals(NotificationType.permissionPrompt));
      expect(NotificationType.fromString('idle_prompt'), equals(NotificationType.idlePrompt));
      expect(NotificationType.fromString('auth_success'), equals(NotificationType.authSuccess));
      expect(NotificationType.fromString('elicitation_dialog'), equals(NotificationType.elicitationDialog));
    });

    test('fromString defaults to permissionPrompt for unknown', () {
      expect(NotificationType.fromString('unknown'), equals(NotificationType.permissionPrompt));
    });
  });

  group('CommonHookInput', () {
    test('fromJson parses all fields', () {
      final json = {
        'session_id': 'sess123',
        'transcript_path': '/path/to/transcript',
        'cwd': '/project',
        'permission_mode': 'plan',
        'hook_event_name': 'PostToolUse',
      };

      final input = CommonHookInput.fromJson(json);

      expect(input.sessionId, equals('sess123'));
      expect(input.transcriptPath, equals('/path/to/transcript'));
      expect(input.cwd, equals('/project'));
      expect(input.permissionMode, equals(PermissionMode.plan));
      expect(input.hookEventName, equals('PostToolUse'));
    });

    test('fromJson handles missing fields with defaults', () {
      final input = CommonHookInput.fromJson({});

      expect(input.sessionId, isEmpty);
      expect(input.transcriptPath, isEmpty);
      expect(input.cwd, isEmpty);
      expect(input.permissionMode, equals(PermissionMode.defaultMode));
      expect(input.hookEventName, isEmpty);
    });
  });

  group('ToolInput', () {
    test('fromJson parses all fields', () {
      final json = {
        'command': 'dart test',
        'file_path': '/path/to/file.dart',
        'old_string': 'old',
        'new_string': 'new',
        'content': 'file content',
        'pattern': '*.dart',
      };

      final input = ToolInput.fromJson(json);

      expect(input.command, equals('dart test'));
      expect(input.filePath, equals('/path/to/file.dart'));
      expect(input.oldString, equals('old'));
      expect(input.newString, equals('new'));
      expect(input.content, equals('file content'));
      expect(input.pattern, equals('*.dart'));
      expect(input.raw, equals(json));
    });

    test('toJson returns raw', () {
      final json = {'command': 'test'};
      final input = ToolInput.fromJson(json);
      expect(input.toJson(), equals(json));
    });

    test('fromJson handles missing fields', () {
      final input = ToolInput.fromJson({});

      expect(input.command, isNull);
      expect(input.filePath, isNull);
    });
  });

  group('PreToolUseInput', () {
    test('fromJson parses all fields', () {
      final json = {
        'session_id': 'sess123',
        'transcript_path': '/transcript',
        'cwd': '/project',
        'permission_mode': 'default',
        'hook_event_name': 'PreToolUse',
        'tool_name': 'Edit',
        'tool_input': {'file_path': '/file.dart'},
        'tool_use_id': 'tool123',
      };

      final input = PreToolUseInput.fromJson(json);

      expect(input.toolName, equals('Edit'));
      expect(input.toolInput.filePath, equals('/file.dart'));
      expect(input.toolUseId, equals('tool123'));
    });

    test('fromJson handles missing tool_input', () {
      final json = {
        'session_id': 'sess',
        'transcript_path': '/t',
        'cwd': '/',
        'permission_mode': 'default',
        'hook_event_name': 'PreToolUse',
        'tool_name': 'Read',
        'tool_use_id': '123',
      };

      final input = PreToolUseInput.fromJson(json);
      expect(input.toolInput.raw, isEmpty);
    });
  });

  group('PostToolUseInput', () {
    test('fromJson parses all fields', () {
      final json = {
        'session_id': 'sess123',
        'transcript_path': '/transcript',
        'cwd': '/project',
        'permission_mode': 'acceptEdits',
        'hook_event_name': 'PostToolUse',
        'tool_name': 'Bash',
        'tool_input': {'command': 'dart test'},
        'tool_response': {'output': 'All tests passed'},
        'tool_use_id': 'tool456',
      };

      final input = PostToolUseInput.fromJson(json);

      expect(input.toolName, equals('Bash'));
      expect(input.toolInput.command, equals('dart test'));
      expect(input.toolResponse['output'], equals('All tests passed'));
      expect(input.toolUseId, equals('tool456'));
    });
  });

  group('UserPromptSubmitInput', () {
    test('fromJson parses all fields', () {
      final json = {
        'session_id': 'sess123',
        'transcript_path': '/transcript',
        'cwd': '/project',
        'permission_mode': 'default',
        'hook_event_name': 'UserPromptSubmit',
        'prompt': 'Help me fix this bug',
      };

      final input = UserPromptSubmitInput.fromJson(json);

      expect(input.prompt, equals('Help me fix this bug'));
    });
  });

  group('SessionStartInput', () {
    test('fromJson parses all fields', () {
      final json = {
        'session_id': 'sess123',
        'transcript_path': '/transcript',
        'cwd': '/project',
        'permission_mode': 'default',
        'hook_event_name': 'SessionStart',
        'source': 'resume',
      };

      final input = SessionStartInput.fromJson(json);

      expect(input.source, equals(SessionStartSource.resume));
    });
  });

  group('SessionEndInput', () {
    test('fromJson parses all fields', () {
      final json = {
        'session_id': 'sess123',
        'transcript_path': '/transcript',
        'cwd': '/project',
        'permission_mode': 'default',
        'hook_event_name': 'SessionEnd',
        'reason': 'logout',
      };

      final input = SessionEndInput.fromJson(json);

      expect(input.reason, equals(SessionEndReason.logout));
    });
  });

  group('PreCompactInput', () {
    test('fromJson parses all fields', () {
      final json = {
        'session_id': 'sess123',
        'transcript_path': '/transcript',
        'cwd': '/project',
        'permission_mode': 'default',
        'hook_event_name': 'PreCompact',
        'trigger': 'manual',
        'custom_instructions': 'Keep the error summary',
      };

      final input = PreCompactInput.fromJson(json);

      expect(input.trigger, equals(PreCompactTrigger.manual));
      expect(input.customInstructions, equals('Keep the error summary'));
    });

    test('fromJson handles null custom_instructions', () {
      final json = {
        'session_id': 'sess',
        'transcript_path': '/t',
        'cwd': '/',
        'permission_mode': 'default',
        'hook_event_name': 'PreCompact',
        'trigger': 'auto',
      };

      final input = PreCompactInput.fromJson(json);
      expect(input.customInstructions, isNull);
    });
  });

  group('StopHookInput', () {
    test('fromJson parses all fields', () {
      final json = {
        'session_id': 'sess123',
        'transcript_path': '/transcript',
        'cwd': '/project',
        'permission_mode': 'default',
        'hook_event_name': 'Stop',
        'stop_hook_active': true,
      };

      final input = StopHookInput.fromJson(json);

      expect(input.stopHookActive, isTrue);
    });

    test('fromJson defaults stop_hook_active to false', () {
      final json = {
        'session_id': 'sess',
        'transcript_path': '/t',
        'cwd': '/',
        'permission_mode': 'default',
        'hook_event_name': 'Stop',
      };

      final input = StopHookInput.fromJson(json);
      expect(input.stopHookActive, isFalse);
    });
  });

  group('NotificationInput', () {
    test('fromJson parses all fields', () {
      final json = {
        'session_id': 'sess123',
        'transcript_path': '/transcript',
        'cwd': '/project',
        'permission_mode': 'default',
        'hook_event_name': 'Notification',
        'message': 'Permission required',
        'notification_type': 'permission_prompt',
      };

      final input = NotificationInput.fromJson(json);

      expect(input.message, equals('Permission required'));
      expect(input.notificationType, equals(NotificationType.permissionPrompt));
    });
  });
}
