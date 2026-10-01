/// Notification engine pure-logic tests — daily scheduling arithmetic,
/// payload parsing, reminder config codec. No platform channels involved.
library;

import 'package:fixpose/core/notification/notification_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nextDailyOccurrence', () {
    test('later time today stays today', () {
      final now = DateTime(2026, 6, 15, 8, 30);
      expect(nextDailyOccurrence(now, 19, 45), DateTime(2026, 6, 15, 19, 45));
    });

    test('earlier time rolls to tomorrow', () {
      final now = DateTime(2026, 6, 15, 20, 0);
      expect(nextDailyOccurrence(now, 7, 5), DateTime(2026, 6, 16, 7, 5));
    });

    test('exact same minute keeps today (inclusive edge)', () {
      final now = DateTime(2026, 6, 15, 7, 5);
      expect(nextDailyOccurrence(now, 7, 5), DateTime(2026, 6, 15, 7, 5));
    });

    test('one minute past the target rolls to tomorrow', () {
      final now = DateTime(2026, 6, 15, 7, 6);
      expect(nextDailyOccurrence(now, 7, 5), DateTime(2026, 6, 16, 7, 5));
    });

    test('midnight target after midnight is tomorrow', () {
      final now = DateTime(2026, 6, 15, 0, 10);
      expect(nextDailyOccurrence(now, 0, 0), DateTime(2026, 6, 16, 0, 0));
    });

    test('midnight target late at night is tomorrow', () {
      final now = DateTime(2026, 6, 15, 23, 30);
      expect(nextDailyOccurrence(now, 0, 0), DateTime(2026, 6, 16, 0, 0));
    });

    test('rolls across a month boundary', () {
      final now = DateTime(2026, 1, 31, 23, 0);
      expect(nextDailyOccurrence(now, 7, 0), DateTime(2026, 2, 1, 7, 0));
    });
  });

  group('workoutIdFromPayload', () {
    test('parses a plain workout payload', () {
      expect(workoutIdFromPayload('workout:push_day'), 'push_day');
    });

    test('parses ids with hyphens and digits', () {
      expect(workoutIdFromPayload('workout:upper-body-2'), 'upper-body-2');
    });

    test('empty id after the prefix is rejected', () {
      expect(workoutIdFromPayload('workout:'), isNull);
    });

    test('foreign payload shapes are rejected', () {
      expect(workoutIdFromPayload('settings-daily-reminder'), isNull);
      expect(workoutIdFromPayload('summary:s42'), isNull);
      expect(workoutIdFromPayload('workout'), isNull);
      expect(workoutIdFromPayload(''), isNull);
    });
  });

  group('ReminderConfig codec', () {
    test('encode → decode round-trips an enabled config', () {
      const config = ReminderConfig(
        enabled: true,
        hour: 6,
        minute: 45,
        workoutName: 'Morning push',
        workoutId: 'push_day',
      );
      final decoded = ReminderConfig.decode(config.encode());
      expect(decoded, isNotNull);
      expect(decoded!.enabled, isTrue);
      expect(decoded.hour, 6);
      expect(decoded.minute, 45);
      expect(decoded.workoutName, 'Morning push');
      expect(decoded.workoutId, 'push_day');
    });

    test('encode → decode round-trips the disabled config', () {
      const config = ReminderConfig(enabled: false);
      final decoded = ReminderConfig.decode(config.encode());
      expect(decoded, isNotNull);
      expect(decoded!.enabled, isFalse);
      expect(decoded.hour, 0);
      expect(decoded.minute, 0);
      expect(decoded.workoutName, '');
      expect(decoded.workoutId, '');
    });

    test('decode rejects malformed input', () {
      expect(ReminderConfig.decode('workout:push_day'), isNull); // not JSON
      expect(ReminderConfig.decode('42'), isNull); // wrong JSON type
      expect(ReminderConfig.decode('[]'), isNull); // list, not object
      expect(
        ReminderConfig.decode('{"enabled":true,"hour":7}'), // missing fields
        isNull,
      );
    });
  });

  group('routeForPayload', () {
    test('workout payload → details route', () {
      expect(NotificationEngine.routeForPayload('workout:push_day'),
          '/workout-details?id=push_day');
    });

    test('settings daily reminder → plan (never "not found")', () {
      expect(
        NotificationEngine.routeForPayload(
            'workout:${NotificationEngine.settingsReminderWorkoutId}'),
        '/plan',
      );
    });

    test('workout ids are URL-encoded', () {
      expect(NotificationEngine.routeForPayload('workout:a b&c'),
          '/workout-details?id=a%20b%26c');
    });

    test('foreign payloads → null (no navigation)', () {
      expect(NotificationEngine.routeForPayload('summary:s42'), isNull);
      expect(NotificationEngine.routeForPayload('workout:'), isNull);
      expect(NotificationEngine.routeForPayload(''), isNull);
    });
  });
}
