import 'package:claude_code_creeper/services/daemon_service.dart';
import 'package:test/test.dart';

void main() {
  group('DaemonStatus', () {
    test('creates with running=false', () {
      final status = DaemonStatus(running: false);

      expect(status.running, isFalse);
      expect(status.pid, isNull);
      expect(status.startedAt, isNull);
      expect(status.projectPath, isNull);
      expect(status.waitDuration, isNull);
      expect(status.autoApply, isFalse);
    });

    test('creates with all fields', () {
      final status = DaemonStatus(
        running: true,
        pid: 12345,
        startedAt: DateTime(2024, 1, 15, 10, 30),
        projectPath: '/project',
        waitDuration: Duration(minutes: 10),
        autoApply: true,
      );

      expect(status.running, isTrue);
      expect(status.pid, equals(12345));
      expect(status.startedAt, isNotNull);
      expect(status.projectPath, equals('/project'));
      expect(status.waitDuration, equals(Duration(minutes: 10)));
      expect(status.autoApply, isTrue);
    });

    test('uptime returns null when startedAt is null', () {
      final status = DaemonStatus(running: true, pid: 123);

      expect(status.uptime, isNull);
    });

    test('uptime formats seconds', () {
      final status = DaemonStatus(
        running: true,
        pid: 123,
        startedAt: DateTime.now().subtract(Duration(seconds: 30)),
      );

      expect(status.uptime, contains('s'));
    });

    test('uptime formats minutes', () {
      final status = DaemonStatus(
        running: true,
        pid: 123,
        startedAt: DateTime.now().subtract(Duration(minutes: 5)),
      );

      expect(status.uptime, contains('m'));
    });

    test('uptime formats hours', () {
      final status = DaemonStatus(
        running: true,
        pid: 123,
        startedAt: DateTime.now().subtract(Duration(hours: 2, minutes: 30)),
      );

      expect(status.uptime, contains('h'));
      expect(status.uptime, contains('m'));
    });

    test('uptime formats days', () {
      final status = DaemonStatus(
        running: true,
        pid: 123,
        startedAt: DateTime.now().subtract(Duration(days: 2, hours: 5)),
      );

      expect(status.uptime, contains('d'));
      expect(status.uptime, contains('h'));
    });
  });

  group('DaemonAlreadyRunningException', () {
    test('creates with pid', () {
      final exception = DaemonAlreadyRunningException(12345);

      expect(exception.pid, equals(12345));
    });

    test('toString includes pid', () {
      final exception = DaemonAlreadyRunningException(12345);

      expect(exception.toString(), contains('12345'));
      expect(exception.toString(), contains('already running'));
    });
  });
}
