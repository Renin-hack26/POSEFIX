/// Background reminder re-arm worker (WS1).
///
/// Drives workmanager's hourly `reminder_sync` task: replays the persisted
/// daily-reminder config so a schedule lost to a force-stop, app update or
/// OEM process killer is restored within ~1 h. (Reboot recovery is handled
/// separately by flutter_local_notifications' boot receiver — see the
/// AndroidManifest.) Replaying is idempotent: re-scheduling uses the shared
/// daily-reminder id, so it replaces the pending alarm.
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:workmanager/workmanager.dart';

import '../storage/hive_service.dart';
import 'notification_engine.dart';

/// Task name of the periodic re-arm job — registered under the same string
/// as the workmanager uniqueName in main.dart.
const String reminderSyncTask = 'reminder_sync';

/// workmanager entry point: a top-level function annotated for the compiler,
/// because it starts in its own isolate where everything (timezone, Hive box,
/// notification channels) must be re-initialized before use.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != reminderSyncTask) return true; // not ours — nothing to do
    try {
      await _rearmDailyReminder();
      return true;
    } catch (e) {
      debugPrint('reminder_sync: re-arm failed ($e)');
      return false; // report failure so workmanager retries next period
    }
  });
}

/// Re-arm the last scheduled daily reminder — a no-op when none is stored or
/// it has been turned off (cancel paths persist `enabled: false`).
Future<void> _rearmDailyReminder() async {
  await HiveService.init();
  final raw = HiveService.getString(NotificationEngine.reminderConfigKey);
  if (raw == null) return;
  final config = ReminderConfig.decode(raw);
  if (config == null || !config.enabled) return;

  final engine = NotificationEngine.instance;
  // Background isolate: refresh timezone + permission *state*, never prompt.
  await engine.initialize(requestPermission: false);
  await engine.scheduleDailyReminder(
    hour: config.hour,
    minute: config.minute,
    workoutName: config.workoutName,
    workoutId: config.workoutId,
  );
}
