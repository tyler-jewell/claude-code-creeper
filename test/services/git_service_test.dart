import 'package:claude_code_creeper/services/git_service.dart';
import 'package:test/test.dart';

void main() {
  group('WorktreeResult', () {
    test('creates with required fields', () {
      final result = WorktreeResult(
        path: '/project/.creeper-work',
        branchName: 'creeper/123456',
      );

      expect(result.path, equals('/project/.creeper-work'));
      expect(result.branchName, equals('creeper/123456'));
    });
  });

  group('PRResult', () {
    test('creates with required fields', () {
      final result = PRResult(
        url: 'https://github.com/test/pr/1',
        branch: 'creeper/123456',
        changesApplied: ['file1.dart', 'file2.dart'],
      );

      expect(result.url, equals('https://github.com/test/pr/1'));
      expect(result.branch, equals('creeper/123456'));
      expect(result.changesApplied, hasLength(2));
    });
  });

  group('GitException', () {
    test('creates with message', () {
      final exception = GitException('Something went wrong');

      expect(exception.message, equals('Something went wrong'));
    });

    test('toString includes message', () {
      final exception = GitException('Failed to push');

      expect(exception.toString(), contains('Failed to push'));
      expect(exception.toString(), contains('GitException'));
    });
  });
}
