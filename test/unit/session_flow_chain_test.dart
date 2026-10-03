/// Multi-exercise workout chain: block sequencing, resume index, and the
/// revived [StartSession] usecase (one record per unique block exercise).
library;

import 'package:fixpose/domain/entities/exercise.dart';
import 'package:fixpose/domain/entities/workout.dart';
import 'package:fixpose/domain/entities/workout_session.dart';
import 'package:fixpose/domain/repositories/session_repository.dart';
import 'package:fixpose/domain/repositories/workout_repository.dart';
import 'package:fixpose/domain/usecases/start_session.dart';
import 'package:fixpose/presentation/vision/session_flow.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSessions implements SessionRepository {
  WorkoutSession? active;

  @override
  Future<WorkoutSession?> activeSession() async => active;

  @override
  Future<void> saveActive(WorkoutSession session) async {
    active = session;
  }

  @override
  Future<void> clearActive() async {
    active = null;
  }

  @override
  Future<void> completeSession(WorkoutSession session) async {
    active = null;
  }

  @override
  Future<List<WorkoutSession>> history({int limit = 100}) async => [];

  @override
  Future<List<WorkoutSession>> sessionsBetween(DateTime from, DateTime to) async =>
      [];
}

class _FakeWorkouts implements WorkoutRepository {
  _FakeWorkouts(this.workouts);

  final Map<String, Workout> workouts;

  @override
  Future<List<Workout>> library() async => workouts.values.toList();

  @override
  Future<Workout?> byId(String id) async => workouts[id];

  @override
  Future<List<Workout>> suggestions({int limit = 5}) async => [];
}

Workout _workout() => const Workout(
      id: 'w1',
      name: 'Chain',
      category: WorkoutCategory.strength,
      level: Difficulty.beginner,
      goal: 'test',
      durationMin: 20,
      description: 'test',
      focusMuscles: [MuscleGroup.chest],
      blocks: [
        WorkoutBlock(exerciseId: 'squat', sets: 2, reps: 10, restSec: 30),
        WorkoutBlock(exerciseId: 'push_up', sets: 3, reps: 8, restSec: 45),
        // Repeated exercise collapses (same record, first prescription).
        WorkoutBlock(exerciseId: 'squat', sets: 9, reps: 9, restSec: 9),
      ],
      demoVideoAsset: '',
    );

void main() {
  group('uniqueBlocks', () {
    test('dedupes by exercise, keeps order and first prescription', () {
      final blocks = uniqueBlocks(
        exerciseIds: const ['squat', 'push_up', 'squat', '', 'push_up'],
        setsFor: (_) => 2,
        repsFor: (_) => 10,
        secondsFor: (_) => 0,
        restFor: (_) => 30,
      );
      expect([for (final b in blocks) b.exerciseId], ['squat', 'push_up']);
      expect(blocks.first.sets, 2);
    });
  });

  group('chainResumeIndex', () {
    test('paused position wins', () {
      expect(
        chainResumeIndex(
          exerciseCount: 3,
          pausedIndex: 2,
          roundsDone: (_) => 9,
          setsTarget: (_) => 2,
        ),
        2,
      );
    });

    test('first incomplete block otherwise; 0 when all complete', () {
      int resume(List<int> done) => chainResumeIndex(
            exerciseCount: 3,
            pausedIndex: null,
            roundsDone: (i) => done[i],
            setsTarget: (_) => 2,
          );
      expect(resume([0, 0, 0]), 0);
      expect(resume([2, 0, 0]), 1);
      expect(resume([2, 2, 0]), 2);
      expect(resume([2, 2, 2]), 0, reason: 're-run from the top');
      expect(
        chainResumeIndex(
          exerciseCount: 3,
          pausedIndex: 9,
          roundsDone: (_) => 0,
          setsTarget: (_) => 2,
        ),
        0,
        reason: 'out-of-range paused index is ignored',
      );
    });
  });

  group('StartSession', () {
    test('creates one record per unique block exercise, order kept', () async {
      final sessions = _FakeSessions();
      final usecase = StartSession(sessions, _FakeWorkouts({'w1': _workout()}));
      final session = await usecase(workoutId: 'w1');
      expect(session.workoutId, 'w1');
      expect(
        [for (final e in session.exercises) e.exerciseId],
        ['squat', 'push_up'],
      );
      expect(sessions.active, isNotNull);
    });

    test('returns the in-flight session instead of duplicating', () async {
      final sessions = _FakeSessions();
      final usecase = StartSession(sessions, _FakeWorkouts({'w1': _workout()}));
      final first = await usecase(workoutId: 'w1');
      final second = await usecase(workoutId: 'w1');
      expect(identical(second, first), isTrue);
    });
  });
}
