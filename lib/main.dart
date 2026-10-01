import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'core/audio/sound_engine.dart';
import 'core/config/supabase_config.dart';
import 'core/notification/notification_engine.dart';
import 'core/notification/reminder_worker.dart';
import 'core/pose/exercise_catalog.dart';
import 'core/storage/hive_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'presentation/navigation/app_router.dart';

/// FixPose app entry point.
///
/// Bootstrap responsibilities (docs/PLANNING.md §11):
///  - Hive first — device-local prefs (theme, first-launch flags, sync
///    watermark); every later reader assumes the box is open.
///  - Theme: liquid-glass light + dark, follows the device by default;
///    manual Auto/Light/Dark picker lives in Settings (Hive-backed).
///  - Supabase auth init: local setup only at boot — no network call, so the
///    app still starts offline; remote work happens on user actions.
///  - Permission flow happens after splash (core/permissions).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.init();
  // FSM catalog is pure Dart — instant.
  registerExerciseCatalog();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  runApp(const ProviderScope(child: FixPoseApp()));
  // Engine warm-up runs AFTER the first frame (never blocks boot): SoundEngine
  // pre-warms TTS + synthesizes SFX so the first coaching cue lands inside
  // 0.5 s of detection. speakCue() re-initializes on demand if it races.
  unawaited(SoundEngine().initialize());

  // WS1: hourly background self-heal for daily reminders — replays the
  // persisted schedule if an alarm was lost (workmanager floor is 15 min;
  // 1 h keeps it off the battery radar). Registered once per process.
  unawaited(_startReminderWorker());

  // WS1: after the first frame, initialize the notification engine (device
  // timezone + one permission prompt per process, as before) and route a
  // cold-start notification payload through the payload handler bound by
  // FixPoseApp.build.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final engine = NotificationEngine.instance;
    try {
      await engine.initialize();
    } catch (e) {
      debugPrint('notifications: init skipped ($e)');
    }
    // Route the cold-start payload even when init failed partway — a tapped
    // reminder must not die with the exception (debugPrint only).
    try {
      final launchPayload = engine.takeLaunchPayload();
      if (launchPayload != null) engine.onPayload?.call(launchPayload);
    } catch (e) {
      debugPrint('notifications: launch payload dropped ($e)');
    }
  });
}

/// Reminder self-heal worker — started once per process; the `keep` policy on
/// registration makes repeats (hot restart) harmless.
bool _reminderWorkerStarted = false;

Future<void> _startReminderWorker() async {
  if (_reminderWorkerStarted) return;
  _reminderWorkerStarted = true;
  try {
    // `isInDebugMode` is deprecated (and a no-op) in workmanager 0.10 —
    // task failures are reported through WorkmanagerDebug handlers instead.
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      reminderSyncTask,
      reminderSyncTask,
      frequency: const Duration(hours: 1), // workmanager floor is 15 min
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.notRequired),
    );
  } catch (e) {
    debugPrint('notifications: reminder worker not registered ($e)');
  }
}

class FixPoseApp extends ConsumerWidget {
  const FixPoseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    // WS1: notification taps (running app or cold start) deep-link per the
    // payload — a real workout id opens details (URL-encoded), the Settings
    // daily reminder opens the plan instead of a dead "not found" screen.
    NotificationEngine.instance.onPayload = (payload) {
      final route = NotificationEngine.routeForPayload(payload);
      if (route != null) router.go(route);
    };
    return MaterialApp.router(
      title: 'FixPose',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode, // default = follow device; Settings can override (§9)
    );
  }
}
