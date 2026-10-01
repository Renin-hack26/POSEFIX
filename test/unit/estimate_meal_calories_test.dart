/// AI calorie estimation contract: JSON/fenced parsing, validation limits,
/// offline fallback — the model must never silently guess.
library;

import 'package:fixpose/domain/entities/chat_message.dart';
import 'package:fixpose/domain/repositories/veda_repository.dart';
import 'package:fixpose/domain/usecases/estimate_meal_calories.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeVeda implements VedaRepository {
  _FakeVeda({this.reply, this.error});

  final String? reply;
  final Object? error;
  String? lastText;

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
    lastText = turns.map((t) => t.text).join('\n');
    if (error != null) throw error!;
    return reply ?? '';
  }
}

void main() {
  test('parses a plain JSON reply', () async {
    final usecase = EstimateMealCalories(
        _FakeVeda(reply: '{"name": "Roti & Dal", "calories": 450}'));
    final est =
        await usecase('2 rotis and dal', at: DateTime(2026, 10, 1, 8));
    expect(est, isNotNull);
    expect(est!.name, 'Roti & Dal');
    expect(est.calories, 450);
  });

  test('parses a ```json fenced reply', () async {
    final usecase = EstimateMealCalories(
        _FakeVeda(reply: '```json\n{"name": "Oats", "calories": 320}\n```'));
    final est = await usecase('a bowl of oats');
    expect(est?.name, 'Oats');
    expect(est?.calories, 320);
  });

  test('truncates a >40-char model name at 40 (JSON contract, max 40)',
      () async {
    // Dart has no string repeat operator → build the 60-char name by hand.
    final longName = List.filled(60, 'A').join();
    expect(longName, hasLength(60));
    final usecase = EstimateMealCalories(
        _FakeVeda(reply: '{"name": "$longName", "calories": 450}'));
    final est = await usecase('a very long dish name');
    expect(est, isNotNull, reason: 'the name is truncated, not rejected');
    expect(est!.name.length, 40,
        reason: 'the contract caps the dish name at 40 chars');
    expect(est.name, longName.substring(0, 40));
    expect(est.calories, 450, reason: 'calories survive the truncation');
  });

  test('rejects off-contract replies', () async {
    for (final reply in [
      'I think around 500 calories',
      '{"name": "", "calories": 100}',
      '{"calories": 100}',
      '{"name": "Cake", "calories": 0}',
      '{"name": "Cake", "calories": 99999}',
      '{"name": "Cake", "calories": "lots"}',
      '[1,2,3]',
    ]) {
      final usecase = EstimateMealCalories(_FakeVeda(reply: reply));
      expect(await usecase('cake'), isNull, reason: 'reply: $reply');
    }
  });

  test('offline / error → null (UI falls back to manual entry)', () async {
    final usecase =
        EstimateMealCalories(_FakeVeda(error: Exception('offline')));
    expect(await usecase('2 rotis and dal'), isNull);
  });

  test('empty description short-circuits without a transport call', () async {
    final veda = _FakeVeda(reply: '{}');
    final usecase = EstimateMealCalories(veda);
    expect(await usecase('   '), isNull);
    expect(veda.lastText, isNull);
  });

  test('sends the description with the local clock time', () async {
    final veda = _FakeVeda(reply: '{"name": "Idli", "calories": 180}');
    await EstimateMealCalories(veda)(
        '2 idli sambar', at: DateTime(2026, 10, 1, 7, 5));
    expect(veda.lastText, contains('07:05'));
    expect(veda.lastText, contains('2 idli sambar'));
  });
}
