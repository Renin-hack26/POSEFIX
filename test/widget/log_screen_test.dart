/// Log page: one chronological feed of sessions + meals grouped by day,
/// with day totals; empty state when nothing was logged.
library;

import 'package:fixpose/core/di/app_dependencies.dart';
import 'package:fixpose/core/theme/app_theme.dart';
import 'package:fixpose/domain/entities/exercise.dart';
import 'package:fixpose/domain/entities/meal.dart';
import 'package:fixpose/domain/entities/workout.dart';
import 'package:fixpose/domain/entities/workout_session.dart';
import 'package:fixpose/domain/repositories/nutrition_repository.dart';
import 'package:fixpose/domain/repositories/session_repository.dart';
import 'package:fixpose/domain/repositories/workout_repository.dart';
import 'package:fixpose/presentation/nutrition/log_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNutritionRepo implements NutritionRepository {
  _FakeNutritionRepo(this.entries);

  final List<MealEntry> entries;

  @override
  Future<List<FoodItem>> searchFoods(String query) async => [];

  @override
  Future<List<MealEntry>> entriesFor(String dateKey) async =>
      entries.where((e) => e.dateKey == dateKey).toList();

  @override
  Future<List<MealEntry>> entriesBetween(DateTime from, DateTime to) async =>
      entries;

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
  _FakeSessionRepo(this.sessions);

  final List<WorkoutSession> sessions;

  @override
  Future<WorkoutSession?> activeSession() async => null;

  @override
  Future<void> saveActive(WorkoutSession session) async {}

  @override
  Future<void> clearActive() async {}

  @override
  Future<void> completeSession(WorkoutSession session) async {}

  @override
  Future<List<WorkoutSession>> history({int limit = 100}) async => sessions;

  @override
  Future<List<WorkoutSession>> sessionsBetween(
          DateTime from, DateTime to) async =>
      sessions;
}

class _FakeWorkoutRepo implements WorkoutRepository {
  _FakeWorkoutRepo(this.workouts);

  final List<Workout> workouts;

  @override
  Future<List<Workout>> library() async => workouts;

  @override
  Future<Workout?> byId(String id) async {
    for (final w in workouts) {
      if (w.id == id) return w;
    }
    return null;
  }

  @override
  Future<List<Workout>> suggestions({int limit = 5}) async =>
      workouts.take(limit).toList();
}

Workout _workout() => Workout(
      id: 'w1',
      name: 'Full Body Blast',
      category: WorkoutCategory.fullBody,
      level: Difficulty.beginner,
      goal: 'Get stronger',
      durationMin: 30,
      description: 'desc',
      focusMuscles: const [],
      blocks: const [],
      demoVideoAsset: '',
    );

Future<void> _pump(
  WidgetTester tester, {
  required List<WorkoutSession> sessions,
  required List<MealEntry> meals,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(_FakeSessionRepo(sessions)),
        workoutRepositoryProvider.overrideWithValue(_FakeWorkoutRepo([_workout()])),
        nutritionRepositoryProvider
            .overrideWithValue(_FakeNutritionRepo(meals)),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: [AppPalette.dark]),
        home: const LogScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders today with the workout session and meal + totals',
      (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final session = WorkoutSession(
      id: 's1',
      workoutId: 'w1',
      startedAt: today.add(const Duration(hours: 7)),
      endedAt: today.add(const Duration(hours: 7, minutes: 30)),
      status: SessionStatus.completed,
      durationSec: 1800,
      totalReps: 120,
      formAccuracyPct: 88,
    );
    final meal = MealEntry(
      id: 'm1',
      dateKey:
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
      name: 'Oats & Banana',
      calories: 320,
      mealType: MealType.breakfast,
      timeMillis: today.add(const Duration(hours: 8)).millisecondsSinceEpoch,
    );

    await _pump(tester, sessions: [session], meals: [meal]);

    expect(find.text('Activity log'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Full Body Blast'), findsOneWidget);
    expect(find.text('Oats & Banana'), findsOneWidget);
    expect(find.text('320 kcal'), findsOneWidget);
    // Session metrics line.
    expect(find.textContaining('30 min · 120 reps'), findsOneWidget);
    // Day header totals: kcal + sessions.
    expect(find.textContaining('320 kcal · 1 session'), findsOneWidget);
  });

  testWidgets('empty state when nothing was logged', (tester) async {
    await _pump(tester, sessions: const [], meals: const []);
    expect(
      find.textContaining('Nothing logged in the last 30 days'),
      findsOneWidget,
    );
  });
}
