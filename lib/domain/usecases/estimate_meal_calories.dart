import 'dart:convert';

import '../entities/chat_message.dart';
import '../repositories/veda_repository.dart';

/// Parsed AI estimate for one meal description.
class MealEstimate {
  const MealEstimate({required this.name, required this.calories});

  final String name;
  final int calories;
}

/// AI calorie estimation from a free-text meal description (meal page).
///
/// The model sees only the description + approximate local clock time and
/// must answer with a strict JSON contract; anything off-contract — or an
/// offline/missing-key transport — returns null so the UI falls back to
/// manual calorie entry. The meal is never silently dropped.
class EstimateMealCalories {
  EstimateMealCalories(this._veda);

  final VedaRepository _veda;

  static const String _systemPrompt = '''
You are the nutrition estimator of FixPose, a fitness app. You receive one free-text meal description and its approximate local time. Estimate the TOTAL calories for the whole described amount (not per unit).

Respond with ONLY a JSON object, no markdown, no explanation:
{"name": "<short dish name, max 40 chars>", "calories": <total kcal integer>}

Rules:
- calories must be a positive integer between 1 and 5000.
- Assume standard portion sizes when the quantity is unspecified.
- The name is the dish in title case, without the quantity.''';

  Future<MealEstimate?> call(String description, {DateTime? at}) async {
    final desc = description.trim();
    if (desc.isEmpty) return null;
    final now = at ?? DateTime.now();
    try {
      final raw = await _veda.complete(
        turns: [
          ChatMessage(
            id: 'meal_${now.microsecondsSinceEpoch}',
            role: ChatRole.user,
            text: 'Local time: '
                '${now.hour.toString().padLeft(2, '0')}:'
                '${now.minute.toString().padLeft(2, '0')}\n'
                'Meal description: $desc',
            createdAt: now,
          ),
        ],
        systemPrompt: _systemPrompt,
      );
      return _parse(raw);
    } catch (_) {
      return null; // offline / no key → caller falls back to manual entry
    }
  }

  /// Strict reply contract (mirrors `GroqPlanService._parseDays`): fences
  /// stripped, object decoded, calories validated.
  MealEstimate? _parse(String content) {
    final cleaned = content
        .trim()
        .replaceFirst(RegExp(r'^```(?:json)?'), '')
        .replaceFirst(RegExp(r'```$'), '')
        .trim();
    final decoded = jsonDecode(cleaned);
    if (decoded is! Map<String, dynamic>) return null;
    var name = (decoded['name'] as String?)?.trim();
    final calories = (decoded['calories'] as num?)?.toInt();
    if (name == null || name.isEmpty || calories == null) return null;
    if (name.length > 40) name = name.substring(0, 40).trim();
    if (calories < 1 || calories > 5000) return null;
    return MealEstimate(name: name, calories: calories);
  }
}
