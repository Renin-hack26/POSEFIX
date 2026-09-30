import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/exercise.dart';
import '../../domain/entities/training_plan.dart';
import '../../domain/entities/workout.dart';
import '../errors/app_exception.dart';
import '../utils/extensions.dart';

/// GROQ-powered weekly plan generation (PLANNING §5.4 — AI-first).
///
/// The [openai/gpt-oss-120b] LLM builds the 7-day plan from the user's
/// level + goal, grounded in the REAL bundled workout library — the prompt
/// feeds every workout id/name/category/level and forbids inventing workouts.
/// The API key is injected at build time (`--dart-define=GROQ_API_KEY` from
/// `secrets/local.env` — never hardcoded, never committed).
///
/// Contract: [generatePlan] returns `null` when GROQ is unavailable (no key,
/// offline, timeout, malformed reply) so [GenerateWeeklyPlan] falls back to
/// the deterministic local templates — onboarding never bricks, and the plan
/// source is labeled honestly (AI generated vs Manual plan).
class GroqPlanService {
  GroqPlanService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'openai/gpt-oss-120b';
  static const String _apiKey = String.fromEnvironment('GROQ_API_KEY');

  static const Duration _timeout = Duration(seconds: 20);

  /// True when this build has a GROQ key baked in.
  bool get isConfigured => _apiKey.isNotEmpty;

  /// One live GROQ plan completion. Returns the parsed 7-day plan, or `null`
  /// when GROQ could not produce a valid plan (caller falls back).
  Future<List<PlanDay>?> generatePlan({
    required Difficulty level,
    required String goal,
    required List<Workout> library,
  }) async {
    if (!isConfigured) return null;
    try {
      final response = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'temperature': 0.4,
              'max_tokens': 2000,
              'reasoning_effort': 'low',
              'messages': [
                {'role': 'system', 'content': _systemPrompt},
                {'role': 'user', 'content': _userPrompt(level, goal, library)},
              ],
            }),
          )
          .timeout(_timeout);
      if (response.statusCode != 200) {
        debugPrint('GROQ plan HTTP ${response.statusCode}');
        return null;
      }
      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final choices = decoded['choices'] as List<dynamic>;
      final content = ((choices.first as Map<String, dynamic>)['message']
          as Map<String, dynamic>)['content'] as String?;
      if (content == null || content.trim().isEmpty) return null;
      return _parseDays(content, library);
    } on AppException {
      return null;
    } catch (e) {
      debugPrint('GROQ plan failed: $e');
      return null;
    }
  }

  /// Strict reply contract — anything off-contract throws (→ fallback).
  List<PlanDay> _parseDays(String content, List<Workout> library) {
    final cleaned = content
        .trim()
        .replaceFirst(RegExp(r'^```(?:json)?'), '')
        .replaceFirst(RegExp(r'```$'), '')
        .trim();
    final decoded = jsonDecode(cleaned);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('plan reply is not an object');
    }
    final rawDays = decoded['days'];
    if (rawDays is! List || rawDays.length != 7) {
      throw const FormatException('plan reply must contain exactly 7 days');
    }

    final byId = {for (final w in library) w.id: w};
    final seenOffsets = <int>{};
    final days = <PlanDay>[];
    for (final raw in rawDays) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('plan day is not an object');
      }
      final offset = (raw['dayOffset'] as num?)?.toInt();
      if (offset == null || offset < 0 || offset > 6 || !seenOffsets.add(offset)) {
        throw const FormatException('plan dayOffset invalid or duplicated');
      }
      final kind = raw['kind'] as String?;
      if (kind == 'rest') {
        days.add(PlanDay(date: _dateFor(offset)));
        continue;
      }
      final workoutId = raw['workoutId'] as String?;
      final workout = workoutId == null ? null : byId[workoutId];
      // The LLM may only pick from the real library — never invent workouts.
      if (workout == null) {
        throw const FormatException('plan workoutId is not in the library');
      }
      days.add(PlanDay(date: _dateFor(offset), sessions: [
        PlanSession(
          id: _newSessionId(),
          workoutId: workout.id,
          startTimeMin:
              (raw['startMin'] as num?)?.toInt() ?? 420,
        ),
      ]));
    }
    if (seenOffsets.length != 7) {
      throw const FormatException('plan must cover all 7 days');
    }
    if (days.every((d) => d.sessions.isEmpty)) {
      throw const FormatException('plan has no workout days');
    }
    return days;
  }

  DateTime _dateFor(int dayOffset) =>
      DateTime.now().startOfWeek.add(Duration(days: dayOffset));

  String _newSessionId() => DateTime.now().microsecondsSinceEpoch.toString();

  static const String _systemPrompt = '''
You are the weekly plan generator of FixPose, an on-device pose detection workout app.
Build a 7-day training plan for the user from ONLY the workout library provided by the caller.
Reply with ONLY a JSON object, no markdown fences, no explanations, no emojis:
{"days":[{"dayOffset":0,"kind":"workout","workoutId":"<id>","startMin":420}]}
Rules:
- Exactly 7 entries; dayOffset runs 0 (Monday) to 6 (Sunday), each exactly once.
- kind is "workout" or "rest". Rest entries have no workoutId and no startMin.
- workoutId MUST be one of the ids from the provided library. Never invent ids.
- Pick a sensible number of workout days for the level (beginner 3-4, intermediate 4-5, advanced 5-6).
- Balance categories across the week, alternate hard and easy days, avoid training the same muscles on consecutive days.
- startMin is the session start time in minutes after midnight (e.g. 420 = 07:00, 1080 = 18:00).
''';

  String _userPrompt(Difficulty level, String goal, List<Workout> library) {
    final buffer = StringBuffer(
        'User level: ${level.name}\nUser goal: $goal\n\nWorkout library:\n');
    for (final w in library) {
      buffer.write(
          '- ${w.id}: ${w.name} (${w.category.name}, ${w.level.name}, '
          '${w.durationMin} min, goal ${w.goal})\n');
    }
    return buffer.toString();
  }
}

/// Plan-generation service provider (shares the DI graph's HTTP resources).
final groqPlanServiceProvider = Provider<GroqPlanService>((ref) {
  return GroqPlanService();
});
