import '../../core/utils/extensions.dart';
import '../../engines/strike_engine/strike_engine.dart';
import '../entities/home_dashboard.dart';
import '../entities/report.dart';
import '../repositories/content_repository.dart';
import '../repositories/plan_repository.dart';
import '../repositories/session_repository.dart';
import '../repositories/workout_repository.dart';
import 'get_strike_state.dart';

/// Single-pass HOME aggregation (PLANNING §5.2) — one provider refresh feeds
/// every slot of the dashboard.
class GetHomeDashboard {
  GetHomeDashboard(
    this._strikeState,
    this._sessions,
    this._plan,
    this._workouts,
    this._content,
    this._engine,
  );

  final GetStrikeState _strikeState;
  final SessionRepository _sessions;
  final PlanRepository _plan;
  final WorkoutRepository _workouts;
  final ContentRepository _content;
  final StrikeEngine _engine;

  static const int _graphDays = 28;

  Future<HomeDashboard> call() async {
    final now = DateTime.now();
    final strike = await _strikeState();

    final history = await _sessions.history(limit: 300);
    final lastSession = history.isEmpty ? null : history.first;

    // --- current week (Monday - Sunday) ---
    final weekFrom = now.startOfWeek;
    final weekSessions =
        history.where((s) => !s.startedAt.isBefore(weekFrom)).toList();
    final weekMinutes =
        weekSessions.fold<int>(0, (sum, s) => sum + s.durationSec) ~/ 60;
    final weekReps =
        weekSessions.fold<int>(0, (sum, s) => sum + s.totalReps);

    // --- graph: last 28 days, zero-filled ---
    final graphFrom = now.startOfDay.subtract(
        const Duration(days: _graphDays - 1));
    final recent = await _sessions.sessionsBetween(graphFrom, now);
    final minutesByDay = <String, int>{};
    for (final s in recent) {
      minutesByDay.update(
        s.startedAt.dateKey,
        (v) => v + s.durationSec ~/ 60,
        ifAbsent: () => s.durationSec ~/ 60,
      );
    }
    final graph = <DailyMinutes>[
      for (var i = 0; i < _graphDays; i++)
        DailyMinutes(
          date: graphFrom.add(Duration(days: i)),
          minutes: minutesByDay[graphFrom.add(Duration(days: i)).dateKey] ??
              0,
        ),
    ];

    // --- extended analytics (30d window = graph data) ---
    var bestForm = 0.0;
    final frequency = <String, int>{};
    for (final s in recent) {
      if (s.formAccuracyPct > bestForm) bestForm = s.formAccuracyPct;
      for (final e in s.exercises) {
        if (e.roundsCompleted > 0) {
          frequency.update(e.exerciseId, (v) => v + e.roundsCompleted,
              ifAbsent: () => e.roundsCompleted);
        }
      }
    }

    // --- plan + start/resume slot ---
    final plan = await _plan.currentPlan();
    final todaySessions = <TodaySession>[];
    if (plan != null) {
      for (final ps in plan.sessionsFor(now)) {
        final workout = await _workouts.byId(ps.workoutId);
        if (workout != null) {
          todaySessions.add(
              TodaySession(planSession: ps, workout: workout));
        }
      }
    }
    final activeSession = await _sessions.activeSession();

    final suggestions = await _workouts.suggestions(limit: 5);
    final tips = await _content.tips();

    return HomeDashboard(
      strike: strike,
      gapDays: _engine.gapDays(strike, now),
      lastSession: lastSession,
      weekMinutes: weekMinutes,
      weekSessions: weekSessions.length,
      weekReps: weekReps,
      hasPlan: plan != null,
      todaySessions: todaySessions,
      activeSession: activeSession,
      suggestions: suggestions,
      tips: tips,
      graph: graph,
      bestFormPct30d: bestForm,
      exerciseFrequency30d: frequency,
      latestReport: lastSession == null ? null : Report.fromSession(lastSession),
    );
  }
}
