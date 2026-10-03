/// FixPose Notification Engine — scheduled workout reminders.
///
/// PLANNING §11: Local notifications for planned session times.
/// Uses flutter_local_notifications with timezone-aware scheduling.
/// All processing on-device; no cloud push.
///
/// Background guarantees (WS1):
///  - OS-delivered while closed: schedules are AlarmManager alarms in
///    `exactAllowWhileIdle` (falling back to `inexactAllowWhileIdle` when the
///    OS says exact alarms are not allowed), so reminders fire even when the
///    app is swiped away or the device is dozing.
///  - Reboot re-armed: `ScheduledNotificationBootReceiver` declared in the
///    manifest replays pending schedules after BOOT_COMPLETED / app update.
///  - Hourly self-heal: the `reminder_sync` workmanager task
///    (see reminder_worker.dart) replays the persisted config from Hive, so a
///    schedule lost to a force-stop or OEM process killer is back within ~1 h.
///  - Local wall clock: `flutter_timezone` resolves the device's IANA zone at
///    init; every daily schedule is a `DateTimeComponents.time` recurrence.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../storage/hive_service.dart';

/// Notification engine singleton.
class NotificationEngine {
  NotificationEngine._();
  static final NotificationEngine _instance = NotificationEngine._();
  static NotificationEngine get instance => _instance;

  /// Hive settings key for the JSON-encoded [ReminderConfig] of the last
  /// scheduled daily reminder — read back by the hourly `reminder_sync`
  /// worker to re-arm schedules (see reminder_worker.dart).
  static const String reminderConfigKey = 'reminderConfig';

  /// Synthetic workout id the Settings screen passes for the generic daily
  /// reminder — it has no workout to open, so taps land on the plan
  /// (see [routeForPayload]).
  static const String settingsReminderWorkoutId = 'settings-daily-reminder';

  /// One shared notification id for the daily reminder: Settings and Plan
  /// are two entry points to the ONE stored reminder config, so scheduling
  /// from either replaces the pending alarm instead of stacking a second
  /// schedule the single config cannot describe (nor re-arm).
  static const int dailyReminderNotificationId = 0x646179; // 'day'

  /// One channel per notification kind (organized-notifications):
  /// the daily reminder, one-shot session alerts (rest timers, nudges),
  /// and the legacy id — kept so alarms scheduled by older builds still
  /// render on their original channel instead of falling back to default.
  static const String dailyRemindersChannelId = 'daily_reminders';
  static const String sessionAlertsChannelId = 'session_alerts';
  static const String legacyWorkoutChannelId = 'workout_reminders';

  /// Hive settings key for the daily reminder time (minutes since 00:00),
  /// single-sourced here — Settings previously owned this exact string, and
  /// a rename would silently orphan every user's stored reminder time.
  static const String reminderMinuteOfDayKey = 'reminderMinuteOfDay';

  /// Default daily reminder time (07:00) until the user picks one.
  static const int defaultReminderMinuteOfDay = 7 * 60;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionsGranted = false;
  Future<void>? _initFuture;

  /// Set by the app entry point (main.dart): receives the payload of a
  /// notification tapped while the app is running (shape `'workout:<id>'`).
  void Function(String payload)? onPayload;

  String? _launchPayload;

  /// Payload the app was cold-started with (a notification tapped while the
  /// app was closed). Consumed once — later calls return null.
  String? takeLaunchPayload() {
    final payload = _launchPayload;
    _launchPayload = null;
    return payload;
  }

  /// Route for a tapped/cold-started notification payload — null when the
  /// payload maps nowhere (skip navigation instead of a dead-end screen).
  ///  - `workout:<id>` → workout details, id URL-encoded
  ///  - the Settings daily reminder → the plan (it has no workout)
  static String? routeForPayload(String payload) {
    final id = workoutIdFromPayload(payload);
    if (id == null) return null;
    if (id == settingsReminderWorkoutId) return '/plan';
    return '/workout-details?id=${Uri.encodeComponent(id)}';
  }

  /// Initialize notification channels and request permissions.
  ///
  /// [requestPermission] may show the OS prompt — pass false from background
  /// isolates (the `reminder_sync` worker), which only read the current
  /// state, since no Activity is attached to host the dialog. Concurrent
  /// callers share a single in-flight initialization.
  Future<void> initialize({bool requestPermission = true}) async {
    if (_initialized) return;
    final pending = _initFuture;
    if (pending != null) return pending;
    final future = _initialize(requestPermission: requestPermission);
    _initFuture = future;
    try {
      await future;
    } catch (_) {
      // A failed init stays retryable on the next call.
      if (identical(_initFuture, future)) _initFuture = null;
      rethrow;
    }
  }

  Future<void> _initialize({required bool requestPermission}) async {
    tzdata.initializeTimeZones();
    await _setLocalTimezone();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _notifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Cold start: if the app was launched by tapping a notification, stash
    // its payload for takeLaunchPayload() (routed once the router is up).
    try {
      final details = await _notifications.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        _launchPayload = details?.notificationResponse?.payload;
      }
    } catch (e) {
      debugPrint('NotificationEngine: launch details unavailable ($e)');
    }

    // Create one channel per notification kind. The legacy channel is kept
    // (no new schedules use it) so alarms stored by older builds still
    // render with their original sound/vibration behavior.
    const androidChannels = [
      AndroidNotificationChannel(
        dailyRemindersChannelId,
        'Daily Reminders',
        description: 'Daily workout reminders at your chosen time',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
      AndroidNotificationChannel(
        sessionAlertsChannelId,
        'Session Alerts',
        description: 'One-off workout alerts (rest timers, session nudges)',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
      AndroidNotificationChannel(
        legacyWorkoutChannelId,
        'Workout Reminders',
        description: 'Notifications for your scheduled workout sessions',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    ];
    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    for (final channel in androidChannels) {
      await androidImpl?.createNotificationChannel(channel);
    }

    // Request permissions
    await _requestPermissions(allowPrompt: requestPermission);
    _initialized = true;
  }

  /// Resolve the device's IANA timezone so schedules fire at local wall-clock
  /// time (a fixed UTC location fires at the wrong hour). On failure the
  /// location stays UTC — scheduling must never block on the platform channel.
  Future<void> _setLocalTimezone() async {
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e) {
      debugPrint(
          'NotificationEngine: timezone detection failed ($e) — keeping UTC');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  /// Android-only app: only the Android permission branch exists.
  /// Denials are accepted — the settings toggle explains where to unblock.
  /// Reads the current state first (no prompt when already granted) and
  /// never prompts when [allowPrompt] is false: background isolates have no
  /// Activity to host the OS dialog.
  Future<void> _requestPermissions({required bool allowPrompt}) async {
    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return;
    try {
      final enabled = await androidImpl.areNotificationsEnabled() ?? false;
      if (enabled) {
        _permissionsGranted = true;
        return;
      }
      _permissionsGranted = allowPrompt
          ? await androidImpl.requestNotificationsPermission() ?? false
          : false;
    } catch (e) {
      debugPrint('NotificationEngine: permission check failed ($e)');
      _permissionsGranted = false;
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    // Foreground tap — hand the payload to the app for deep-link routing.
    final payload = response.payload;
    if (payload != null) onPayload?.call(payload);
  }

  /// Android 14+ can revoke SCHEDULE_EXACT_ALARM, and scheduling an exact
  /// alarm anyway throws ExactAlarmPermissionException (verified in
  /// flutter_local_notifications 22.3.1 — `checkCanScheduleExactAlarms`).
  /// The Dart API is named `canScheduleExactNotifications()`; anything but a
  /// confident yes falls back to the inexact, doze-tolerant mode.
  Future<AndroidScheduleMode> _resolveScheduleMode() async {
    try {
      final androidImpl = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl == null) return AndroidScheduleMode.exactAllowWhileIdle;
      final canExact = await androidImpl.canScheduleExactNotifications();
      if (canExact ?? false) return AndroidScheduleMode.exactAllowWhileIdle;
    } catch (e) {
      debugPrint('NotificationEngine: exact-alarm check failed ($e)');
    }
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// Persist the active reminder config for the hourly `reminder_sync`
  /// worker. Storage trouble must never break scheduling — it only costs the
  /// background re-arm.
  Future<void> _persistReminderConfig(ReminderConfig config) async {
    try {
      await HiveService.init(); // no-op once boot has opened the box
      await HiveService.setString(reminderConfigKey, config.encode());
    } catch (e) {
      debugPrint('NotificationEngine: reminder config not persisted ($e)');
    }
  }

  /// Schedule a daily workout reminder at [hour]:[minute].
  /// [workoutName] shown in notification body.
  /// [workoutId] passed in payload for deep linking.
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String workoutName,
    required String workoutId,
    int? notificationId,
  }) async {
    if (!_initialized) await initialize();
    if (!_permissionsGranted) return;

    // Shared id: Settings + Plan are entry points to ONE stored config, so
    // the newer schedule always replaces the pending alarm (never stacks).
    final id = notificationId ?? dailyReminderNotificationId;

    final next = nextDailyOccurrence(DateTime.now(), hour, minute);
    final tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      next.year,
      next.month,
      next.day,
      next.hour,
      next.minute,
    );

    await _notifications.zonedSchedule(
      id: id,
      title: 'Time to train!',
      body: '$workoutName is scheduled now',
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          dailyRemindersChannelId,
          'Daily Reminders',
          channelDescription: 'Daily workout reminders at your chosen time',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: await _resolveScheduleMode(),
      payload: 'workout:$workoutId',
      matchDateTimeComponents: DateTimeComponents.time, // daily
    );

    // Hand the config to the background re-arm worker (idempotent: the same
    // notification id replaces the previous schedule).
    await _persistReminderConfig(ReminderConfig(
      enabled: true,
      hour: hour,
      minute: minute,
      workoutName: workoutName,
      workoutId: workoutId,
    ));
  }

  /// Cancel a specific workout reminder.
  Future<void> cancelReminder(int notificationId) async {
    await _notifications.cancel(id: notificationId);
    await _persistReminderConfig(const ReminderConfig(enabled: false));
  }

  /// Cancel all workout reminders.
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
    await _persistReminderConfig(const ReminderConfig(enabled: false));
  }

  /// Schedule a one-time notification (e.g., "Rest over in 30s").
  Future<void> scheduleOneTime({
    required Duration after,
    required String title,
    required String body,
    int? notificationId,
    String? payload,
  }) async {
    if (!_initialized) await initialize();
    if (!_permissionsGranted) return;

    final id = notificationId ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);
    final scheduledDate = tz.TZDateTime.now(tz.local).add(after);

    await _notifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          sessionAlertsChannelId,
          'Session Alerts',
          channelDescription:
              'One-off workout alerts (rest timers, session nudges)',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: await _resolveScheduleMode(),
      payload: payload,
    );
  }

  /// Check if notifications are enabled.
  Future<bool> areNotificationsEnabled() async {
    if (!_initialized) await initialize();
    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      return await androidImpl.areNotificationsEnabled() ?? false;
    }
    return _permissionsGranted;
  }

  /// Get pending notifications (for debugging/settings).
  Future<List<PendingNotificationRequest>> pendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }
}

// ---------------------------------------------------------------------------
// Pure helpers — no platform channels; unit-tested in
// test/notification/notification_engine_logic_test.dart
// ---------------------------------------------------------------------------

/// Next occurrence of [hour]:[minute] on the wall clock: today when that time
/// has not passed yet, tomorrow otherwise. Shared by
/// [NotificationEngine.scheduleDailyReminder] and its tests.
DateTime nextDailyOccurrence(DateTime now, int hour, int minute) {
  DateTime next = DateTime(now.year, now.month, now.day, hour, minute);
  if (next.isBefore(now)) {
    next = next.add(const Duration(days: 1));
  }
  return next;
}

/// The workout id embedded in a `'workout:<id>'` notification payload —
/// null for any other payload shape (or an empty id).
String? workoutIdFromPayload(String payload) {
  const prefix = 'workout:';
  if (!payload.startsWith(prefix)) return null;
  final id = payload.substring(prefix.length);
  return id.isEmpty ? null : id;
}

/// Settings of the last scheduled daily reminder, JSON-encoded into the Hive
/// settings box so the background worker can re-arm it
/// (see reminder_worker.dart).
class ReminderConfig {
  const ReminderConfig({
    required this.enabled,
    this.hour = 0,
    this.minute = 0,
    this.workoutName = '',
    this.workoutId = '',
  });

  /// Parses [raw]; null for anything malformed — the worker then skips the
  /// re-arm instead of scheduling at a guessed time.
  static ReminderConfig? decode(String raw) {
    try {
      final Object? map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return null;
      return ReminderConfig(
        enabled: map['enabled'] as bool,
        hour: map['hour'] as int,
        minute: map['minute'] as int,
        workoutName: map['workoutName'] as String,
        workoutId: map['workoutId'] as String,
      );
    } catch (_) {
      return null;
    }
  }

  final bool enabled;
  final int hour;
  final int minute;
  final String workoutName;
  final String workoutId;

  /// Inverse of [decode] — the stored Hive string value.
  String encode() => jsonEncode(<String, Object?>{
        'enabled': enabled,
        'hour': hour,
        'minute': minute,
        'workoutName': workoutName,
        'workoutId': workoutId,
      });
}
