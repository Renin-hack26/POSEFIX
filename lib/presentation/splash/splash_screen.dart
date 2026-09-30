import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../shared/anim/fade_slide_in.dart';
import '../shared/app_logo.dart';
import '../shared/grid_background.dart';

/// 01 — Splash (sample/index.html).
///
/// UI-first: holds ~1.7s then enters the auth stack.
/// P1: replace the delay with a session check — straight to /home when
/// a session exists (mock source → Supabase).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1700), () {
      if (mounted) context.go('/signin');
    });
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
                // Staggered entrance: logo first, headline copy after.
                const FadeSlideIn(
                  child: AppLogo(size: 88, radius: 28, iconSize: 44),
                ),
                const SizedBox(height: 18),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 120),
                  child: Column(
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
