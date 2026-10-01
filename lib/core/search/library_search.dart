/// WS7 — smart library search over the workout catalog (and exercises).
///
/// Pure and synchronous by contract: callers pass the list, the raw query
/// and — for matching exercises referenced by workout blocks — an exercise
/// id → display-name map, so unit tests need no loaders or IO.
///
/// Semantics (items 7.1–7.3):
///  * normalization — lowercase, `_`/`-`/runs of whitespace collapsed to a
///    single space, tokenized on whitespace;
///  * empty / whitespace-only query — the input list is returned as-is;
///  * multi-token query — AND across tokens (every token must match some
///    indexed word);
///  * per-token match surfaces — workout name, category, level, goal,
///    focusMuscles, tags, description keywords and the names (plus raw
///    ids) of the exercises inside `blocks`;
///  * related-word expansion (7.2) — [_synonymGroups] groups are
///    equivalence classes merged transitively; a query token expands to
///    every word of its class, and an indexed word resolves to the same
///    class, so the expansion is effectively bidirectional: "legs" finds
///    squat/lunge/quad/hamstring content, "core" finds ab/plank/crunch
///    content, "belly" finds "Ab Blast", …;
///  * typo tolerance (7.3) — Levenshtein distance ≤ 1 when at least one
///    side is ≥ 5 chars (`sqat` → `squat`, but `core` does not match
///    `care`);
///  * ordering — results always preserve the input order; the match score
///    only decides inclusion (existing UI/tests rely on library order).
library;

import 'dart:math' as math;

import '../../domain/entities/exercise.dart';
import '../../domain/entities/workout.dart';

/// Smart, order-preserving filter for the workout / exercise library.
abstract final class LibrarySearch {
  /// Normalizer shared by query and indexed text: lowercase, `_`/`-` and
  /// whitespace runs collapsed to a single space.
  static final RegExp _separator = RegExp(r'[\s_\-]+');

  /// Synonym equivalence groups (item 7.2). Members are normalized first;
  /// groups sharing a word merge into one class, so `belly/stomach/waist`
  /// inherits the whole abs/core class transitively.
  ///
  /// Multi-word members (`push-up`, `fat burn`, …) are flattened into their
  /// words when building the lookup — see [_trivialWords] for the few
  /// words dropped in the process.
  static const List<List<String>> _synonymGroups = <List<String>>[
    // Legs / lower body.
    ['legs', 'quads', 'hamstrings', 'glutes', 'squat', 'lunge', 'lower', 'thigh', 'calf'],
    // Abs / core (merged with the belly/stomach group below).
    ['abs', 'core', 'abdominal', 'plank', 'crunch', 'sit-up', 'middle', 'midline'],
    // Chest (shares `press` with shoulders → one merged class).
    ['chest', 'pushup', 'push-up', 'press', 'bench', 'pecs'],
    // Back.
    ['back', 'row', 'deadlift', 'pull', 'lats'],
    // Shoulders.
    ['shoulders', 'press', 'lateral', 'raise', 'delts'],
    // Arms.
    ['arms', 'curl', 'tricep', 'bicep'],
    // Cardio / conditioning.
    ['cardio', 'hiit', 'jump', 'run', 'cardio blast', 'fat burn', 'weight loss'],
    // Full body.
    ['full body', 'compound', 'total body', 'whole body'],
    // Stretching / mobility.
    ['stretch', 'mobility', 'flexibility', 'warmup', 'warm up', 'cool down', 'wind down'],
    // Belly / stomach → folds into the abs/core class.
    ['belly', 'stomach', 'waist', 'abs', 'core'],
  ];

  /// Words dropped when a multi-word synonym member is flattened: too
  /// generic to carry meaning (`sit-up` → `sit` would pull every Wall Sit
  /// leg workout into core queries; `up` matches every "Wake-Up").
  static const Set<String> _trivialWords = <String>{
    'up', 'sit', 'and', 'the', 'of', 'to', 'in', 'on', 'at', 'a', 'an',
    'is', 'it', 'or', 'for', 'with',
  };

  /// Word → every word of its (transitively merged) synonym class.
  static final Map<String, Set<String>> _synonyms = _buildSynonymClasses();

  /// Filters [workouts] by [query], preserving the original order.
  ///
  /// [exerciseNames] maps block `exerciseId`s to their display names so
  /// "push" finds workouts containing Push-Ups even when the id itself
  /// gives nothing away (raw ids are indexed too, `-` normalized).
  static List<Workout> filter(
    List<Workout> workouts,
    String query, {
    Map<String, String> exerciseNames = const <String, String>{},
  }) {
    final tokens = tokenize(query);
    if (tokens.isEmpty) return workouts;
    return workouts.where((workout) {
      final words = _workoutWords(workout, exerciseNames);
      return tokens.every((token) => _matchesToken(token, words));
    }).toList();
  }

  /// Like [filter] but over the exercise catalog (item 7.1).
  static List<Exercise> filterExercises(
    List<Exercise> exercises,
    String query,
  ) {
    final tokens = tokenize(query);
    if (tokens.isEmpty) return exercises;
    return exercises.where((exercise) {
      final words = _exerciseWords(exercise);
      return tokens.every((token) => _matchesToken(token, words));
    }).toList();
  }

  /// Normalized whitespace tokens of [query]; empty for blank input.
  static List<String> tokenize(String query) {
    final normalized = query.toLowerCase().replaceAll(_separator, ' ').trim();
    if (normalized.isEmpty) return const <String>[];
    return normalized.split(' ');
  }

  /// True when every token of [query] is a word-prefix of some word in
  /// [text] (empty query matches everything). Shared, lightweight matcher
  /// for non-workout lists (food search) — multi-token AND + prefix only,
  /// no synonyms or typo tolerance.
  static bool matchesText(String text, String query) {
    final tokens = tokenize(query);
    if (tokens.isEmpty) return true;
    final words = tokenize(text);
    return tokens.every((token) => words.any((w) => w.startsWith(token)));
  }

  // ---------------------------------------------------------------------------
  // Indexing
  // ---------------------------------------------------------------------------

  /// Every searchable word of a workout, in surface order.
  static List<String> _workoutWords(
    Workout workout,
    Map<String, String> exerciseNames,
  ) {
    final words = <String>[
      ...tokenize(workout.name),
      ...tokenize(workout.category.label),
      ...tokenize(workout.level.label),
      ...tokenize(workout.goal),
      ...tokenize(workout.description),
      ...tokenize(workout.tags.join(' ')),
      for (final muscle in workout.focusMuscles) ...tokenize(muscle.label),
    ];
    for (final block in workout.blocks) {
      // Raw id (`knee-push-up` → "knee push up") — always indexed, so
      // matching still works when no name map was supplied.
      words.addAll(tokenize(block.exerciseId));
      final name = exerciseNames[block.exerciseId];
      if (name != null) words.addAll(tokenize(name));
    }
    return words;
  }

  /// Every searchable word of an exercise.
  static List<String> _exerciseWords(Exercise exercise) {
    return <String>[
      ...tokenize(exercise.name),
      ...tokenize(exercise.id),
      ...tokenize(exercise.description),
      ...tokenize(exercise.difficulty.label),
      for (final muscle in exercise.primaryMuscles) ...tokenize(muscle.label),
      for (final muscle in exercise.secondaryMuscles) ...tokenize(muscle.label),
    ];
  }

  // ---------------------------------------------------------------------------
  // Matching
  // ---------------------------------------------------------------------------

  /// One query token against every indexed word — direct match or any
  /// word of the token's synonym class.
  static bool _matchesToken(String token, List<String> words) {
    final candidates = <String>{token, ...?_synonyms[token]};
    for (final word in words) {
      for (final candidate in candidates) {
        if (_matchesWord(candidate, word)) return true;
      }
    }
    return false;
  }

  /// Equality, prefix (either side — so `abs` finds "Ab Blast" and
  /// `squats` finds "Squat") or one-edit typo when long enough.
  static bool _matchesWord(String candidate, String word) {
    if (candidate == word) return true;
    if (candidate.isEmpty || word.isEmpty) return false;
    // Query as word-prefix: `squa` → `squat`.
    if (word.startsWith(candidate)) return true;
    // Indexed word as prefix of the candidate: `ab` → `abs`,
    // `push` → `pushup`. Needs a real word on the left so a stray `a` or
    // `an` from a description never matches everything.
    if (word.length >= 3 && candidate.startsWith(word)) return true;
    // Typo tolerance: one edit, with at least one side ≥ 5 chars so two
    // short-but-similar words (`core` / `care`) don't collide.
    if ((candidate.length >= 5 || word.length >= 5) &&
        _levenshtein(candidate, word) <= 1) {
      return true;
    }
    return false;
  }

  /// Classic two-row Levenshtein distance; early-outs when the lengths
  /// differ by more than the caller's threshold. Cheap at library scale
  /// (44 workouts × a few dozen words × a handful of tokens).
  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if ((a.length - b.length).abs() > 1) return 2;
    var prev = List<int>.generate(b.length + 1, (j) => j);
    var curr = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        curr[j] = math.min(
          curr[j - 1] + 1,
          math.min(prev[j] + 1, prev[j - 1] + cost),
        );
      }
      final swap = prev;
      prev = curr;
      curr = swap;
    }
    return prev[b.length];
  }

  // ---------------------------------------------------------------------------
  // Synonym classes
  // ---------------------------------------------------------------------------

  /// Merges [_synonymGroups] transitively (any two groups sharing a word
  /// become one class) and inverts the result into word → class.
  static Map<String, Set<String>> _buildSynonymClasses() {
    final classOf = <String, Set<String>>{};
    for (final group in _synonymGroups) {
      final words = <String>{};
      for (final member in group) {
        for (final word in tokenize(member)) {
          if (!_trivialWords.contains(word)) words.add(word);
        }
      }
      if (words.isEmpty) continue;
      final merged = <String>{};
      for (final word in words) {
        final existing = classOf[word];
        if (existing != null) merged.addAll(existing);
      }
      merged.addAll(words);
      for (final word in merged) {
        classOf[word] = merged;
      }
    }
    return classOf;
  }
}
