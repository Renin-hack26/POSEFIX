/// Post-workout report (FR-6) — snapshot of a session's headline metrics
/// plus per-exercise breakdown; source for PDF/CSV export and drill-downs.
library;

import 'workout_session.dart';

/// Per-exercise rollup inside a report.
class ExerciseBreakdown {
  const ExerciseBreakdown({
    required this.exerciseId,
    required this.rounds,
    required this.reps,
    required this.avgFormPct,
    required this.avgRepTimeSec,
  });

  final String exerciseId;
  final int rounds;
  final int reps;
  final double avgFormPct;
  final double avgRepTimeSec;
}

class Report {
  const Report({
    required this.id,
    required this.sessionId,
    required this.workoutId,
    required this.generatedAt,
    required this.totalReps,
    required this.durationSec,
    required this.avgCadenceRpm,
    required this.formAccuracyPct,
    required this.roundsTotal,
    required this.breakdown,
    this.syncedAt,
  });

  final String id;
  final String sessionId;
  final String workoutId;
  final DateTime generatedAt;

  // ---- FR-6 headline ----
  final int totalReps;
  final int durationSec;
  final double avgCadenceRpm;
  final double formAccuracyPct;
  final int roundsTotal;
  final List<ExerciseBreakdown> breakdown;
  final DateTime? syncedAt;

  /// Builds the report snapshot from a completed session.
  factory Report.fromSession(WorkoutSession session) {
    final breakdown = <ExerciseBreakdown>[];
    for (final ex in session.exercises) {
      final avgRep = ex.perRepTimesSec.isEmpty
          ? 0.0
          : ex.perRepTimesSec.reduce((a, b) => a + b) / ex.perRepTimesSec.length;
      breakdown.add(ExerciseBreakdown(
        exerciseId: ex.exerciseId,
        rounds: ex.roundsCompleted,
        reps: ex.totalReps,
        avgFormPct: ex.formAccuracyPct,
        avgRepTimeSec: avgRep,
      ));
    }
    return Report(
      id: 'rep_${session.id}',
      sessionId: session.id,
      workoutId: session.workoutId,
      generatedAt: session.endedAt ?? DateTime.now(),
      totalReps: session.totalReps,
      durationSec: session.durationSec,
      avgCadenceRpm: session.avgCadenceRpm,
      formAccuracyPct: session.formAccuracyPct,
      roundsTotal:
          session.exercises.fold(0, (sum, e) => sum + e.roundsCompleted),
      breakdown: breakdown,
    );
  }
}
