import '../../domain/entities/training_plan.dart';
import '../../domain/repositories/plan_repository.dart';
import '../datasources/local/plan_dao.dart';

/// Weekly plan persistence — local-first (Drift primary). Every local write
/// clears `syncedAt`, marking the row dirty for the next SyncEngine sweep
/// (upload-only; downloads bypass this repository and hit the DAO directly).
class PlanRepositoryImpl implements PlanRepository {
  PlanRepositoryImpl(this._dao);

  final PlanDao _dao;

  @override
  Future<TrainingPlan?> currentPlan() => _dao.latest();

  @override
  Future<void> savePlan(TrainingPlan plan) => _dao.upsert(_dirty(plan));

  @override
  Future<void> updateSession(PlanSession session) async {
    final plan = await _dao.latest();
    if (plan == null) return;

    var found = false;
    final days = <PlanDay>[];
    for (final day in plan.days) {
      if (!day.sessions.any((s) => s.id == session.id)) {
        days.add(day);
        continue;
      }
      found = true;
      days.add(day.copyWith(
        sessions: [
          for (final s in day.sessions) s.id == session.id ? session : s,
        ],
      ));
    }
    if (!found) return;

    await _dao.upsert(_dirty(TrainingPlan(
      id: plan.id,
      weekStart: plan.weekStart,
      days: days,
      source: plan.source,
      lastUpdated: DateTime.now(),
    )));
  }

  /// Edit semantics: bump `lastUpdated`, clear the sync watermark (dirty).
  TrainingPlan _dirty(TrainingPlan plan) => TrainingPlan(
        id: plan.id,
        weekStart: plan.weekStart,
        days: plan.days,
        source: plan.source,
        lastUpdated: plan.lastUpdated,
        syncedAt: null,
      );
}
