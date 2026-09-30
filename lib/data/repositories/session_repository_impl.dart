import '../../../domain/entities/workout_session.dart';
import '../../../domain/repositories/session_repository.dart';
import '../datasources/local/session_dao.dart';

/// Session persistence over Drift (offline-first, append-only history).
class SessionRepositoryImpl implements SessionRepository {
  SessionRepositoryImpl(this._dao);

  final SessionDao _dao;

  @override
  Future<WorkoutSession?> activeSession() => _dao.activeSession();

  @override
  Future<void> saveActive(WorkoutSession session) => _dao.upsert(session);

  @override
  Future<void> clearActive() async {
    final active = await _dao.activeSession();
    if (active != null) await _dao.remove(active.id);
  }

  @override
  Future<void> completeSession(WorkoutSession session) =>
      _dao.upsert(session.copyWith());

  @override
  Future<List<WorkoutSession>> history({int limit = 100}) =>
      _dao.history(limit: limit);

  @override
  Future<List<WorkoutSession>> sessionsBetween(DateTime from, DateTime to) =>
      _dao.between(from, to);
}
