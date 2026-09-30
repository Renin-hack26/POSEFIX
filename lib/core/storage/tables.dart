/// Local Drift schema — user data tables (PLANNING §7).
///
/// Sync design: every account-synced table carries a nullable `syncedAt`
/// watermark; `NULL` = dirty → queued for the next upload sweep. Device-local
/// tables (bundled content progress) intentionally omit the column.
library;

import 'package:drift/drift.dart';

/// Performed workout sessions (append-only history + one in-flight row).
@DataClassName('WorkoutSessionRow')
class WorkoutSessions extends Table {
  TextColumn get id => text()();
  TextColumn get workoutId => text()();
  TextColumn get planSessionId => text().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();

  /// SessionStatus.name — active | paused | completed | abandoned.
  TextColumn get status => text()();
  TextColumn get exercisesJson => text().withDefault(const Constant('[]'))();
  TextColumn get restJson => text().withDefault(const Constant('[]'))();
  TextColumn get pausedJson => text().nullable()();
  IntColumn get durationSec => integer().withDefault(const Constant(0))();
  IntColumn get totalReps => integer().withDefault(const Constant(0))();
  RealColumn get avgCadenceRpm => real().withDefault(const Constant(0))();
  RealColumn get formAccuracyPct => real().withDefault(const Constant(0))();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Weekly training plans — newest `lastUpdated` row is current.
@DataClassName('TrainingPlanRow')
class TrainingPlans extends Table {
  TextColumn get id => text()();
  DateTimeColumn get weekStart => dateTime()();

  /// PlanSource.name — ai | manual.
  TextColumn get source => text()();

  /// Serialized PlanDay list (see plan mapping in `plan_dao.dart`).
  TextColumn get daysJson => text().withDefault(const Constant('[]'))();
  DateTimeColumn get lastUpdated => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Manual meal entries — one row per log, indexed by local day bucket.
@DataClassName('MealEntryRow')
class MealEntries extends Table {
  TextColumn get id => text()();
  TextColumn get dateKey => text()();
  TextColumn get name => text()();
  IntColumn get calories => integer()();
  TextColumn get mealType => text()(); // MealType.name
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Daily calorie target (single row, id = 1).
@DataClassName('MealTargetRow')
class MealTargets extends Table {
  IntColumn get id => integer()();
  IntColumn get dailyCalories => integer()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Weight/height entries — one row per day (last-writer-wins per day).
@DataClassName('BodyMetricRow')
class BodyMetrics extends Table {
  TextColumn get dateKey => text()();
  RealColumn get weightKg => real()();
  RealColumn get heightCm => real().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {dateKey};
}

/// Consistency strike + unlocked badge tiers (single row, id = 1).
@DataClassName('StrikeStateRow')
class StrikeStates extends Table {
  IntColumn get id => integer()();
  IntColumn get currentStrike => integer().withDefault(const Constant(0))();
  IntColumn get longestStrike => integer().withDefault(const Constant(0))();
  TextColumn get lastActiveDateKey => text()();
  TextColumn get unlockedTiersJson => text().withDefault(const Constant('[]'))();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// VEDA chat history (account-synced).
@DataClassName('ChatMessageRow')
class ChatMessages extends Table {
  TextColumn get id => text()();
  TextColumn get role => text()(); // ChatRole.name

  /// Message body (named `content` — `text` collides with Table.text()).
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get contextRef => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Device-local per-exercise flags — intentionally NOT synced.
@DataClassName('ExerciseProgressRow')
class ExerciseProgress extends Table {
  TextColumn get exerciseId => text()();
  BoolColumn get videoSeen => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {exerciseId};
}
