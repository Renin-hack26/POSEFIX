/// Nutrition domain — food catalog (bundled), logged entries and the daily
/// calorie target (PLANNING §5.4 minimal scope + meal/log pages).
library;

enum MealType { breakfast, lunch, dinner, snack }

extension MealTypeX on MealType {
  String get label => switch (this) {
        MealType.breakfast => 'Breakfast',
        MealType.lunch => 'Lunch',
        MealType.dinner => 'Dinner',
        MealType.snack => 'Snack',
      };

  /// Auto meal tag from the clock — the meal page pre-selects this and the
  /// user can override. Windows: breakfast 05–10, lunch 11–15, dinner
  /// 17–21, everything else (16:00–16:59 and 22:00–04:59) = snack.
  static MealType forTime(DateTime t) {
    final h = t.hour;
    if (h >= 5 && h < 11) return MealType.breakfast;
    if (h >= 11 && h < 16) return MealType.lunch;
    if (h >= 17 && h < 22) return MealType.dinner;
    return MealType.snack;
  }
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

/// One logged entry — typed at the meal page (manual or AI-estimated).
class MealEntry {
  const MealEntry({
    required this.id,
    required this.dateKey,
    required this.name,
    required this.calories,
    required this.mealType,
    this.timeMillis,
    this.syncedAt,
  });

  final String id;

  /// `yyyy-MM-dd` local day bucket.
  final String dateKey;
  final String name;
  final int calories;
  final MealType mealType;

  /// Meal clock time as epoch millis — **device-local** (drives the log
  /// ordering and the auto tag; not uploaded to the account mirror).
  /// NULL on rows logged before schema v2.
  final int? timeMillis;
  final DateTime? syncedAt;

  /// Parsed [timeMillis] for display.
  DateTime? get time => timeMillis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(timeMillis!);

  MealEntry copyWith({DateTime? syncedAt, int? timeMillis}) => MealEntry(
        id: id,
        dateKey: dateKey,
        name: name,
        calories: calories,
        mealType: mealType,
        timeMillis: timeMillis ?? this.timeMillis,
        syncedAt: syncedAt ?? this.syncedAt,
      );
}

/// Daily calorie target (account data, editable in Plan/Nutrition).
class MealTarget {
  const MealTarget({required this.dailyCalories, this.syncedAt});

  final int dailyCalories;
  final DateTime? syncedAt;
}
