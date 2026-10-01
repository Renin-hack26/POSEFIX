/// Plan screen interactions (day slot + library cards).
///
/// Contract:
///  * the exercise-library cards are tappable and route to the exercise's
///    instruction video (`/instruction-video?ex=<id>`) — the section renders
///    catalog [Exercise]s, not workouts;
///  * the day-slot region reserves a stable floor (the rest card's height),
///    so tapping another date never moves the sections below the slot —
///    "slots are moving" regression.
library;

import 'dart:convert';
import 'dart:io';

import 'package:fixpose/core/di/app_dependencies.dart';
import 'package:fixpose/core/theme/app_theme.dart';
import 'package:fixpose/data/mappers/content_mappers.dart';
import 'package:fixpose/domain/entities/exercise.dart';
import 'package:fixpose/domain/entities/meal.dart';
import 'package:fixpose/domain/entities/training_plan.dart';
import 'package:fixpose/domain/entities/workout.dart';
import 'package:fixpose/domain/entities/workout_session.dart';
import 'package:fixpose/domain/repositories/exercise_repository.dart';
import 'package:fixpose/domain/repositories/nutrition_repository.dart';
import 'package:fixpose/domain/repositories/plan_repository.dart';
import 'package:fixpose/domain/repositories/session_repository.dart';
import 'package:fixpose/domain/repositories/workout_repository.dart';
import 'package:fixpose/presentation/plan/plan_screen.dart';
import 'package:fixpose/presentation/shared/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// ---------------------------------------------------------------------------
// Fakes (same pattern as test/widget/plan_day_selection_test.dart)
// ---------------------------------------------------------------------------

class _FakePlanRepo implements PlanRepository {
  _FakePlanRepo(this.plan);
  final TrainingPlan plan;

  @override
  Future<TrainingPlan?> currentPlan() async => plan;

  @override
  Future<void> savePlan(TrainingPlan plan) async {}

  @override
  Future<void> updateSession(PlanSession session) async {}
}

class _FakeExerciseRepo implements ExerciseRepository {
  _FakeExerciseRepo(this.items);
  final List<Exercise> items;

  @override
  Future<List<Exercise>> catalog() async => items;

  @override
  Future<Exercise?> byId(String id) async => null;

  @override
  Future<bool> videoSeen(String exerciseId) async => false;

  @override
  Future<void> markVideoSeen(String exerciseId) async {}
}

class _FakeWorkoutRepo implements WorkoutRepository {
  _FakeWorkoutRepo(this.byIdMap);
  final Map<String, Workout> byIdMap;

  @override
  Future<List<Workout>> library() async => byIdMap.values.toList();

  @override
  Future<Workout?> byId(String id) async => byIdMap[id];

  @override
  Future<List<Workout>> suggestions({int limit = 5}) async =>
      byIdMap.values.take(limit).toList();
}

class _FakeNutritionRepo implements NutritionRepository {
  @override
  Future<List<FoodItem>> searchFoods(String query) async => [];

  @override
  Future<List<MealEntry>> entriesFor(String dateKey) async => [];

  @override
  Future<List<MealEntry>> entriesBetween(DateTime from, DateTime to) async => [];

  @override
  Future<void> addEntry(MealEntry entry) async {}

  @override
  Future<void> removeEntry(String id) async {}

  @override
  Future<MealTarget?> target() async => null;

  @override
  Future<void> saveTarget(MealTarget target) async {}
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

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/// Monday-based week containing today; `sessionsByIndex` supplies each
/// weekday's sessions (Mon = 0 … Sun = 6).
TrainingPlan _currentWeekPlan(
    List<List<PlanSession>> sessionsByIndex, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  return TrainingPlan(
    id: 'p_test',
    weekStart: weekStart,
    days: [
      for (var i = 0; i < 7; i++)
        PlanDay(
          date: weekStart.add(Duration(days: i)),
          sessions: sessionsByIndex[i],
        ),
    ],
    source: PlanSource.manual,
    lastUpdated: now,
  );
}

Workout _workout(String id, String name) => Workout(
      id: id,
      name: name,
      category: WorkoutCategory.fullBody,
      level: Difficulty.beginner,
      goal: 'Test goal',
      durationMin: 30,
      description: 'desc',
      focusMuscles: const [],
      blocks: const [],
      demoVideoAsset: '',
    );

/// ProviderScope over the fake repositories [PlanScreen] reads — shared by
/// both tests (the override list stays a literal so Riverpod 3 never has to
/// name its non-exported override type).
Widget _planScope({
  required Widget child,
  required TrainingPlan plan,
  List<Exercise> exercises = const [],
  Map<String, Workout> workouts = const {},
}) =>
    ProviderScope(
      overrides: [
        planRepositoryProvider.overrideWithValue(_FakePlanRepo(plan)),
        exerciseRepositoryProvider
            .overrideWithValue(_FakeExerciseRepo(exercises)),
        workoutRepositoryProvider.overrideWithValue(_FakeWorkoutRepo(workouts)),
        nutritionRepositoryProvider.overrideWithValue(_FakeNutritionRepo()),
        sessionRepositoryProvider.overrideWithValue(_FakeSessionRepo()),
      ],
      child: child,
    );

// ---------------------------------------------------------------------------

void main() {
  testWidgets('library card tap routes to the exercise instruction video',
      (tester) async {
    final raw =
        jsonDecode(File('assets/data/exercises.json').readAsStringSync())
            as List<dynamic>;
    final exercises = [
      for (final e in raw)
        exerciseFromJson(e as Map<String, dynamic>, 'exercises.json'),
    ];
    expect(exercises, isNotEmpty,
        reason: 'fixture: exercises.json must ship a catalog');

    final now = DateTime.now();
    final plan = _currentWeekPlan(
        List.generate(7, (_) => const <PlanSession>[]), now);

    // Real routes, fake destinations: only the navigated location matters.
    final router = GoRouter(
      initialLocation: '/plan',
      routes: [
        GoRoute(path: '/plan', builder: (context, state) => const PlanScreen()),
        GoRoute(
          path: '/instruction-video',
          builder: (context, state) =>
              Text('video:${state.uri.queryParameters['ex']}'),
        ),
        GoRoute(
          path: '/workout-details',
          builder: (context, state) =>
              Text('workout:${state.uri.queryParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _planScope(
        plan: plan,
        exercises: exercises,
        child: MaterialApp.router(
          theme: AppTheme.dark(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // First card of the library carousel (= exercises[0], preview order).
    final firstCard = find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(InkWell),
        )
        .first;
    expect(
      find.descendant(of: firstCard, matching: find.text(exercises[0].name)),
      findsOneWidget,
      reason: 'the carousel renders the catalog in order',
    );

    await tester.ensureVisible(firstCard);
    await tester.pumpAndSettle();
    await tester.tap(firstCard);
    await tester.pumpAndSettle();

    expect(find.text('video:${exercises[0].id}'), findsOneWidget,
        reason: 'library items are exercises → instruction-video route');
    expect(find.textContaining('workout:'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'day slot keeps a stable floor: tapping a rest date does not move '
      'the sections below', (tester) async {
    final now = DateTime.now();
    final todayIdx = now.weekday - 1; // Mon=0 … Sun=6
    final emptyIdx = [0, 1, 2, 3, 4, 5, 6].firstWhere((i) => i != todayIdx);
    final workout = _workout('w_stable', 'Quick Blast');

    final sessionsByIndex = List.generate(7, (_) => const <PlanSession>[]);
    sessionsByIndex[todayIdx] = [
      PlanSession(id: 's_t', workoutId: workout.id, startTimeMin: 420),
    ];
    final plan = _currentWeekPlan(sessionsByIndex, now);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: _planScope(
          plan: plan,
          workouts: {workout.id: workout},
          child: const PlanScreen(),
        ),
      ),
    );
    // Settles the data load AND the one-off floor measurement.
    await tester.pumpAndSettle();

    // Default selection = today → its session card is on screen.
    expect(find.text('Quick Blast'), findsOneWidget);

    final header = find.widgetWithText(SectionHeader, 'Exercise library');
    expect(header, findsOneWidget);
    final before = tester.getTopLeft(header).dy;

    // Session day → rest day: the slot keeps the rest-card floor, so the
    // library header must not budge.
    final emptyDate = plan.days[emptyIdx].date;
    await tester.tap(find.text('${emptyDate.day}'));
    await tester.pumpAndSettle();
    expect(find.text('No sessions scheduled'), findsOneWidget);

    final after = tester.getTopLeft(header).dy;
    expect(after, before,
        reason: 'the day slot reserves a stable height on every day — '
            'library moved from $before to $after');
    expect(tester.takeException(), isNull);
  });
}
