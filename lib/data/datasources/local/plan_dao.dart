import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../../../domain/entities/training_plan.dart';
import '../../mappers/plan_json.dart';

part 'plan_dao.g.dart';

/// Weekly training plans — newest `lastUpdated` row is the current plan.
@DriftAccessor(tables: [TrainingPlans])
class PlanDao extends DatabaseAccessor<AppDatabase> with _$PlanDaoMixin {
  PlanDao(super.db);

  TrainingPlan _fromRow(TrainingPlanRow row) => TrainingPlan(
        id: row.id,
        weekStart: row.weekStart,
        source: PlanSource.values.byName(row.source),
        days: decodePlanDays(row.daysJson),
        lastUpdated: row.lastUpdated,
        syncedAt: row.syncedAt,
      );

  TrainingPlansCompanion _toCompanion(TrainingPlan plan) =>
      TrainingPlansCompanion.insert(
        id: plan.id,
        weekStart: plan.weekStart,
        source: plan.source.name,
        daysJson: Value(encodePlanDays(plan.days)),
        lastUpdated: plan.lastUpdated,
        syncedAt: Value(plan.syncedAt),
      );

  Future<TrainingPlan?> latest() async {
    final row = await (select(trainingPlans)
          ..orderBy([(t) => OrderingTerm.desc(t.lastUpdated)])
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  /// Upsert; clears `syncedAt` implicitly (dirty) via the entity value.
  Future<void> upsert(TrainingPlan plan) =>
      into(trainingPlans).insertOnConflictUpdate(_toCompanion(plan));

  /// Merge lookup for the sync engine.
  Future<TrainingPlan?> byId(String id) async {
    final row = await (select(trainingPlans)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  // --- sync -------------------------------------------------------------

  Future<TrainingPlan?> dirty() async {
    final row = await (select(trainingPlans)
          ..where((t) => t.syncedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<void> markSynced(String id, DateTime at) =>
      (update(trainingPlans)..where((t) => t.id.equals(id)))
          .write(TrainingPlansCompanion(syncedAt: Value(at)));
}
