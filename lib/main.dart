import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/audio/sound_engine.dart';
import 'core/config/supabase_config.dart';
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
}

class FixPoseApp extends ConsumerWidget {
  const FixPoseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
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
