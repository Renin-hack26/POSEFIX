/// Plan tab — day-strip date accessibility (new in v1.1.9).
///
/// Contract:
///  * every date of the ongoing week is tappable (session days, rest days),
///  * tapping a date selects it (highlight moves),
///  * the slot below shows that date's full set of workouts — today by
///    default, or the next upcoming session day when today is empty,
///  * an empty date renders the rest card.
///
/// The week shown is always the plan's ongoing week — no cross-week
/// navigation exists, so the scope requirement ("ongoing week only") is
/// structural.
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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

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

void main() {
  testWidgets(
      'day strip: all ongoing-week dates accessible · each date shows '
      'its workout set', (tester) async {
    final raw = jsonDecode(
            File('assets/data/workouts.json').readAsStringSync())
        as List<dynamic>;
    final workouts = [
      for (final e in raw)
        workoutFromJson(e as Map<String, dynamic>, 'workouts.json'),
    ];
    final todayWorkout = workouts[0];
    final futureWorkout = workouts[1];

    // Monday-based current week; today at its weekday index.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final todayIdx = now.weekday - 1; // Mon=0 … Sun=6
    final futureIdx = todayIdx < 6 ? 6 : -1; // upcoming day this week
    final emptyIdx = [0, 1, 2, 3, 4, 5, 6]
        .firstWhere((i) => i != todayIdx && i != futureIdx);

    PlanSession sessionFor(String workoutId) => PlanSession(
        id: 's_$workoutId', workoutId: workoutId, startTimeMin: 420);

    final days = <PlanDay>[];
    for (var i = 0; i < 7; i++) {
      var sessions = const <PlanSession>[];
      if (i == todayIdx) sessions = [sessionFor(todayWorkout.id)];
      if (i == futureIdx) sessions = [sessionFor(futureWorkout.id)];
      days.add(PlanDay(
        date: weekStart.add(Duration(days: i)),
        sessions: sessions,
      ));
    }
    final plan = TrainingPlan(
      id: 'p_test',
      weekStart: weekStart,
      days: days,
      source: PlanSource.manual,
      lastUpdated: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: ProviderScope(
          overrides: [
            planRepositoryProvider.overrideWithValue(_FakePlanRepo(plan)),
            exerciseRepositoryProvider
                .overrideWithValue(_FakeExerciseRepo(const [])),
            workoutRepositoryProvider.overrideWithValue(
                _FakeWorkoutRepo({todayWorkout.id: todayWorkout,
                  futureWorkout.id: futureWorkout})),
            nutritionRepositoryProvider
                .overrideWithValue(_FakeNutritionRepo()),
            sessionRepositoryProvider.overrideWithValue(_FakeSessionRepo()),
          ],
          child: const PlanScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    // Default selection = today → today's workout set is on screen.
    expect(find.text(todayWorkout.name), findsOneWidget,
        reason: 'default selection shows today’s session');

    // Future date in the ongoing week → its workout + weekday pill.
    if (futureIdx >= 0) {
      final futureDate = days[futureIdx].date;
      await tester.tap(find.text('${futureDate.day}'));
      await tester.pump();
      expect(find.text(futureWorkout.name), findsOneWidget,
          reason: 'tapping an upcoming date shows that date’s workout');
      expect(
        find.text('${DateFormat('EEE').format(futureDate)} · 7:00 AM'),
        findsOneWidget,
        reason: 'pill labels the selected weekday + start time',
      );
      expect(find.text(todayWorkout.name), findsNothing,
          reason: 'only the selected date’s set is shown');
    }

    // Empty (rest) date is accessible too → rest card.
    final emptyDate = days[emptyIdx].date;
    await tester.tap(find.text('${emptyDate.day}'));
    await tester.pump();
    expect(find.text('No sessions scheduled'), findsOneWidget,
        reason: 'a session-less date still opens (rest card)');

    // Back to today.
    await tester.tap(find.text('${today.day}'));
    await tester.pump();
    expect(find.text(todayWorkout.name), findsOneWidget,
        reason: 'selection returns to today');
  });
}
