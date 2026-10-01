/// Organized-notifications invariants (v1.1.11 user feedback):
///  - one channel per notification kind, all distinct;
///  - the shared reminder-time key stays byte-identical — a rename would
///    silently orphan every user's stored reminder time;
///  - the default stays 07:00.
library;

import 'package:fixpose/core/notification/notification_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('channels are distinct per notification kind', () {
    expect(NotificationEngine.dailyRemindersChannelId, 'daily_reminders');
    expect(NotificationEngine.sessionAlertsChannelId, 'session_alerts');
    expect(NotificationEngine.legacyWorkoutChannelId, 'workout_reminders');
    expect(
      NotificationEngine.dailyRemindersChannelId,
      isNot(NotificationEngine.sessionAlertsChannelId),
    );
    expect(
      NotificationEngine.sessionAlertsChannelId,
      isNot(NotificationEngine.legacyWorkoutChannelId),
    );
  });

  test('shared reminder-time key is migration-stable', () {
    // Settings previously owned this exact string — changing it would
    // orphan every user's persisted reminder time.
    expect(NotificationEngine.reminderMinuteOfDayKey, 'reminderMinuteOfDay');
    expect(NotificationEngine.defaultReminderMinuteOfDay, 7 * 60);
    expect(NotificationEngine.defaultReminderMinuteOfDay, 420);
  });

  test('daily reminder keeps its shared notification id', () {
    // Settings + Plan must replace, never stack.
    expect(NotificationEngine.dailyReminderNotificationId, 0x646179);
    expect(
        NotificationEngine.settingsReminderWorkoutId, 'settings-daily-reminder');
  });
}
