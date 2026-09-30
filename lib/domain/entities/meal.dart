/// Nutrition domain — food catalog (bundled), manual entries and the daily
/// calorie target (PLANNING §5.4 minimal scope).
library;

enum MealType { breakfast, lunch, dinner, snack }

extension MealTypeX on MealType {
  String get label => switch (this) {
        MealType.breakfast => 'Breakfast',
        MealType.lunch => 'Lunch',
        MealType.dinner => 'Dinner',
        MealType.snack => 'Snack',
      };
}

/// Bundled food item for manual search/log (calories per [serving]).
class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    required this.calories,
    required this.serving,
  });

  final String id;
  final String name;
  final int calories;
  final String serving;
}

/// One logged entry (manual only — spec minimal scope).
class MealEntry {
  const MealEntry({
    required this.id,
    required this.dateKey,
    required this.name,
    required this.calories,
    required this.mealType,
    this.syncedAt,
  });

  final String id;

  /// `yyyy-MM-dd` local day bucket.
  final String dateKey;
  final String name;
  final int calories;
  final MealType mealType;
  final DateTime? syncedAt;

  MealEntry copyWith({DateTime? syncedAt}) => MealEntry(
        id: id,
        dateKey: dateKey,
        name: name,
        calories: calories,
        mealType: mealType,
        syncedAt: syncedAt ?? this.syncedAt,
      );
}

/// Daily calorie target (account data, editable in Plan/Nutrition).
class MealTarget {
  const MealTarget({required this.dailyCalories, this.syncedAt});

  final int dailyCalories;
  final DateTime? syncedAt;
}
