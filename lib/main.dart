import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/navigation/app_router.dart';

/// FixPose app entry point.
///
/// P0 bootstrap responsibilities (docs/PLANNING.md §11):
///  - Firebase init (P1)
///  - Drift/Hive init (P0)
///  - Dependency wiring (core/di)
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
    return MaterialApp.router(
      title: 'FixPose',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00C853)),
      ),
    );
  }
}
