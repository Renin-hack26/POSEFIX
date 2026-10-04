import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../../core/storage/app_database.dart';
import '../../../domain/entities/workout_session.dart';
import '../../mappers/session_json.dart';

part 'session_dao.g.dart';

/// Workout session persistence (history append-only + one in-flight row).
@DriftAccessor(tables: [WorkoutSessions])
class SessionDao extends DatabaseAccessor<AppDatabase>
    with _$SessionDaoMixin {
  SessionDao(super.db);

  // --- row <-> entity -----------------------------------------------------

  /// One corrupt row (bad status string, malformed JSON) skips loudly
  /// instead of sinking the query — and single-row lookups degrade to
  /// null (self-healing: the next save overwrites the bad row).
  WorkoutSession? _fromRowOrNull(WorkoutSessionRow row) {
    try {
      return _fromRow(row);
    } catch (e) {
      debugPrint('sessions: skipping unreadable row ${row.id} ($e)');
      return null;
    }
  }

  WorkoutSession _fromRow(WorkoutSessionRow row) => WorkoutSession(
        id: row.id,
        workoutId: row.workoutId,
        planSessionId: row.planSessionId,
        startedAt: row.startedAt,
        endedAt: row.endedAt,
        status: SessionStatus.values.byName(row.status),
        exercises: decodeSessionExercises(row.exercisesJson),
        restDurationsSec: decodeDoubles(row.restJson),
        pausedState: decodePaused(row.pausedJson),
        durationSec: row.durationSec,
        totalReps: row.totalReps,
        avgCadenceRpm: row.avgCadenceRpm,
        formAccuracyPct: row.formAccuracyPct,
        syncedAt: row.syncedAt,
      );

  WorkoutSessionsCompanion _toCompanion(WorkoutSession s) =>
      WorkoutSessionsCompanion.insert(
        id: s.id,
        workoutId: s.workoutId,
        planSessionId: Value(s.planSessionId),
        startedAt: s.startedAt,
        endedAt: Value(s.endedAt),
        status: s.status.name,
        exercisesJson: Value(encodeSessionExercises(s.exercises)),
        restJson: Value(encodeDoubles(s.restDurationsSec)),
        pausedJson: Value(encodePaused(s.pausedState)),
        durationSec: Value(s.durationSec),
        totalReps: Value(s.totalReps),
        avgCadenceRpm: Value(s.avgCadenceRpm),
        formAccuracyPct: Value(s.formAccuracyPct),
        syncedAt: Value(s.syncedAt),
      );

  // --- queries ------------------------------------------------------------

  /// The in-flight session (active or paused), newest first.
  Future<WorkoutSession?> activeSession() async {
    final row = (await (select(workoutSessions)
          ..where((t) =>
              t.status.equals(SessionStatus.active.name) |
              t.status.equals(SessionStatus.paused.name))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
          ..limit(1))
        .getSingleOrNull());
    return row == null ? null : _fromRowOrNull(row);
  }

  Future<void> upsert(WorkoutSession session) =>
      into(workoutSessions).insertOnConflictUpdate(_toCompanion(session));

  /// Merge lookup for the sync engine.
  Future<WorkoutSession?> byId(String id) async {
    final row = await (select(workoutSessions)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _fromRowOrNull(row);
  }

  Future<void> remove(String id) =>
      (delete(workoutSessions)..where((t) => t.id.equals(id))).go();

  Future<List<WorkoutSession>> history({int limit = 100}) async {
    final rows = await (select(workoutSessions)
          ..where((t) =>
              t.status.equals(SessionStatus.completed.name) |
              t.status.equals(SessionStatus.abandoned.name))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
          ..limit(limit))
        .get();
    return rows.map(_fromRowOrNull).whereType<WorkoutSession>().toList();
  }

  Future<List<WorkoutSession>> between(DateTime from, DateTime to) async {
    final rows = await (select(workoutSessions)
          ..where((t) =>
              t.startedAt.isBiggerOrEqualValue(from) &
              t.startedAt.isSmallerThanValue(to) &
              (t.status.equals(SessionStatus.completed.name) |
                  t.status.equals(SessionStatus.abandoned.name)))
          ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]))
        .get();
    return rows.map(_fromRowOrNull).whereType<WorkoutSession>().toList();
  }

  // --- sync -------------------------------------------------------------

  /// Completed/abandoned history marked dirty (syncedAt IS NULL) — upload
  /// candidates. In-flight rows are deliberately excluded: they upload once
  /// completed (their watermark is still NULL at that point).
  Future<List<WorkoutSession>> dirty() async {
    final rows = await (select(workoutSessions)
          ..where((t) =>
              t.syncedAt.isNull() &
              (t.status.equals(SessionStatus.completed.name) |
                  t.status.equals(SessionStatus.abandoned.name)))
          ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]))
        .get();
    return rows.map(_fromRowOrNull).whereType<WorkoutSession>().toList();
  }

  /// Applies the sync watermark after a successful upload.
  Future<void> markSynced(String id, DateTime at) =>
      (update(workoutSessions)
            ..where((t) => t.id.equals(id) & t.syncedAt.isNull()))
          .write(WorkoutSessionsCompanion(syncedAt: Value(at)));
}
