import '../../engines/strike_engine/strike_engine.dart';
import '../entities/report.dart';
import '../entities/training_plan.dart';
import '../entities/workout_session.dart';
import '../repositories/plan_repository.dart';
import '../repositories/progress_repository.dart';
import '../repositories/session_repository.dart';

/// Finalizes the in-flight session (FR-6) and runs the post-workout chain:
/// strike + badges + plan credit + the post-workout report.
///
/// Sessions shorter than a minute get no credit (no strike, plan keeps its
/// status) — "showing up" means actual work.
class EndSession {
  EndSession(this._sessions, this._progress, this._plan, this._engine);

  final SessionRepository _sessions;
  final ProgressRepository _progress;
  final PlanRepository _plan;
  final StrikeEngine _engine;

  static const int _minCreditSeconds = 60;

  Future<Report> call(WorkoutSession session,
      {bool abandoned = false}) async {
    final now = DateTime.now();
    final finalized = _finalize(session, endedAt: now, abandoned: abandoned);
    await _sessions.completeSession(finalized);

    if (finalized.durationSec >= _minCreditSeconds) {
      await _creditStrike(finalized);
      await _creditPlan(finalized);
    }
    return Report.fromSession(finalized);
  }

  /// Fills headline metrics from per-exercise data when the live engine
  /// didn't (short/interrupted sessions).
  WorkoutSession _finalize(
    WorkoutSession session, {
    required DateTime endedAt,
    required bool abandoned,
  }) {
    final exercises = session.exercises;
    final totalReps = session.totalReps != 0
        ? session.totalReps
        : exercises.fold<int>(0, (sum, e) => sum + e.totalReps);

    final durationSec = session.durationSec != 0
        ? session.durationSec
        : endedAt.difference(session.startedAt).inSeconds;

    final gaps = exercises.expand((e) => e.perRepTimesSec).toList();
    final cadence = session.avgCadenceRpm != 0
        ? session.avgCadenceRpm
        : (gaps.isEmpty
            ? 0.0
            : 60.0 / (gaps.reduce((a, b) => a + b) / gaps.length));

    final analyzed = exercises.where((e) => e.totalReps > 0).toList();
    final formAccuracy = session.formAccuracyPct != 0
        ? session.formAccuracyPct
        : analyzed.isEmpty
            ? 0.0
            : analyzed.fold<double>(
                    0, (sum, e) => sum + e.formAccuracyPct * e.totalReps) /
                analyzed.fold<int>(0, (sum, e) => sum + e.totalReps);

    return session.copyWith(
      status: abandoned ? SessionStatus.abandoned : SessionStatus.completed,
      endedAt: endedAt,
      clearPaused: true,
      durationSec: durationSec,
      totalReps: totalReps,
      avgCadenceRpm: cadence,
      formAccuracyPct: formAccuracy,
    );
  }

  Future<void> _creditStrike(WorkoutSession session) async {
    final current = await _progress.strike();
    final next = _engine.onWorkoutCompleted(
      current,
      now: DateTime.now(),
      formAccuracyPct: session.formAccuracyPct,
    );
    if (!identical(next, current)) {
      await _progress.saveStrike(next);
    }
  }

  Future<void> _creditPlan(WorkoutSession session) async {
    final planSessionId = session.planSessionId;
    if (planSessionId == null) return;
    final plan = await _plan.currentPlan();
    if (plan == null) return;
    for (final day in plan.days) {
      for (final s in day.sessions) {
        if (s.id == planSessionId &&
            s.status != PlanSessionStatus.done) {
          await _plan
              .updateSession(s.copyWith(status: PlanSessionStatus.done));
          return;
        }
      }
    }
  }
}
