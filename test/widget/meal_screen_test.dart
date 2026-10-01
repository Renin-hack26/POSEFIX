/// Meal page flows: AI estimate → prefill, offline fallback to manual
/// entry, clock-derived meal tag, save → entry with time + tag.
library;

import 'package:fixpose/core/di/app_dependencies.dart';
import 'package:fixpose/core/theme/app_theme.dart';
import 'package:fixpose/core/utils/extensions.dart';
import 'package:fixpose/domain/entities/chat_message.dart';
import 'package:fixpose/domain/entities/meal.dart';
import 'package:fixpose/domain/repositories/nutrition_repository.dart';
import 'package:fixpose/domain/repositories/veda_repository.dart';
import 'package:fixpose/domain/usecases/estimate_meal_calories.dart';
import 'package:fixpose/presentation/nutrition/meal_screen.dart';
import 'package:fixpose/presentation/shared/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNutritionRepo implements NutritionRepository {
  _FakeNutritionRepo({
    MealTarget? targetValue = const MealTarget(dailyCalories: 2000),
  }) : _target = targetValue;

  final entries = <MealEntry>[];

  /// Configurable target the card renders (null → "Set daily calorie
  /// target" row); [saveTarget] overwrites it like the real store.
  MealTarget? _target;

  /// Last target written by the UI — asserted by the dialog-flow test.
  MealTarget? savedTarget;

  @override
  Future<List<FoodItem>> searchFoods(String query) async => [];

  @override
  Future<List<MealEntry>> entriesFor(String dateKey) async =>
      entries.where((e) => e.dateKey == dateKey).toList();

  @override
  Future<List<MealEntry>> entriesBetween(DateTime from, DateTime to) async =>
      entries;

  @override
  Future<void> addEntry(MealEntry entry) async => entries.add(entry);

  @override
  Future<void> removeEntry(String id) async =>
      entries.removeWhere((e) => e.id == id);

  @override
  Future<MealTarget?> target() async => _target;

  @override
  Future<void> saveTarget(MealTarget target) async {
    savedTarget = target;
    _target = target;
  }
}

class _FakeVeda implements VedaRepository {
  _FakeVeda({this.reply, this.error});

  final String? reply;
  final Object? error;

  @override
  Future<List<ChatMessage>> history() async => const [];

  @override
  Future<void> saveMessage(ChatMessage message) async {}

  @override
  Future<void> clearHistory() async {}

  @override
  Future<String> complete({
    required List<ChatMessage> turns,
    required String systemPrompt,
  }) async {
    if (error != null) throw error!;
    return reply ?? '';
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required NutritionRepository repo,
  required VedaRepository veda,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        nutritionRepositoryProvider.overrideWithValue(repo),
        estimateMealCaloriesProvider
            .overrideWithValue(EstimateMealCalories(veda)),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: [AppPalette.dark]),
        home: const MealScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('auto-selects the meal tag from the clock', (tester) async {
    await _pump(
      tester,
      repo: _FakeNutritionRepo(),
      veda: _FakeVeda(reply: '{}'),
    );

    final chips = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .toList();
    expect(chips, hasLength(4));
    final selected = chips.where((c) => c.selected).toList();
    expect(selected, hasLength(1));
    final expected = MealTypeX.forTime(DateTime.now()).label;
    expect(
      (selected.first.label as Text).data,
      expected,
      reason: 'the clock decides the initial tag',
    );
  });

  testWidgets('AI estimate prefills name and calories', (tester) async {
    await _pump(
      tester,
      repo: _FakeNutritionRepo(),
      veda: _FakeVeda(
          reply: '{"name": "Roti & Dal", "calories": 450}'),
    );

    await tester.enterText(find.byType(TextField).at(0), '2 rotis and dal');
    await tester.pump();
    await tester.tap(find.text('Estimate calories with AI'));
    await tester.pumpAndSettle();

    expect(find.text('450 kcal'), findsOneWidget); // result tile
    expect(find.widgetWithText(TextField, 'Roti & Dal'), findsOneWidget);
    expect(find.widgetWithText(TextField, '450'), findsOneWidget);
  });

  testWidgets('offline estimate shows a fallback message (manual entry)',
      (tester) async {
    await _pump(
      tester,
      repo: _FakeNutritionRepo(),
      veda: _FakeVeda(error: Exception('offline')),
    );

    await tester.enterText(find.byType(TextField).at(0), '2 rotis and dal');
    await tester.pump();
    await tester.tap(find.text('Estimate calories with AI'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('AI estimate unavailable'),
      findsOneWidget,
    );
    // Manual entry still possible: name + kcal fields are right there.
    expect(find.widgetWithText(TextField, 'Meal name'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'kcal'), findsOneWidget);
  });

  testWidgets('save writes the entry with time, tag and calories',
      (tester) async {
    final repo = _FakeNutritionRepo();
    await _pump(
      tester,
      repo: repo,
      veda: _FakeVeda(reply: '{"name": "Roti & Dal", "calories": 450}'),
    );

    await tester.enterText(find.byType(TextField).at(0), '2 rotis and dal');
    await tester.pump();
    await tester.tap(find.text('Estimate calories with AI'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save meal'));
    await tester.pumpAndSettle();

    expect(repo.entries, hasLength(1));
    final saved = repo.entries.single;
    expect(saved.name, 'Roti & Dal');
    expect(saved.calories, 450);
    expect(saved.timeMillis, isNotNull);
    expect(saved.time, isNotNull);
    // Tag equals the clock-derived one for the chosen time.
    expect(saved.mealType, MealTypeX.forTime(saved.time!));
    expect(saved.dateKey, saved.time!.dateKey);

    // Confirmation + the form resets for the next entry — the saved meal
    // now appears once, in "Today's meals".
    expect(find.textContaining('Meal logged'), findsOneWidget);
    expect(find.text('2 rotis and dal'), findsNothing); // description cleared

    // The "Today's meals" card starts below the 800px-tall test viewport,
    // so the ListView hasn't built it yet — scroll it into view.
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Roti & Dal'), findsOneWidget); // list row, not the field
    expect(find.text('450 kcal'), findsOneWidget); // row's calorie chip
  });

  testWidgets('manual entry works without any AI call', (tester) async {
    final repo = _FakeNutritionRepo();
    await _pump(tester, repo: repo, veda: _FakeVeda(error: Exception('no')));

    await tester.enterText(find.byType(TextField).at(1), 'Chai');
    await tester.enterText(find.byType(TextField).at(2), '90');
    await tester.pump();
    await tester.tap(find.text('Save meal'));
    await tester.pumpAndSettle();

    expect(repo.entries, hasLength(1));
    expect(repo.entries.single.name, 'Chai');
    expect(repo.entries.single.calories, 90);
  });

  testWidgets('null target → "Set daily calorie target" row, no "/ 2000"',
      (tester) async {
    await _pump(
      tester,
      repo: _FakeNutritionRepo(targetValue: null),
      veda: _FakeVeda(reply: '{}'),
    );

    expect(find.text('Set daily calorie target'), findsOneWidget);
    expect(find.text('Set'), findsOneWidget); // trailing action
    expect(
      find.textContaining('kcal logged'),
      findsOneWidget,
      reason: 'card still reports intake without a target denominator',
    );
    expect(find.textContaining('/ 2000'), findsNothing);
    expect(find.textContaining('Target 2000 kcal'), findsNothing);
  });

  testWidgets('target dialog saves 2200 → repository + card reload',
      (tester) async {
    final repo = _FakeNutritionRepo(targetValue: null);
    await _pump(tester, repo: repo, veda: _FakeVeda(reply: '{}'));

    await tester.tap(find.text('Set daily calorie target'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Daily calorie target'), findsOneWidget);
    // Only the dialog's field — the page has 3 TextFields of its own.
    final dialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    expect(dialogField, findsOneWidget);
    await tester.enterText(dialogField, '2200');
    // Exact 'Save' → the dialog button (the page's says 'Save meal').
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.savedTarget?.dailyCalories, 2200,
        reason: 'saveTarget received the parsed dialog value');
    expect(find.textContaining('/ 2200 kcal'), findsOneWidget,
        reason: 'the Today card reloaded with the new denominator');
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Save meal stays disabled until name/description AND kcal',
      (tester) async {
    await _pump(
      tester,
      repo: _FakeNutritionRepo(),
      veda: _FakeVeda(error: Exception('no')),
    );

    PrimaryButton saveButton() => tester.widget<PrimaryButton>(
          find.widgetWithText(PrimaryButton, 'Save meal'),
        );

    // Description only (no name, no kcal): the old operator-precedence bug
    // let a description alone enable Save — it must stay disabled.
    await tester.enterText(find.byType(TextField).at(0), 'just a description');
    await tester.pump();
    expect(saveButton().onPressed, isNull,
        reason: 'a description without calories must not enable Save');

    // Valid kcal alongside the description → enabled (hasName && 1..5000).
    await tester.enterText(find.byType(TextField).at(2), '90');
    await tester.pump();
    expect(saveButton().onPressed, isNotNull,
        reason: 'name-or-description + 1..5000 kcal → Save enabled');
  });
}
