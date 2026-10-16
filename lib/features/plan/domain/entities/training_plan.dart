/// Training plan — 7-day weekly schedule generated at onboarding and
/// editable in the Plan tab (PLANNING §5.4 / §7).
library;

enum PlanSource { ai, manual }

enum PlanSessionStatus { planned, done, skipped }

/// One scheduled workout slot inside a day.
class PlanSession {
  const PlanSession({
    required this.id,
    required this.workoutId,
    required this.startTimeMin,
    this.status = PlanSessionStatus.planned,
    this.roundsOverride,
  });

  final String id;
  final String workoutId;

  /// Minutes since midnight (local) — feeds NOTIFICATION_ENGINE scheduling.
  final int startTimeMin;
  final PlanSessionStatus status;

  /// User-edited round count for the session (null → workout default).
  final int? roundsOverride;

  PlanSession copyWith({
    String? id,
    String? workoutId,
    int? startTimeMin,
    PlanSessionStatus? status,
    int? roundsOverride,
  }) =>
      PlanSession(
        id: id ?? this.id,
        workoutId: workoutId ?? this.workoutId,
        startTimeMin: startTimeMin ?? this.startTimeMin,
        status: status ?? this.status,
        roundsOverride: roundsOverride ?? this.roundsOverride,
      );
}

/// A calendar day inside the plan week.
class PlanDay {
  const PlanDay({required this.date, this.sessions = const []});

  final DateTime date;
  final List<PlanSession> sessions;

  PlanDay copyWith({List<PlanSession>? sessions}) =>
      PlanDay(date: date, sessions: sessions ?? this.sessions);
}

/// The current weekly plan (week starts on [weekStart], 7 [days]).
class TrainingPlan {
  const TrainingPlan({
    required this.id,
    required this.weekStart,
    required this.days,
    required this.source,
    required this.lastUpdated,
    this.syncedAt,
  });

  final String id;

  /// Local date of the first day of the week (midnight).
  final DateTime weekStart;
  final List<PlanDay> days;
  final PlanSource source;
  final DateTime lastUpdated;

  /// Server sync watermark (null → dirty, queued for upload).
  final DateTime? syncedAt;

  TrainingPlan copyWith({
    String? id,
    DateTime? weekStart,
    List<PlanDay>? days,
    PlanSource? source,
    DateTime? lastUpdated,
    DateTime? syncedAt,
    bool keepSynced = false,
  }) =>
      TrainingPlan(
        id: id ?? this.id,
        weekStart: weekStart ?? this.weekStart,
        days: days ?? this.days,
        source: source ?? this.source,
        lastUpdated: lastUpdated ?? this.lastUpdated,
        syncedAt: keepSynced ? this.syncedAt : (syncedAt ?? this.syncedAt),
      );

  /// Today's scheduled sessions (empty when [date] is outside the week).
  List<PlanSession> sessionsFor(DateTime date) {
    for (final day in days) {
      if (day.date.year == date.year &&
          day.date.month == date.month &&
          day.date.day == date.day) {
        return day.sessions;
      }
    }
    return const [];
  }
}
