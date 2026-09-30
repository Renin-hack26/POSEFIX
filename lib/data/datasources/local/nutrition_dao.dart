import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../../../domain/entities/meal.dart';

part 'nutrition_dao.g.dart';

/// Meal entries + daily calorie target.
@DriftAccessor(tables: [MealEntries, MealTargets])
class NutritionDao extends DatabaseAccessor<AppDatabase>
    with _$NutritionDaoMixin {
  NutritionDao(super.db);

  MealEntry _entryFromRow(MealEntryRow row) => MealEntry(
        id: row.id,
        dateKey: row.dateKey,
        name: row.name,
        calories: row.calories,
        mealType: MealType.values.byName(row.mealType),
        syncedAt: row.syncedAt,
      );

  // --- entries -----------------------------------------------------------

  Future<List<MealEntry>> entriesFor(String dateKey) async {
    final rows = await (select(mealEntries)
          ..where((t) => t.dateKey.equals(dateKey))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
    return rows.map(_entryFromRow).toList();
  }

  Future<void> upsertEntry(MealEntry entry) =>
      into(mealEntries).insertOnConflictUpdate(MealEntriesCompanion.insert(
        id: entry.id,
        dateKey: entry.dateKey,
        name: entry.name,
        calories: entry.calories,
        mealType: entry.mealType.name,
        syncedAt: Value(entry.syncedAt),
      ));

  Future<void> removeEntry(String id) =>
      (delete(mealEntries)..where((t) => t.id.equals(id))).go();

  /// Merge lookup for the sync engine.
  Future<MealEntry?> entryById(String id) async {
    final row = await (select(mealEntries)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _entryFromRow(row);
  }

  // --- target ------------------------------------------------------------

  static const int _targetRowId = 1;

  Future<MealTarget?> target() async {
    final row = await (select(mealTargets)
          ..where((t) => t.id.equals(_targetRowId)))
        .getSingleOrNull();
    if (row == null) return null;
    return MealTarget(dailyCalories: row.dailyCalories, syncedAt: row.syncedAt);
  }

  Future<void> saveTarget(MealTarget target) =>
      into(mealTargets).insertOnConflictUpdate(MealTargetsCompanion.insert(
        id: Value(_targetRowId),
        dailyCalories: target.dailyCalories,
        syncedAt: Value(target.syncedAt),
      ));

  // --- sync -------------------------------------------------------------

  Future<List<MealEntry>> dirtyEntries() async {
    final rows = await (select(mealEntries)
          ..where((t) => t.syncedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.dateKey)]))
        .get();
    return rows.map(_entryFromRow).toList();
  }

  Future<void> markEntrySynced(String id, DateTime at) =>
      (update(mealEntries)..where((t) => t.id.equals(id)))
          .write(MealEntriesCompanion(syncedAt: Value(at)));

  Future<void> markTargetSynced(DateTime at) =>
      (update(mealTargets)..where((t) => t.id.equals(_targetRowId)))
          .write(MealTargetsCompanion(syncedAt: Value(at)));
}
