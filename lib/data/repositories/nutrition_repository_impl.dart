import '../../../core/search/library_search.dart';
import '../../../core/utils/extensions.dart';
import '../../../domain/entities/meal.dart';
import '../../../domain/repositories/nutrition_repository.dart';
import '../datasources/content/content_loader.dart';
import '../datasources/local/nutrition_dao.dart';

/// Nutrition — bundled food search + local entries/target (synced).
class NutritionRepositoryImpl implements NutritionRepository {
  NutritionRepositoryImpl(this._content, this._dao);

  final ContentLoader _content;
  final NutritionDao _dao;

  @override
  Future<List<FoodItem>> searchFoods(String query) async {
    final all = await _content.foods();
    if (LibrarySearch.tokenize(query).isEmpty) return all;
    // Multi-token AND + word-prefix (shared normalizer with the workout
    // library search) — "chick br" finds "Chicken Breast".
    return all
        .where((f) => LibrarySearch.matchesText(f.name, query))
        .toList();
  }

  @override
  Future<List<MealEntry>> entriesFor(String dateKey) =>
      _dao.entriesFor(dateKey);

  @override
  Future<List<MealEntry>> entriesBetween(DateTime from, DateTime to) =>
      _dao.entriesBetween(from.dateKey, to.dateKey);

  @override
  Future<void> addEntry(MealEntry entry) => _dao.upsertEntry(entry);

  @override
  Future<void> removeEntry(String id) => _dao.removeEntry(id);

  @override
  Future<MealTarget?> target() => _dao.target();

  @override
  Future<void> saveTarget(MealTarget target) => _dao.saveTarget(target);
}
