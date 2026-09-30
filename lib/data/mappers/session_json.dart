/// JSON codecs for the nested parts of a session row (shared by the local
/// DAO and the sync payload — one shape everywhere).
library;

import 'dart:convert';

import '../../domain/entities/workout_session.dart';

String encodeSessionExercises(List<SessionExercise> exercises) =>
    jsonEncode(exercises.map(exerciseToMap).toList());

List<SessionExercise> decodeSessionExercises(String source) =>
    (jsonDecode(source) as List<dynamic>)
        .map((e) => exerciseFromMap(e as Map<String, dynamic>))
        .toList();

String? encodePaused(PausedState? state) =>
    state == null ? null : jsonEncode(pausedToMap(state));

PausedState? decodePaused(String? source) => source == null
    ? null
    : pausedFromMap(jsonDecode(source) as Map<String, dynamic>);

String encodeDoubles(List<double> values) => jsonEncode(values);

List<double> decodeDoubles(String source) =>
    (jsonDecode(source) as List<dynamic>).cast<double>();

Map<String, dynamic> exerciseToMap(SessionExercise e) => {
      'exerciseId': e.exerciseId,
      'roundsCompleted': e.roundsCompleted,
      'totalReps': e.totalReps,
      'formAccuracyPct': e.formAccuracyPct,
      'perRepTimesSec': e.perRepTimesSec,
      'roundTimesSec': e.roundTimesSec,
      'repsPerRound': e.repsPerRound,
    };

SessionExercise exerciseFromMap(Map<String, dynamic> m) => SessionExercise(
      exerciseId: m['exerciseId'] as String,
      roundsCompleted: (m['roundsCompleted'] as num?)?.toInt() ?? 0,
      totalReps: (m['totalReps'] as num?)?.toInt() ?? 0,
      formAccuracyPct: (m['formAccuracyPct'] as num?)?.toDouble() ?? 0,
      perRepTimesSec:
          ((m['perRepTimesSec'] as List?) ?? const []).cast<double>(),
      roundTimesSec: ((m['roundTimesSec'] as List?) ?? const []).cast<double>(),
      repsPerRound:
          ((m['repsPerRound'] as List?) ?? const []).cast<int>(),
    );

Map<String, dynamic> pausedToMap(PausedState p) => {
      'exerciseIndex': p.exerciseIndex,
      'roundIndex': p.roundIndex,
      'repsInRound': p.repsInRound,
      'elapsedSec': p.elapsedSec,
    };

PausedState pausedFromMap(Map<String, dynamic> m) => PausedState(
      exerciseIndex: (m['exerciseIndex'] as num).toInt(),
      roundIndex: (m['roundIndex'] as num).toInt(),
      repsInRound: (m['repsInRound'] as num).toInt(),
      elapsedSec: (m['elapsedSec'] as num).toInt(),
    );
