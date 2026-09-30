import '../../domain/entities/meal.dart';

/// Nutrition — bundled food catalog (search), manual entries and the daily
/// calorie target. Entries/target sync to the account (LWW per record).
abstract class NutritionRepository {
  /// Bundled food list filtered by [query] (empty → full list).
  Future<List<FoodItem>> searchFoods(String query);

  Future<List<MealEntry>> entriesFor(String dateKey);

  Future<void> addEntry(MealEntry entry);

  Future<void> removeEntry(String id);

  Future<MealTarget?> target();

  Future<void> saveTarget(MealTarget target);
}
