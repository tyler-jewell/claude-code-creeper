/// Claude Code Hook Types
///
/// Typed Dart models for Claude Code hook inputs and outputs.
/// Based on: lib/schemas/claude_code_hooks_schema.json
library hook_types;

// =============================================================================
// ENUMS
// =============================================================================

/// Permission modes available in Claude Code
enum PermissionMode {
  defaultMode('default'),
  plan('plan'),
  acceptEdits('acceptEdits'),
  bypassPermissions('bypassPermissions');

  const PermissionMode(this.value);
  final String value;

  static PermissionMode fromString(String value) {
    return PermissionMode.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PermissionMode.defaultMode,
    );
  }
}

/// Hook event types
enum HookEventType {
  preToolUse('PreToolUse'),
  postToolUse('PostToolUse'),
  userPromptSubmit('UserPromptSubmit'),
  stop('Stop'),
  subagentStop('SubagentStop'),
  preCompact('PreCompact'),
  sessionStart('SessionStart'),
  sessionEnd('SessionEnd'),
  notification('Notification'),
  permissionRequest('PermissionRequest');

  const HookEventType(this.value);
  final String value;

  static HookEventType fromString(String value) {
    return HookEventType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError('Unknown hook event: $value'),
    );
  }
}

/// Session start sources
enum SessionStartSource {
  startup('startup'),
  resume('resume'),
  clear('clear'),
  compact('compact');

  const SessionStartSource(this.value);
  final String value;

  static SessionStartSource fromString(String value) {
    return SessionStartSource.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SessionStartSource.startup,
    );
  }
}

/// Session end reasons
enum SessionEndReason {
  clear('clear'),
  logout('logout'),
  promptInputExit('prompt_input_exit'),
  other('other');

  const SessionEndReason(this.value);
  final String value;

  static SessionEndReason fromString(String value) {
    return SessionEndReason.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SessionEndReason.other,
    );
  }
}

/// PreCompact trigger types
enum PreCompactTrigger {
  manual('manual'),
  auto('auto');

  const PreCompactTrigger(this.value);
  final String value;

  static PreCompactTrigger fromString(String value) {
    return PreCompactTrigger.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PreCompactTrigger.auto,
    );
  }
}

/// Notification types
enum NotificationType {
  permissionPrompt('permission_prompt'),
  idlePrompt('idle_prompt'),
  authSuccess('auth_success'),
  elicitationDialog('elicitation_dialog');

  const NotificationType(this.value);
  final String value;

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotificationType.permissionPrompt,
    );
  }
}

// =============================================================================
// HOOK INPUT MODELS
// =============================================================================

/// Common fields present in all hook inputs
class CommonHookInput {
  final String sessionId;
  final String transcriptPath;
  final String cwd;
  final PermissionMode permissionMode;
  final String hookEventName;

  CommonHookInput({
    required this.sessionId,
    required this.transcriptPath,
    required this.cwd,
    required this.permissionMode,
    required this.hookEventName,
  });

  factory CommonHookInput.fromJson(Map<String, dynamic> json) {
    return CommonHookInput(
      sessionId: json['session_id'] as String? ?? '',
      transcriptPath: json['transcript_path'] as String? ?? '',
      cwd: json['cwd'] as String? ?? '',
      permissionMode: PermissionMode.fromString(
        json['permission_mode'] as String? ?? 'default',
      ),
      hookEventName: json['hook_event_name'] as String? ?? '',
    );
  }
}

/// Tool input structure (varies by tool type)
class ToolInput {
  final String? command;
  final String? filePath;
  final String? oldString;
  final String? newString;
  final String? content;
  final String? pattern;
  final Map<String, dynamic> raw;

  ToolInput({
    this.command,
    this.filePath,
    this.oldString,
    this.newString,
    this.content,
    this.pattern,
    required this.raw,
  });

  factory ToolInput.fromJson(Map<String, dynamic> json) {
    return ToolInput(
      command: json['command'] as String?,
      filePath: json['file_path'] as String?,
      oldString: json['old_string'] as String?,
      newString: json['new_string'] as String?,
      content: json['content'] as String?,
      pattern: json['pattern'] as String?,
      raw: json,
    );
  }

  Map<String, dynamic> toJson() => raw;
}

/// PreToolUse hook input
class PreToolUseInput extends CommonHookInput {
  final String toolName;
  final ToolInput toolInput;
  final String toolUseId;

  PreToolUseInput({
    required super.sessionId,
    required super.transcriptPath,
    required super.cwd,
    required super.permissionMode,
    required super.hookEventName,
    required this.toolName,
    required this.toolInput,
    required this.toolUseId,
  });

  factory PreToolUseInput.fromJson(Map<String, dynamic> json) {
    final common = CommonHookInput.fromJson(json);
    return PreToolUseInput(
      sessionId: common.sessionId,
      transcriptPath: common.transcriptPath,
      cwd: common.cwd,
      permissionMode: common.permissionMode,
      hookEventName: common.hookEventName,
      toolName: json['tool_name'] as String? ?? '',
      toolInput: ToolInput.fromJson(
        json['tool_input'] as Map<String, dynamic>? ?? {},
      ),
      toolUseId: json['tool_use_id'] as String? ?? '',
    );
  }
}

/// PostToolUse hook input
class PostToolUseInput extends CommonHookInput {
  final String toolName;
  final ToolInput toolInput;
  final Map<String, dynamic> toolResponse;
  final String toolUseId;

  PostToolUseInput({
    required super.sessionId,
    required super.transcriptPath,
    required super.cwd,
    required super.permissionMode,
    required super.hookEventName,
    required this.toolName,
    required this.toolInput,
    required this.toolResponse,
    required this.toolUseId,
  });

  factory PostToolUseInput.fromJson(Map<String, dynamic> json) {
    final common = CommonHookInput.fromJson(json);
    return PostToolUseInput(
      sessionId: common.sessionId,
      transcriptPath: common.transcriptPath,
      cwd: common.cwd,
      permissionMode: common.permissionMode,
      hookEventName: common.hookEventName,
      toolName: json['tool_name'] as String? ?? '',
      toolInput: ToolInput.fromJson(
        json['tool_input'] as Map<String, dynamic>? ?? {},
      ),
      toolResponse: json['tool_response'] as Map<String, dynamic>? ?? {},
      toolUseId: json['tool_use_id'] as String? ?? '',
    );
  }
}

/// UserPromptSubmit hook input
class UserPromptSubmitInput extends CommonHookInput {
  final String prompt;

  UserPromptSubmitInput({
    required super.sessionId,
    required super.transcriptPath,
    required super.cwd,
    required super.permissionMode,
    required super.hookEventName,
    required this.prompt,
  });

  factory UserPromptSubmitInput.fromJson(Map<String, dynamic> json) {
    final common = CommonHookInput.fromJson(json);
    return UserPromptSubmitInput(
      sessionId: common.sessionId,
      transcriptPath: common.transcriptPath,
      cwd: common.cwd,
      permissionMode: common.permissionMode,
      hookEventName: common.hookEventName,
      prompt: json['prompt'] as String? ?? '',
    );
  }
}

/// SessionStart hook input
class SessionStartInput extends CommonHookInput {
  final SessionStartSource source;

  SessionStartInput({
    required super.sessionId,
    required super.transcriptPath,
    required super.cwd,
    required super.permissionMode,
    required super.hookEventName,
    required this.source,
  });

  factory SessionStartInput.fromJson(Map<String, dynamic> json) {
    final common = CommonHookInput.fromJson(json);
    return SessionStartInput(
      sessionId: common.sessionId,
      transcriptPath: common.transcriptPath,
      cwd: common.cwd,
      permissionMode: common.permissionMode,
      hookEventName: common.hookEventName,
      source: SessionStartSource.fromString(json['source'] as String? ?? ''),
    );
  }
}

/// SessionEnd hook input
class SessionEndInput extends CommonHookInput {
  final SessionEndReason reason;

  SessionEndInput({
    required super.sessionId,
    required super.transcriptPath,
    required super.cwd,
    required super.permissionMode,
    required super.hookEventName,
    required this.reason,
  });

  factory SessionEndInput.fromJson(Map<String, dynamic> json) {
    final common = CommonHookInput.fromJson(json);
    return SessionEndInput(
      sessionId: common.sessionId,
      transcriptPath: common.transcriptPath,
      cwd: common.cwd,
      permissionMode: common.permissionMode,
      hookEventName: common.hookEventName,
      reason: SessionEndReason.fromString(json['reason'] as String? ?? ''),
    );
  }
}

/// PreCompact hook input
class PreCompactInput extends CommonHookInput {
  final PreCompactTrigger trigger;
  final String? customInstructions;

  PreCompactInput({
    required super.sessionId,
    required super.transcriptPath,
    required super.cwd,
    required super.permissionMode,
    required super.hookEventName,
    required this.trigger,
    this.customInstructions,
  });

  factory PreCompactInput.fromJson(Map<String, dynamic> json) {
    final common = CommonHookInput.fromJson(json);
    return PreCompactInput(
      sessionId: common.sessionId,
      transcriptPath: common.transcriptPath,
      cwd: common.cwd,
      permissionMode: common.permissionMode,
      hookEventName: common.hookEventName,
      trigger: PreCompactTrigger.fromString(json['trigger'] as String? ?? ''),
      customInstructions: json['custom_instructions'] as String?,
    );
  }
}

/// Stop/SubagentStop hook input
class StopHookInput extends CommonHookInput {
  final bool stopHookActive;

  StopHookInput({
    required super.sessionId,
    required super.transcriptPath,
    required super.cwd,
    required super.permissionMode,
    required super.hookEventName,
    required this.stopHookActive,
  });

  factory StopHookInput.fromJson(Map<String, dynamic> json) {
    final common = CommonHookInput.fromJson(json);
    return StopHookInput(
      sessionId: common.sessionId,
      transcriptPath: common.transcriptPath,
      cwd: common.cwd,
      permissionMode: common.permissionMode,
      hookEventName: common.hookEventName,
      stopHookActive: json['stop_hook_active'] as bool? ?? false,
    );
  }
}

/// Notification hook input
class NotificationInput extends CommonHookInput {
  final String message;
  final NotificationType notificationType;

  NotificationInput({
    required super.sessionId,
    required super.transcriptPath,
    required super.cwd,
    required super.permissionMode,
    required super.hookEventName,
    required this.message,
    required this.notificationType,
  });

  factory NotificationInput.fromJson(Map<String, dynamic> json) {
    final common = CommonHookInput.fromJson(json);
    return NotificationInput(
      sessionId: common.sessionId,
      transcriptPath: common.transcriptPath,
      cwd: common.cwd,
      permissionMode: common.permissionMode,
      hookEventName: common.hookEventName,
      message: json['message'] as String? ?? '',
      notificationType: NotificationType.fromString(
        json['notification_type'] as String? ?? '',
      ),
    );
  }
}
