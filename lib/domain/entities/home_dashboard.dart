/// Home dashboard aggregate — everything the HOME tab renders in one read
/// (PLANNING §5.2). Computed by `GetHomeDashboard`; presentation maps 1:1.
library;

import 'report.dart';
import 'strike_state.dart';
import 'training_plan.dart';
import 'workout.dart';
import 'workout_session.dart';

/// A scheduled session resolved against the workout catalog.
class TodaySession {
  const TodaySession({required this.planSession, required this.workout});

  final PlanSession planSession;
  final Workout workout;
}

/// One bar of the "time spent working out" graph.
class DailyMinutes {
  const DailyMinutes({required this.date, required this.minutes});

  final DateTime date;
  final int minutes;
}

class HomeDashboard {
  const HomeDashboard({
    required this.strike,
    required this.gapDays,
    required this.lastSession,
    required this.weekMinutes,
    required this.weekSessions,
    required this.weekReps,
    required this.hasPlan,
    required this.todaySessions,
    required this.activeSession,
    required this.suggestions,
    required this.tips,
    required this.graph,
    required this.bestFormPct30d,
    required this.exerciseFrequency30d,
    required this.latestReport,
  });

  /// Rollover-applied strike (badge header + greeting rules).
  final StrikeState strike;

  /// Whole days since the last session (null = never trained).
  final int? gapDays;
  final WorkoutSession? lastSession;

  // --- performance line ---
  final int weekMinutes;
  final int weekSessions;
  final int weekReps;

  // --- start/resume slot state machine inputs ---
  final bool hasPlan;
  final List<TodaySession> todaySessions;

  /// In-flight session (active or paused) — slot shows Resume.
  final WorkoutSession? activeSession;

  // --- content slots ---
  final List<Workout> suggestions;
  final List<String> tips;

  /// Last 28 days, always dense (zero-filled) — fl_chart bars.
  final List<DailyMinutes> graph;

  // --- extended analytics ---
  final double bestFormPct30d;

  /// exerciseId → completed-round count over 30 days.
  final Map<String, int> exerciseFrequency30d;

  /// Report slot: snapshot of the most recent completed session.
  final Report? latestReport;
}
