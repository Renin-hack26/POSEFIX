/// FixPose Notification Engine — scheduled workout reminders.
///
/// PLANNING §11: Local notifications for planned session times.
/// Uses flutter_local_notifications with timezone-aware scheduling.
/// All processing on-device; no cloud push.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Notification engine singleton.
class NotificationEngine {
  NotificationEngine._();
  static final NotificationEngine _instance = NotificationEngine._();
  static NotificationEngine get instance => _instance;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionsGranted = false;

  /// Initialize notification channels and request permissions.
  Future<void> initialize() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));

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

    // Create channel for workout reminders
    const androidChannel = AndroidNotificationChannel(
      'workout_reminders',
      'Workout Reminders',
      description: 'Notifications for your scheduled workout sessions',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Request permissions
    await _requestPermissions();
    _initialized = true;
  }

  /// Android-only app: only the Android permission branch exists.
  /// Denials are accepted — the camera is re-requested at point of use.
  Future<void> _requestPermissions() async {
    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      _permissionsGranted =
          await androidImpl.requestNotificationsPermission() ?? false;
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap — navigate to workout screen
    // Handled by router via deep link or app state
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

    final id = notificationId ?? workoutId.hashCode;

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notifications.zonedSchedule(
      id: id,
      title: 'Time to train!',
      body: '$workoutName is scheduled now',
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'workout_reminders',
          'Workout Reminders',
          channelDescription:
              'Notifications for your scheduled workout sessions',
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
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'workout:$workoutId',
      matchDateTimeComponents: DateTimeComponents.time, // daily
    );
  }

  /// Cancel a specific workout reminder.
  Future<void> cancelReminder(int notificationId) async {
    await _notifications.cancel(id: notificationId);
  }

  /// Cancel all workout reminders.
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
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
          'workout_reminders',
          'Workout Reminders',
          channelDescription: 'Notifications for your scheduled workout sessions',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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