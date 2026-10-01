/// HOME header strike badge (WS4):
///  * a loaded strike of 1 renders as "1 day streak",
///  * the loading branch (dashboard still pending) shows a neutral
///    placeholder — it must never present an unknown streak as a number
///    (the header used to hardcode `strike: 0`).
library;

import 'dart:async';

import 'package:fixpose/core/di/app_dependencies.dart';
import 'package:fixpose/core/theme/app_theme.dart';
import 'package:fixpose/core/utils/extensions.dart';
import 'package:fixpose/domain/entities/body_metric.dart';
import 'package:fixpose/domain/entities/plan_template.dart';
import 'package:fixpose/domain/entities/strike_state.dart';
import 'package:fixpose/domain/entities/training_plan.dart';
import 'package:fixpose/domain/entities/user_profile.dart';
import 'package:fixpose/domain/entities/workout.dart';
import 'package:fixpose/domain/entities/workout_session.dart';
import 'package:fixpose/domain/repositories/content_repository.dart';
import 'package:fixpose/domain/repositories/plan_repository.dart';
import 'package:fixpose/domain/repositories/progress_repository.dart';
import 'package:fixpose/domain/repositories/session_repository.dart';
import 'package:fixpose/domain/repositories/user_repository.dart';
import 'package:fixpose/domain/repositories/workout_repository.dart';
import 'package:fixpose/presentation/home/home_screen.dart';
import 'package:fixpose/presentation/home/widgets/strike_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeProgressRepo implements ProgressRepository {
  _FakeProgressRepo({this.strikeState, this.hangOnRead = false});

  final StrikeState? strikeState;

  /// When true the strike read never completes — the dashboard stays in its
  /// loading branch (spinner + placeholder header).
  final bool hangOnRead;

  final List<StrikeState> saved = [];

  @override
  Future<StrikeState?> strike() => hangOnRead
      ? Completer<StrikeState?>().future
      : Future.value(strikeState);

  @override
  Future<void> saveStrike(StrikeState state) async => saved.add(state);

  @override
  Future<List<BodyMetric>> metrics({int limit = 365}) async => const [];

  @override
  Future<void> addMetric(BodyMetric metric) async {}
}

class _FakeSessionRepo implements SessionRepository {
  @override
  Future<WorkoutSession?> activeSession() async => null;

  @override
  Future<void> saveActive(WorkoutSession session) async {}

  @override
  Future<void> clearActive() async {}

  @override
  Future<void> completeSession(WorkoutSession session) async {}

  @override
  Future<List<WorkoutSession>> history({int limit = 100}) async => [];

  @override
  Future<List<WorkoutSession>> sessionsBetween(
          DateTime from, DateTime to) async =>
      [];
}

class _FakePlanRepo implements PlanRepository {
  @override
  Future<TrainingPlan?> currentPlan() async => null;

  @override
  Future<void> savePlan(TrainingPlan plan) async {}

  @override
  Future<void> updateSession(PlanSession session) async {}
}

class _FakeWorkoutRepo implements WorkoutRepository {
  @override
  Future<List<Workout>> library() async => [];

  @override
  Future<Workout?> byId(String id) async => null;

  @override
  Future<List<Workout>> suggestions({int limit = 5}) async => [];
}

class _FakeContentRepo implements ContentRepository {
  @override
  Future<List<String>> tips() async => [];

  @override
  Future<List<PlanTemplate>> planTemplates() async => [];
}

class _FakeUserRepo implements UserRepository {
  @override
  Future<UserProfile?> currentUser() async => null;

  @override
  Stream<UserProfile?> authStateChanges() => const Stream.empty();

  @override
  Future<OtpDispatch> signUp({
    required SignUpData data,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<OtpDispatch> resendSignUpOtp() => throw UnimplementedError();

  @override
  Future<void> verifyOtp({required String email, required String code}) =>
      throw UnimplementedError();

  @override
  Future<void> signIn({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<OtpDispatch> requestPasswordReset({required String email}) =>
      throw UnimplementedError();

  @override
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}

/// ProviderScope with the full fake dashboard data source graph — the
/// wrapper exists so the override list never has to be typed by hand
/// (Riverpod 3 keeps [Override] out of the public exports).
Widget _homeScope({required ProgressRepository progress, required Widget child}) =>
    ProviderScope(
      overrides: [
        progressRepositoryProvider.overrideWithValue(progress),
        sessionRepositoryProvider.overrideWithValue(_FakeSessionRepo()),
        planRepositoryProvider.overrideWithValue(_FakePlanRepo()),
        workoutRepositoryProvider.overrideWithValue(_FakeWorkoutRepo()),
        contentRepositoryProvider.overrideWithValue(_FakeContentRepo()),
        userRepositoryProvider.overrideWithValue(_FakeUserRepo()),
      ],
      child: child,
    );

// ---------------------------------------------------------------------------

void main() {
  testWidgets('home header renders the loaded strike as "1 day streak"',
      (tester) async {
    final today = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: _homeScope(
          progress: _FakeProgressRepo(
            strikeState: StrikeState(
              currentStrike: 1,
              longestStrike: 1,
              lastActiveDateKey: today.dateKey,
            ),
          ),
          child: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(StrikeBadge), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(StrikeBadge),
        matching: find.text('1'),
      ),
      findsOneWidget,
      reason: 'the badge shows the real strike count',
    );
    expect(find.text('day streak'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading header makes no numeric streak claim', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: _homeScope(
          // The strike read never resolves → Home stays in its loading
          // branch while the dashboard future is pending.
          progress: _FakeProgressRepo(hangOnRead: true),
          child: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget,
        reason: 'dashboard still loading');
    final badgeTexts = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(StrikeBadge),
            matching: find.byType(Text),
          ),
        )
        .map((text) => text.data ?? '');
    expect(badgeTexts.any((value) => int.tryParse(value) != null), isFalse,
        reason: 'an unknown streak must not render as "0 day streak"');
    expect(badgeTexts, contains('—'),
        reason: 'the placeholder dash replaces the count');
    expect(tester.takeException(), isNull);
  });
}
