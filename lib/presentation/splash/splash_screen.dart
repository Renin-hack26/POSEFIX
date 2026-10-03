import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/app_dependencies.dart';
import '../../core/permissions/permission_flow.dart';
import '../../core/theme/app_theme.dart';
import '../shared/app_logo.dart';
import '../shared/grid_background.dart';

/// 01 — Splash (sample/index.html).
///
/// 1.7 s entrance → routes to permissions (first install), onboarding
/// (signed-in — onboarding forwards to /home when a plan already exists),
/// or sign-in (signed-out).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startSync();
    Future<void>.delayed(const Duration(milliseconds: 1700), _route);
  }

  void _startSync() {
    // Account sync starts at boot (15-min sweep + auth listener). Best-effort:
    // the widget-test harness has no Supabase initialized.
    try {
      ref.read(syncEngineProvider).start();
    } catch (_) {
      return;
    }
  }

  Future<void> _route() async {
    if (!mounted) return;
    if (!_permissionsAsked()) {
      if (mounted) context.go('/permissions');
      return;
    }
    if (await _signedIn()) {
      if (mounted) context.go('/onboarding');
    } else {
      if (mounted) context.go('/signin');
    }
  }

  bool _permissionsAsked() {
    try {
      return PermissionFlow.askedBefore;
    } catch (_) {
      return true; // treat uninitialized box as "asked" (test harness)
    }
  }

  Future<bool> _signedIn() async {
    try {
      return await ref.read(userRepositoryProvider).currentUser() != null;
    } catch (_) {
      return false; // auth stack unavailable (test harness)
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogo(size: 88, radius: 28, iconSize: 44),
                const SizedBox(height: 18),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'FixPose',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your on-device form coach',
                      style: TextStyle(fontSize: 14, color: p.ink2),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.accent,
                    backgroundColor: p.track,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}