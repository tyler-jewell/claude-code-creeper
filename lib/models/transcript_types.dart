/// Claude Code Transcript Types
///
/// Typed models for parsing Claude Code session transcripts (.jsonl files)

import 'dart:convert';

// =============================================================================
// TRANSCRIPT EVENT TYPES
// =============================================================================

/// Base class for transcript events
sealed class TranscriptEvent {
  final String type;

  TranscriptEvent({required this.type});

  factory TranscriptEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';

    return switch (type) {
      'user' => UserEvent.fromJson(json),
      'assistant' => AssistantEvent.fromJson(json),
      'system' => SystemEvent.fromJson(json),
      'result' => ResultEvent.fromJson(json),
      _ => UnknownEvent(type: type, raw: json),
    };
  }

  static List<TranscriptEvent> parseTranscript(String content) {
    final events = <TranscriptEvent>[];
    for (final line in content.split('\n')) {
      if (line.trim().isEmpty) continue;
      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        events.add(TranscriptEvent.fromJson(json));
      } catch (_) {
        // Skip malformed lines
      }
    }
    return events;
  }
}

/// User message event
class UserEvent extends TranscriptEvent {
  final UserMessage message;

  UserEvent({required this.message}) : super(type: 'user');

  factory UserEvent.fromJson(Map<String, dynamic> json) {
    return UserEvent(
      message: UserMessage.fromJson(
        json['message'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

/// Assistant message event
class AssistantEvent extends TranscriptEvent {
  final AssistantMessage message;

  AssistantEvent({required this.message}) : super(type: 'assistant');

  factory AssistantEvent.fromJson(Map<String, dynamic> json) {
    return AssistantEvent(
      message: AssistantMessage.fromJson(
        json['message'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

/// System event (init, etc.)
class SystemEvent extends TranscriptEvent {
  final String subtype;
  final String? sessionId;
  final String? model;
  final Map<String, dynamic> raw;

  SystemEvent({
    required this.subtype,
    this.sessionId,
    this.model,
    required this.raw,
  }) : super(type: 'system');

  factory SystemEvent.fromJson(Map<String, dynamic> json) {
    return SystemEvent(
      subtype: json['subtype'] as String? ?? '',
      sessionId: json['session_id'] as String?,
      model: json['model'] as String?,
      raw: json,
    );
  }
}

/// Result event (end of session)
class ResultEvent extends TranscriptEvent {
  final String subtype;
  final bool isError;
  final int durationMs;
  final int numTurns;
  final String? result;
  final double? totalCostUsd;
  final Map<String, dynamic> raw;

  ResultEvent({
    required this.subtype,
    required this.isError,
    required this.durationMs,
    required this.numTurns,
    this.result,
    this.totalCostUsd,
    required this.raw,
  }) : super(type: 'result');

  factory ResultEvent.fromJson(Map<String, dynamic> json) {
    return ResultEvent(
      subtype: json['subtype'] as String? ?? '',
      isError: json['is_error'] as bool? ?? false,
      durationMs: json['duration_ms'] as int? ?? 0,
      numTurns: json['num_turns'] as int? ?? 0,
      result: json['result'] as String?,
      totalCostUsd: (json['total_cost_usd'] as num?)?.toDouble(),
      raw: json,
    );
  }
}

/// Unknown event type
class UnknownEvent extends TranscriptEvent {
  final Map<String, dynamic> raw;

  UnknownEvent({required super.type, required this.raw});
}

// =============================================================================
// MESSAGE TYPES
// =============================================================================

/// User message content
class UserMessage {
  final String role;
  final dynamic content; // Can be String or List<ToolResult>

  UserMessage({required this.role, required this.content});

  factory UserMessage.fromJson(Map<String, dynamic> json) {
    return UserMessage(
      role: json['role'] as String? ?? 'user',
      content: json['content'],
    );
  }

  /// Get content as plain text (handles both string and tool_result formats)
  String get textContent {
    if (content is String) {
      return content as String;
    }
    if (content is List) {
      // Extract text from tool results
      return (content as List)
          .map((item) {
            if (item is Map) {
              return item['content']?.toString() ?? '';
            }
            return '';
          })
          .join('\n');
    }
    return '';
  }

  /// Check if this is a tool result message
  bool get isToolResult {
    if (content is! List) return false;
    final list = content as List;
    if (list.isEmpty) return false;
    final first = list.first;
    return first is Map && first['type'] == 'tool_result';
  }

  /// Get tool results if this is a tool result message
  List<ToolResult> get toolResults {
    if (!isToolResult) return [];
    return (content as List)
        .map((item) => ToolResult.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

/// Assistant message content
class AssistantMessage {
  final String role;
  final List<AssistantContent> content;
  final String? model;

  AssistantMessage({
    required this.role,
    required this.content,
    this.model,
  });

  factory AssistantMessage.fromJson(Map<String, dynamic> json) {
    final contentList = json['content'];
    List<AssistantContent> parsedContent = [];

    if (contentList is List) {
      parsedContent = contentList
          .map((item) => AssistantContent.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return AssistantMessage(
      role: json['role'] as String? ?? 'assistant',
      content: parsedContent,
      model: json['model'] as String?,
    );
  }

  /// Get all tool uses in this message
  List<ToolUse> get toolUses {
    return content.whereType<ToolUse>().toList();
  }

  /// Get all text content in this message
  String get textContent {
    return content
        .whereType<TextContent>()
        .map((t) => t.text)
        .join('\n');
  }
}

/// Base class for assistant content blocks
sealed class AssistantContent {
  final String type;

  AssistantContent({required this.type});

  factory AssistantContent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';

    return switch (type) {
      'text' => TextContent.fromJson(json),
      'tool_use' => ToolUse.fromJson(json),
      _ => UnknownContent(type: type, raw: json),
    };
  }
}

/// Text content block
class TextContent extends AssistantContent {
  final String text;

  TextContent({required this.text}) : super(type: 'text');

  factory TextContent.fromJson(Map<String, dynamic> json) {
    return TextContent(text: json['text'] as String? ?? '');
  }
}

/// Tool use content block
class ToolUse extends AssistantContent {
  final String id;
  final String name;
  final Map<String, dynamic> input;

  ToolUse({
    required this.id,
    required this.name,
    required this.input,
  }) : super(type: 'tool_use');

  factory ToolUse.fromJson(Map<String, dynamic> json) {
    return ToolUse(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      input: json['input'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Get Bash command if this is a Bash tool use
  String? get bashCommand {
    if (name != 'Bash') return null;
    return input['command'] as String?;
  }

  /// Get file path if this is a file operation
  String? get filePath {
    return input['file_path'] as String?;
  }
}

/// Unknown content type
class UnknownContent extends AssistantContent {
  final Map<String, dynamic> raw;

  UnknownContent({required super.type, required this.raw});
}

/// Tool result from user message
class ToolResult {
  final String type;
  final String toolUseId;
  final String content;
  final bool isError;

  ToolResult({
    required this.type,
    required this.toolUseId,
    required this.content,
    this.isError = false,
  });

  factory ToolResult.fromJson(Map<String, dynamic> json) {
    return ToolResult(
      type: json['type'] as String? ?? 'tool_result',
      toolUseId: json['tool_use_id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      isError: json['is_error'] as bool? ?? false,
    );
  }
}

// =============================================================================
// TRANSCRIPT ANALYSIS
// =============================================================================

/// Analyzed transcript data
class TranscriptAnalysis {
  final Map<String, int> toolUsage;
  final Map<String, int> bashCommands;
  final List<String> errors;
  final List<String> userPrompts;
  final List<String> userDirectives;
  final int totalEvents;

  TranscriptAnalysis({
    required this.toolUsage,
    required this.bashCommands,
    required this.errors,
    required this.userPrompts,
    required this.userDirectives,
    required this.totalEvents,
  });

  /// Analyze a list of transcript events
  factory TranscriptAnalysis.fromEvents(List<TranscriptEvent> events) {
    final toolUsage = <String, int>{};
    final bashCommands = <String, int>{};
    final errors = <String>[];
    final userPrompts = <String>[];
    final userDirectives = <String>[];

    final directivePattern = RegExp(
      r'\b(NEVER|ALWAYS|DO NOT|DONT|MUST NOT|MUST)\b',
      caseSensitive: false,
    );

    for (final event in events) {
      switch (event) {
        case AssistantEvent(:final message):
          for (final toolUse in message.toolUses) {
            toolUsage[toolUse.name] = (toolUsage[toolUse.name] ?? 0) + 1;

            // Track specific Bash commands
            if (toolUse.name == 'Bash') {
              final command = toolUse.bashCommand;
              if (command != null) {
                // Normalize: take first part before pipes/redirects
                final normalized = command.split('|').first.split('>').first.trim();
                bashCommands[normalized] = (bashCommands[normalized] ?? 0) + 1;
              }
            }
          }

        case UserEvent(:final message):
          if (!message.isToolResult) {
            final text = message.textContent;
            if (text.length > 5 && userPrompts.length < 10) {
              userPrompts.add(
                text.substring(0, text.length.clamp(0, 100)),
              );
            }

            // Check for directives
            if (directivePattern.hasMatch(text)) {
              userDirectives.add(text);
            }

            // Check for errors in content
            if (text.contains('Error') ||
                text.contains('error:') ||
                text.contains('failed')) {
              if (errors.length < 5) {
                errors.add(text.substring(0, text.length.clamp(0, 150)));
              }
            }
          } else {
            // Check tool results for errors
            for (final result in message.toolResults) {
              if (result.isError ||
                  result.content.contains('Error') ||
                  result.content.contains('error:')) {
                if (errors.length < 5) {
                  errors.add(
                    result.content.substring(
                      0,
                      result.content.length.clamp(0, 150),
                    ),
                  );
                }
              }
            }
          }

        default:
          // Ignore other event types
          break;
      }
    }

    return TranscriptAnalysis(
      toolUsage: toolUsage,
      bashCommands: bashCommands,
      errors: errors,
      userPrompts: userPrompts,
      userDirectives: userDirectives,
      totalEvents: events.length,
    );
  }

  /// Convert to JSON-compatible map
  Map<String, dynamic> toJson() {
    return {
      'tool_usage': toolUsage,
      'bash_commands': bashCommands,
      'recent_errors': errors,
      'user_prompts': userPrompts,
      'user_directives': userDirectives,
      'total_events': totalEvents,
    };
  }
}
