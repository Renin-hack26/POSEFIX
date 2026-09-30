import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'presentation/navigation/app_router.dart';

/// FixPose app entry point.
///
/// Bootstrap responsibilities (docs/PLANNING.md §11):
///  - Theme: liquid-glass light + dark, follows the device by default;
///    manual Auto/Light/Dark picker lives in Settings (Hive-backed, P1).
///  - Supabase auth init (P1) — app boots offline-first on mock source.
///  - Drift/Hive init (P1)
///  - Permission flow happens after splash (core/permissions)
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: FixPoseApp()));
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
