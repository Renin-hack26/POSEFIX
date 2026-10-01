import '../../core/utils/extensions.dart';
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

  /// Meals logged between [from] and [to] (inclusive local days), newest
  /// first (day desc, then clock time desc). The default walks day buckets —
  /// correct for in-memory fakes; `NutritionRepositoryImpl` overrides it
  /// with a single indexed query.
  Future<List<MealEntry>> entriesBetween(DateTime from, DateTime to) async {
    final out = <MealEntry>[];
    var day = from.startOfDay;
    final end = to.startOfDay;
    while (!day.isAfter(end)) {
      out.addAll(await entriesFor(day.dateKey));
      day = day.add(const Duration(days: 1));
    }
    out.sort((a, b) {
      final cmp = b.dateKey.compareTo(a.dateKey);
      if (cmp != 0) return cmp;
      return (b.timeMillis ?? 0).compareTo(a.timeMillis ?? 0);
    });
    return out;
  }
}
