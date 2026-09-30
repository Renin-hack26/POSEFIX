import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/forgot_password_screen.dart';
import '../auth/otp_screen.dart';
import '../auth/reset_password_screen.dart';
import '../auth/sign_in_screen.dart';
import '../auth/sign_up_screen.dart';
import '../home/home_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../permissions/permission_screen.dart';
import '../plan/plan_screen.dart';
import '../settings/settings_screen.dart';
import '../shared/anim/app_transitions.dart';
import '../splash/splash_screen.dart';
import '../veda/veda_chat_screen.dart';
import '../vision/vision_session_screen.dart';
import '../workout/instruction_video_screen.dart';
import '../workout/session_summary_screen.dart';
import '../workout/workout_details_screen.dart';
import '../workout/workout_screen.dart';
import 'app_shell.dart';

/// Root navigator key (for full-screen routes: vision, OTP, etc.).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// App router — 4-tab shell (HOME | WORKOUT | PLAN | SETTINGS) + auth stack.
///
/// Adding a reserved page (PLANNING §10.2) = 1 route + 1 slot.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    routes: [
      // --- Auth stack ---
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/signin', builder: (context, state) => const SignInScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignUpScreen()),
      GoRoute(
        path: '/otp',
        builder: (context, state) => OtpScreen(
          args: state.extra is OtpArgs ? state.extra as OtpArgs : null,
        ),
      ),
      GoRoute(path: '/forgot', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => ResetPasswordScreen(
          args: state.extra is OtpArgs ? state.extra as OtpArgs : null,
        ),
      ),

      // --- First-launch permissions (before auth stack) ---
      GoRoute(
        path: '/permissions',
        pageBuilder: (context, state) => AppTransitions.fadeRise(
          state: state,
          child: const PermissionScreen(),
        ),
      ),

      // --- Onboarding (post-auth, pre-home) ---
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => AppTransitions.fadeRise(
          state: state,
          child: const OnboardingScreen(),
        ),
      ),

      // --- Reserved full-screen pages (PLANNING §10.2) ---
      GoRoute(
        path: '/workout-details',
        pageBuilder: (context, state) => AppTransitions.fadeRise(
          state: state,
          child: WorkoutDetailsScreen(
            workoutId: state.uri.queryParameters['id'],
          ),
        ),
      ),
      GoRoute(
        path: '/instruction-video',
        pageBuilder: (context, state) => AppTransitions.fadeRise(
          state: state,
          child: InstructionVideoScreen(
            exerciseId: state.uri.queryParameters['ex'] ?? 'squat',
          ),
        ),
      ),
      GoRoute(
        path: '/vision',
        pageBuilder: (context, state) => AppTransitions.fadeRise(
          state: state,
          child: VisionSessionScreen(
            exerciseId: state.uri.queryParameters['ex'] ?? 'squat',
          ),
        ),
      ),
      GoRoute(
        path: '/summary',
        pageBuilder: (context, state) => AppTransitions.fadeRise(
          state: state,
          child: SessionSummaryScreen(
            sessionId: state.uri.queryParameters['session'],
          ),
        ),
      ),
      GoRoute(
        path: '/veda',
        pageBuilder: (context, state) => AppTransitions.fadeRise(
          state: state,
          child: const VedaChatScreen(),
        ),
      ),

      // --- 4-tab shell ---
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/workout', builder: (context, state) => const WorkoutScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/plan', builder: (context, state) => const PlanScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
          ]),
        ],
      ),
    ],
  );
});
