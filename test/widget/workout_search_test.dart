/// WS7 — workout tab search (item 7.4/7.5): the search field smart-filters
/// the library.
///
/// Contract:
///  * typing a related word ("legs") shows the synonym-matched workout and
///    hides non-matches;
///  * typing "waist" reaches "Ab Blast" through the merged abs/core class
///    (neither word appears on the workout);
///  * typing "push" finds the workout via its block's exercise (id +
///    display name from the exercise catalog), not its own name;
///  * a query with no hits shows the search-aware empty state.
library;

import 'package:fixpose/core/di/app_dependencies.dart';
import 'package:fixpose/core/theme/app_theme.dart';
import 'package:fixpose/domain/entities/exercise.dart';
import 'package:fixpose/domain/entities/training_plan.dart';
import 'package:fixpose/domain/entities/workout.dart';
import 'package:fixpose/domain/repositories/exercise_repository.dart';
import 'package:fixpose/domain/repositories/plan_repository.dart';
import 'package:fixpose/domain/repositories/workout_repository.dart';
import 'package:fixpose/presentation/workout/workout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWorkoutRepo implements WorkoutRepository {
  _FakeWorkoutRepo(this.items);

  final List<Workout> items;

  @override
  Future<List<Workout>> library() async => items;

  @override
  Future<Workout?> byId(String id) async {
    for (final w in items) {
      if (w.id == id) return w;
    }
    return null;
  }

  @override
  Future<List<Workout>> suggestions({int limit = 5}) async =>
      const <Workout>[]; // keep the resume card hidden — it duplicates names
}

class _FakeExerciseRepo implements ExerciseRepository {
  _FakeExerciseRepo(this.items);

  final List<Exercise> items;

  @override
  Future<List<Exercise>> catalog() async => items;

  @override
  Future<Exercise?> byId(String id) async {
    for (final e in items) {
      if (e.id == id) return e;
    }
    return null;
  }

  @override
  Future<bool> videoSeen(String exerciseId) async => false;

  @override
  Future<void> markVideoSeen(String exerciseId) async {}
}

class _FakePlanRepo implements PlanRepository {
  @override
  Future<TrainingPlan?> currentPlan() async => null;

  @override
  Future<void> savePlan(TrainingPlan plan) async {}

  @override
  Future<void> updateSession(PlanSession session) async {}
}

Workout _workout({
  required String id,
  required String name,
  required WorkoutCategory category,
  List<MuscleGroup> focusMuscles = const <MuscleGroup>[],
  List<String> blockExerciseIds = const <String>[],
}) =>
    Workout(
      id: id,
      name: name,
      category: category,
      level: Difficulty.beginner,
      goal: '',
      durationMin: 15,
      description: '',
      focusMuscles: focusMuscles,
      blocks: [
        for (final exerciseId in blockExerciseIds)
          WorkoutBlock(exerciseId: exerciseId),
      ],
      demoVideoAsset: '',
    );

List<Workout> _library() => [
      _workout(
        id: 'w_legs',
        name: 'Lunge and Squat Lab',
        category: WorkoutCategory.strength,
        focusMuscles: const [MuscleGroup.glutes],
        blockExerciseIds: const ['squat'],
      ),
      _workout(
        id: 'w_abs',
        name: 'Ab Blast',
        category: WorkoutCategory.core,
        blockExerciseIds: const ['plank'],
      ),
      _workout(
        id: 'w_push',
        name: 'Upper Ladder Circuit',
        category: WorkoutCategory.fullBody,
        blockExerciseIds: const ['pushup'],
      ),
      _workout(
        id: 'w_mob',
        name: 'Wind Down Mobility',
        category: WorkoutCategory.mobility,
      ),
    ];

List<Exercise> _exerciseCatalog() => [
      const Exercise(
        id: 'squat',
        name: 'Bodyweight Squat',
        kind: ExerciseKind.counted,
        primaryMuscles: [MuscleGroup.legs],
        difficulty: Difficulty.beginner,
        description: '',
        formCues: [],
        met: 3.5,
      ),
      const Exercise(
        id: 'plank',
        name: 'Forearm Plank',
        kind: ExerciseKind.manual,
        primaryMuscles: [MuscleGroup.core],
        difficulty: Difficulty.beginner,
        description: '',
        formCues: [],
        met: 3.0,
      ),
      const Exercise(
        id: 'pushup',
        name: 'Push-Up',
        kind: ExerciseKind.counted,
        primaryMuscles: [MuscleGroup.chest],
        difficulty: Difficulty.beginner,
        description: '',
        formCues: [],
        met: 4.0,
      ),
    ];

Future<void> _pumpWorkoutScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workoutRepositoryProvider.overrideWithValue(
            _FakeWorkoutRepo(_library())),
        exerciseRepositoryProvider
            .overrideWithValue(_FakeExerciseRepo(_exerciseCatalog())),
        planRepositoryProvider.overrideWithValue(_FakePlanRepo()),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const WorkoutScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Opens the search field and types [query].
Future<void> _search(WidgetTester tester, String query) async {
  await tester.tap(find.byIcon(Icons.search));
  await tester.pump();
  await tester.enterText(find.byType(TextField), query);
  await tester.pump();
}

void main() {
  testWidgets('related word "legs" filters the library via synonyms',
      (tester) async {
    await _pumpWorkoutScreen(tester);

    // Everything is visible before searching.
    expect(find.text('Lunge and Squat Lab'), findsOneWidget);
    expect(find.text('Ab Blast'), findsOneWidget);
    expect(find.text('Upper Ladder Circuit'), findsOneWidget);
    expect(find.text('Wind Down Mobility'), findsOneWidget);

    await _search(tester, 'legs');

    expect(find.text('Lunge and Squat Lab'), findsOneWidget,
        reason: 'legs → squat/lunge/glutes class matches');
    expect(find.text('Ab Blast'), findsNothing);
    expect(find.text('Upper Ladder Circuit'), findsNothing);
    expect(find.text('Wind Down Mobility'), findsNothing);
  });

  testWidgets('related word "waist" reaches "Ab Blast" through the merged '
      'abs/core class', (tester) async {
    await _pumpWorkoutScreen(tester);
    await _search(tester, 'waist');

    expect(find.text('Ab Blast'), findsOneWidget,
        reason: 'waist → abs/core → category "Core"');
    expect(find.text('Lunge and Squat Lab'), findsNothing);
    expect(find.text('Upper Ladder Circuit'), findsNothing);
    expect(find.text('Wind Down Mobility'), findsNothing);
  });

  testWidgets('"push" finds the workout through its block exercise',
      (tester) async {
    await _pumpWorkoutScreen(tester);
    await _search(tester, 'push');

    expect(find.text('Upper Ladder Circuit'), findsOneWidget,
        reason: 'block exerciseId `pushup` + catalog name "Push-Up"');
    expect(find.text('Lunge and Squat Lab'), findsNothing);
    expect(find.text('Ab Blast'), findsNothing);
    expect(find.text('Wind Down Mobility'), findsNothing);
  });

  testWidgets('no matches shows the search-aware empty state',
      (tester) async {
    await _pumpWorkoutScreen(tester);
    await _search(tester, 'zzzz');

    expect(find.text('No workouts match "zzzz".'), findsOneWidget);
    expect(
      find.text(
          'Try a muscle (legs, chest), a goal (fat burn), or an exercise (squat).'),
      findsOneWidget,
    );
    expect(find.text('0 workouts'), findsOneWidget,
        reason: 'the header count follows the same filter');
  });
}
