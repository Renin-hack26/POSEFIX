// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nutrition_dao.dart';

// ignore_for_file: type=lint
mixin _$NutritionDaoMixin on DatabaseAccessor<AppDatabase> {
  $MealEntriesTable get mealEntries => attachedDatabase.mealEntries;
  $MealTargetsTable get mealTargets => attachedDatabase.mealTargets;
  NutritionDaoManager get managers => NutritionDaoManager(this);
}

class NutritionDaoManager {
  final _$NutritionDaoMixin _db;
  NutritionDaoManager(this._db);
  $$MealEntriesTableTableManager get mealEntries =>
      $$MealEntriesTableTableManager(_db.attachedDatabase, _db.mealEntries);
  $$MealTargetsTableTableManager get mealTargets =>
      $$MealTargetsTableTableManager(_db.attachedDatabase, _db.mealTargets);
}
