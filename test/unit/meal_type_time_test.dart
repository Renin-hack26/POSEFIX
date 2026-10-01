/// Meal-tag auto-derivation by clock time (meal page requirement:
/// breakfast/lunch/dinner/snack determined automatically from the time).
library;

import 'package:fixpose/domain/entities/meal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MealType at(int hour, [int minute = 0]) =>
      MealTypeX.forTime(DateTime(2026, 10, 1, hour, minute));

  test('breakfast window 05:00–10:59', () {
    expect(at(5), MealType.breakfast);
    expect(at(10, 59), MealType.breakfast);
  });

  test('lunch window 11:00–15:59', () {
    expect(at(11), MealType.lunch);
    expect(at(15, 59), MealType.lunch);
  });

  test('dinner window 17:00–21:59', () {
    expect(at(17), MealType.dinner);
    expect(at(21, 59), MealType.dinner);
  });

  test('snack everywhere else (16:00–16:59 and 22:00–04:59)', () {
    expect(at(16), MealType.snack);
    expect(at(16, 59), MealType.snack);
    expect(at(22), MealType.snack);
    expect(at(0), MealType.snack);
    expect(at(4, 59), MealType.snack);
  });

  test('labels round-trip for the chips', () {
    expect(MealType.breakfast.label, 'Breakfast');
    expect(MealType.snack.label, 'Snack');
  });
}
