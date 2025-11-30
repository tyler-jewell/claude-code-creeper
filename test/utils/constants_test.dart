import 'package:test/test.dart';
import 'package:claude_code_creeper/utils/constants.dart';
import 'package:claude_code_creeper/models/transcript_types.dart';

void main() {
  test('constants have expected values', () {
    expect(defaultModel, equals('haiku'));
    expect(migrationExtension, equals('.jsonl'));
    expect(migrationMetadataKey, equals('_migration'));
    expect(maxVerifyRetries, equals(3));
  });

  test('parseTranscript parses user events', () {
    const transcript = '''
{"type":"user","message":{"role":"user","content":"Hello"}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Hi there"}]}}
''';
    final events = TranscriptEvent.parseTranscript(transcript);
    expect(events.length, equals(2));
    expect(events[0], isA<UserEvent>());
    expect(events[1], isA<AssistantEvent>());
  });
}
