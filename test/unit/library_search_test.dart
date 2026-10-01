/// WS7 — smart library search (items 7.1–7.3, 7.5).
///
/// Contract:
///  * exact + partial (word-prefix) workout-name matches;
///  * related-word expansion in BOTH directions (`legs` finds a squat
///    workout, `core` finds "Ab Blast", `waist` transitively finds the
///    abs class) — pure synonym paths only, no direct-field coincidence;
///  * multi-token queries are AND across tokens;
///  * exercise names inside blocks match (`push` finds the workout whose
///    blocks contain Push-Up), via the id→name map and via raw ids;
///  * typo tolerance for one-edit tokens (`sqat` → squat);
///  * no match → empty; empty query → input unchanged;
///  * results always preserve the library's original order.
library;

import 'dart:convert';
import 'dart:io';

import 'package:fixpose/core/search/library_search.dart';
import 'package:fixpose/data/mappers/content_mappers.dart';
import 'package:fixpose/domain/entities/exercise.dart';
import 'package:fixpose/domain/entities/workout.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixture workout — every field optional so each test only states the
/// surfaces it cares about.
Workout _workout({
  required String id,
  required String name,
  WorkoutCategory category = WorkoutCategory.strength,
  Difficulty level = Difficulty.beginner,
  String goal = '',
  String description = '',
  List<MuscleGroup> focusMuscles = const <MuscleGroup>[],
  List<String> blockExerciseIds = const <String>[],
}) =>
    Workout(
      id: id,
      name: name,
      category: category,
      level: level,
      goal: goal,
      durationMin: 20,
      description: description,
      focusMuscles: focusMuscles,
      blocks: [
        for (final exerciseId in blockExerciseIds)
          WorkoutBlock(exerciseId: exerciseId),
      ],
      demoVideoAsset: '',
    );

/// The 5-workout library used across the tests (order matters — several
/// assertions rely on it).
///
///  w1 Lunge and Squat Lab  — "legs" is only reachable via synonyms
///  w2 Ab Blast             — category core; "waist" only via synonyms
///  w3 HIIT Lower Body Blast
///  w4 Plank Party          — no "core"/"ab" anywhere; "core" via synonyms
///  w5 Upper Ladder         — blocks reference pushup + pecDeck
List<Workout> _library() => [
      _workout(
        id: 'w1',
        name: 'Lunge and Squat Lab',
        goal: 'Build lower-body power',
        focusMuscles: const [MuscleGroup.glutes],
        blockExerciseIds: const ['lunge', 'squat'],
      ),
      _workout(
        id: 'w2',
        name: 'Ab Blast',
        category: WorkoutCategory.core,
        focusMuscles: const [MuscleGroup.core],
        blockExerciseIds: const ['plank'],
      ),
      _workout(
        id: 'w3',
        name: 'HIIT Lower Body Blast',
        category: WorkoutCategory.hiit,
        focusMuscles: const [MuscleGroup.cardio],
        blockExerciseIds: const ['mountain-climber'],
      ),
      _workout(
        id: 'w4',
        name: 'Plank Party',
        level: Difficulty.intermediate,
      ),
      _workout(
        id: 'w5',
        name: 'Upper Ladder',
        category: WorkoutCategory.fullBody,
        blockExerciseIds: const ['pushup', 'pecDeck'],
      ),
    ];

List<String> _ids(List<Workout> workouts) =>
    [for (final w in workouts) w.id];

void main() {
  group('name matching', () {
    test('exact workout-name match (whole query, multi-token AND)', () {
      final result = LibrarySearch.filter(_library(), 'plank party');
      expect(_ids(result), ['w4'],
          reason: 'every token of the exact name must match');
    });

    test('partial / word-prefix match', () {
      expect(_ids(LibrarySearch.filter(_library(), 'squ')), ['w1'],
          reason: 'prefix of a name word matches');
      expect(_ids(LibrarySearch.filter(_library(), 'lun')), ['w1']);
      expect(_ids(LibrarySearch.filter(_library(), '  Squ  ')), ['w1'],
          reason: 'query is trimmed and case-insensitive');
    });
  });

  group('related-word expansion (7.2)', () {
    test('query "legs" finds the squat/lunge workout (synonym path)', () {
      final ids = _ids(LibrarySearch.filter(_library(), 'legs'));
      expect(ids, contains('w1'),
          reason: 'legs → squat/lunge/lower/glutes class');
      expect(ids, isNot(contains('w2')));
      expect(ids, isNot(contains('w4')));
      expect(ids, isNot(contains('w5')));
    });

    test('query "core" finds "Ab Blast" (synonym path)', () {
      final ids = _ids(LibrarySearch.filter(_library(), 'core'));
      expect(ids, contains('w2'));
      expect(ids, contains('w4'),
          reason: 'core → plank class finds Plank Party');
      expect(ids, isNot(contains('w1')));
      expect(ids, isNot(contains('w3')));
      expect(ids, isNot(contains('w5')));
    });

    test('belly/stomach/waist group folds into the abs class transitively',
        () {
      final ids = _ids(LibrarySearch.filter(_library(), 'waist'));
      expect(ids, contains('w2'),
          reason: 'waist → abs/core → "Ab Blast" (merged classes)');
      expect(ids, contains('w4'),
          reason: 'waist → abs/core → plank block');
      expect(ids, isNot(contains('w1')));
      expect(ids, isNot(contains('w3')));
      expect(ids, isNot(contains('w5')));
    });
  });

  group('multi-token AND (7.2)', () {
    test('"hiit legs" matches only the workout with both signals', () {
      expect(_ids(LibrarySearch.filter(_library(), 'hiit legs')), ['w3'],
          reason: 'w1/w4/w5 lack HIIT, w2/w4/w5 lack legs-class words');
    });

    test('one failing token excludes an otherwise matching workout', () {
      // w2 matches "hiit" (via `blast` in "Ab Blast") but not "legs".
      expect(_ids(LibrarySearch.filter(_library(), 'hiit waist')), ['w2']);
    });
  });

  group('block exercises (7.1)', () {
    test('"push" finds the workout whose blocks contain push-up', () {
      expect(_ids(LibrarySearch.filter(_library(), 'push')), ['w5'],
          reason: 'raw exerciseId `pushup` is indexed without a name map');
    });

    test('id→name map adds the display name as a surface', () {
      const names = {'pecDeck': 'Bench Press Machine'};
      expect(
        _ids(LibrarySearch.filter(_library(), 'machine',
            exerciseNames: names)),
        ['w5'],
        reason: 'display name only exists in the map',
      );
      expect(
        _ids(LibrarySearch.filter(_library(), 'machine')),
        isEmpty,
        reason: 'without the map there is nothing to match',
      );
      // The map also feeds synonym classes: "pecs" reaches "Bench…" via
      // the chest class (bench/press) even though the id says nothing.
      expect(
        _ids(LibrarySearch.filter(_library(), 'bench',
            exerciseNames: names)),
        ['w5'],
      );
    });
  });

  group('typo tolerance (7.3)', () {
    test('"sqat" matches the squat workout', () {
      expect(_ids(LibrarySearch.filter(_library(), 'sqat')), ['w1'],
          reason: 'one edit, longer side ≥ 5 chars');
    });

    test('short similar words do NOT collide', () {
      // `core` and `care`-style neighbours must stay distinct.
      expect(_ids(LibrarySearch.filter(_library(), 'qore')), isEmpty,
          reason: 'both sides < 5 chars → no edit-distance match');
    });
  });

  group('edge cases + ordering (7.5)', () {
    test('no match → empty list', () {
      expect(LibrarySearch.filter(_library(), 'zzzz'), isEmpty);
      expect(LibrarySearch.filter(_library(), 'zzz legs'), isEmpty,
          reason: 'AND: one unmatched token drops the workout');
    });

    test('empty / whitespace query returns the input unchanged', () {
      final workouts = _library();
      expect(LibrarySearch.filter(workouts, ''), same(workouts));
      expect(LibrarySearch.filter(workouts, '   '), same(workouts));
      expect(_ids(LibrarySearch.filter(workouts, '')),
          ['w1', 'w2', 'w3', 'w4', 'w5']);
    });

    test('results preserve the library order (never re-sorted by score)',
        () {
      // "l" matches w1 (lunge), w3 (lower) and w5 (ladder) but not
      // w2/w4 — the gaps must stay in place, i.e. input order.
      expect(
        _ids(LibrarySearch.filter(_library(), 'l')),
        ['w1', 'w3', 'w5'],
        reason: 'score decides inclusion only, never ordering',
      );
      // Same query from a shuffled input → shuffled output, same order.
      final reversed = _library().reversed.toList();
      expect(
        _ids(LibrarySearch.filter(reversed, 'l')),
        ['w5', 'w3', 'w1'],
        reason: 'output order mirrors the input, not a rank list',
      );
    });
  });

  group('exercise catalog + shared text matcher (7.1)', () {
    final exercises = [
      const Exercise(
        id: 'squat',
        name: 'Bodyweight Squat',
        kind: ExerciseKind.counted,
        primaryMuscles: [MuscleGroup.legs],
        difficulty: Difficulty.beginner,
        description: 'Sit back and down, knees tracking over toes.',
        formCues: [],
        met: 3.5,
      ),
      const Exercise(
        id: 'plank',
        name: 'Forearm Plank',
        kind: ExerciseKind.manual,
        primaryMuscles: [MuscleGroup.core],
        difficulty: Difficulty.beginner,
        description: 'Hold a straight line from head to heels.',
        formCues: [],
        met: 3.0,
      ),
      const Exercise(
        id: 'pushup',
        name: 'Push-Up',
        kind: ExerciseKind.counted,
        primaryMuscles: [MuscleGroup.chest],
        difficulty: Difficulty.beginner,
        description: 'Hands under shoulders, elbows ~45°.',
        formCues: [],
        met: 4.0,
      ),
    ];

    test('name prefix + description keyword', () {
      expect(
        LibrarySearch.filterExercises(exercises, 'squa')
            .map((e) => e.id)
            .toList(),
        ['squat'],
      );
      expect(
        LibrarySearch.filterExercises(exercises, 'heels')
            .map((e) => e.id)
            .toList(),
        ['plank'],
        reason: 'description keywords are indexed',
      );
    });

    test('synonyms work for exercises too', () {
      expect(
        LibrarySearch.filterExercises(exercises, 'crunch')
            .map((e) => e.id)
            .toList(),
        ['plank'],
        reason: 'crunch → plank class, no "crunch" anywhere on the surface',
      );
      expect(
        LibrarySearch.filterExercises(exercises, 'pecs')
            .map((e) => e.id)
            .toList(),
        ['pushup'],
        reason: 'pecs → chest class reaches Push-Up',
      );
    });

    test('matchesText: multi-token AND + prefix (food search helper)', () {
      expect(LibrarySearch.matchesText('Chicken Breast', 'chick'), isTrue);
      expect(LibrarySearch.matchesText('Chicken Breast', 'breast chicken'),
          isTrue,
          reason: 'token order is irrelevant');
      expect(LibrarySearch.matchesText('Chicken Breast', 'beef'), isFalse);
      expect(LibrarySearch.matchesText('Chicken Breast', ''), isTrue,
          reason: 'empty query keeps everything');
    });
  });

  group('real 44-workout library (bundled content)', () {
    List<Workout> loadLibrary() {
      final raw = jsonDecode(
              File('assets/data/workouts.json').readAsStringSync())
          as List<dynamic>;
      return [
        for (final e in raw)
          workoutFromJson(e as Map<String, dynamic>, 'workouts.json'),
      ];
    }

    test('empty query keeps all 44 workouts in file order', () {
      final workouts = loadLibrary();
      expect(workouts, hasLength(44));
      final result = LibrarySearch.filter(workouts, '');
      expect(result, hasLength(44));
      expect(result.first.id, 'w001');
      expect(result.last.id, workouts.last.id);
    });

    test('related word "legs" hits lower-body content only', () {
      final ids =
          [for (final w in LibrarySearch.filter(loadLibrary(), 'legs')) w.id];
      final byName = {
        for (final w in loadLibrary()) w.name: w.id,
      };
      expect(ids, contains(byName['Lower Body Foundation']),
          reason: 'legs → `lower`');
      expect(ids, contains(byName['Lunge and Squat Lab']),
          reason: 'legs → lunge/squat');
      expect(ids, isNot(contains(byName['Sunrise Mobility Flow'])),
          reason: 'mobility flow has no legs-class signal');
    });

    test('typo over the real library + nonsense stays empty', () {
      final byName = {
        for (final w in loadLibrary()) w.name: w.id,
      };
      expect(
        [for (final w in LibrarySearch.filter(loadLibrary(), 'sqat')) w.id],
        contains(byName['Lunge and Squat Lab']),
        reason: 'one-edit typo finds the squat workout',
      );
      expect(LibrarySearch.filter(loadLibrary(), 'zzz'), isEmpty);
    });
  });
}
