/// Ask Veda nutrition feed (audit: the AI nutrition context was untested).
///
/// 1. ONLINE — `VedaRepository.complete` captures the system prompt; it
///    must carry today's logged calories, the daily target and the meal
///    list in the exact `- Nutrition today: …` format the model reads.
/// 2. OFFLINE / session-less — transport throws, no sessions anywhere;
///    the local retrieval fallback must still acknowledge today's intake
///    (`. Your N kcal logged today still counts, keep the meals coming.`).
///
/// Fakes implement every member of the six repository interfaces (Dart
/// `implements` leaves no inherited bodies); members `_buildContext` and
/// `call` don't touch get sensible empty defaults.
library;

import 'package:fixpose/core/utils/extensions.dart';
import 'package:fixpose/domain/entities/body_metric.dart';
import 'package:fixpose/domain/entities/chat_message.dart';
import 'package:fixpose/domain/entities/exercise.dart';
import 'package:fixpose/domain/entities/meal.dart';
import 'package:fixpose/domain/entities/strike_state.dart';
import 'package:fixpose/domain/entities/training_plan.dart';
import 'package:fixpose/domain/entities/workout.dart';
import 'package:fixpose/domain/entities/workout_session.dart';
import 'package:fixpose/domain/repositories/nutrition_repository.dart';
import 'package:fixpose/domain/repositories/plan_repository.dart';
import 'package:fixpose/domain/repositories/progress_repository.dart';
import 'package:fixpose/domain/repositories/session_repository.dart';
import 'package:fixpose/domain/repositories/veda_repository.dart';
import 'package:fixpose/domain/repositories/workout_repository.dart';
import 'package:fixpose/domain/usecases/ask_veda.dart';
import 'package:flutter_test/flutter_test.dart';

/// Transport fake: captures the system prompt + turns, returns a canned
/// reply or throws (offline).
class _FakeVeda implements VedaRepository {
  _FakeVeda({this.reply, this.error});

  final String? reply;
  final Object? error;

  String? lastSystemPrompt;
  List<ChatMessage> lastTurns = const [];
  final saved = <ChatMessage>[];

  @override
  Future<List<ChatMessage>> history() async => const [];

  @override
  Future<void> saveMessage(ChatMessage message) async => saved.add(message);

  @override
  Future<void> clearHistory() async {}

  @override
  Future<String> complete({
    required List<ChatMessage> turns,
    required String systemPrompt,
  }) async {
    lastTurns = turns;
    lastSystemPrompt = systemPrompt;
    if (error != null) throw error!;
    return reply ?? '';
  }
}

class _FakeSessions implements SessionRepository {
  _FakeSessions({this.sessions = const []});

  final List<WorkoutSession> sessions;

  @override
  Future<WorkoutSession?> activeSession() async => null;

  @override
  Future<void> saveActive(WorkoutSession session) async {}

  @override
  Future<void> clearActive() async {}

  @override
  Future<void> completeSession(WorkoutSession session) async {}

  @override
  Future<List<WorkoutSession>> history({int limit = 100}) async =>
      sessions.take(limit).toList();

  @override
  Future<List<WorkoutSession>> sessionsBetween(DateTime from, DateTime to) async =>
      sessions
          .where((s) => !s.startedAt.isBefore(from) && s.startedAt.isBefore(to))
          .toList();
}

class _FakePlan implements PlanRepository {
  // No plan in either test → `_buildContext` reports "no plan generated yet".
  @override
  Future<TrainingPlan?> currentPlan() async => null;

  @override
  Future<void> savePlan(TrainingPlan plan) async {}

  @override
  Future<void> updateSession(PlanSession session) async {}
}

class _FakeProgress implements ProgressRepository {
  // No strike state → strike 0, no last-active gap in the prompt.
  @override
  Future<StrikeState?> strike() async => null;

  @override
  Future<void> saveStrike(StrikeState state) async {}

  @override
  Future<List<BodyMetric>> metrics({int limit = 365}) async => const [];

  @override
  Future<void> addMetric(BodyMetric metric) async {}
}

class _FakeWorkouts implements WorkoutRepository {
  _FakeWorkouts({this.workout});

  final Workout? workout;

  @override
  Future<List<Workout>> library() async => const [];

  @override
  Future<Workout?> byId(String id) async => workout;

  @override
  Future<List<Workout>> suggestions({int limit = 5}) async => const [];
}

class _FakeNutrition implements NutritionRepository {
  _FakeNutrition({this.entries = const [], this.targetValue});

  final List<MealEntry> entries;
  final MealTarget? targetValue;

  @override
  Future<List<FoodItem>> searchFoods(String query) async => const [];

  @override
  Future<List<MealEntry>> entriesFor(String dateKey) async =>
      entries.where((e) => e.dateKey == dateKey).toList();

  @override
  Future<List<MealEntry>> entriesBetween(DateTime from, DateTime to) async =>
      entries;

  @override
  Future<void> addEntry(MealEntry entry) async {}

  @override
  Future<void> removeEntry(String id) async {}

  @override
  Future<MealTarget?> target() async => targetValue;

  @override
  Future<void> saveTarget(MealTarget target) async {}
}

/// One completed session, ~2h ago (inside `sessionsBetween(startOfWeek, now)`
/// and `history(limit: 1)` — the two queries `_buildContext` runs).
WorkoutSession _completedToday() => WorkoutSession(
      id: 's1',
      workoutId: 'w001',
      startedAt: DateTime.now().subtract(const Duration(hours: 3)),
      endedAt: DateTime.now().subtract(const Duration(hours: 2)),
      status: SessionStatus.completed,
      durationSec: 1800,
      totalReps: 120,
    );

const Workout _workout = Workout(
  id: 'w001',
  name: 'Full Body Burn',
  category: WorkoutCategory.fullBody,
  level: Difficulty.beginner,
  goal: 'Move every day',
  durationMin: 20,
  description: 'Short full-body circuit.',
  focusMuscles: [MuscleGroup.fullBody],
  blocks: [],
  demoVideoAsset: 'assets/videos/w001.mp4',
);

/// Today's single logged meal (450 kcal against a 2200 kcal target).
MealEntry _todayEntry() => MealEntry(
      id: 'm1',
      dateKey: DateTime.now().dateKey,
      name: 'Roti & Dal',
      calories: 450,
      mealType: MealType.lunch,
      timeMillis: DateTime.now().millisecondsSinceEpoch,
    );

void main() {
  test('online: system prompt carries logged kcal, target and meals',
      () async {
    final veda = _FakeVeda(reply: 'Canned coach reply');
    final ask = AskVeda(
      veda,
      _FakeSessions(sessions: [_completedToday()]),
      _FakePlan(),
      _FakeProgress(),
      _FakeWorkouts(workout: _workout),
      _FakeNutrition(
        entries: [_todayEntry()],
        targetValue: const MealTarget(dailyCalories: 2200),
      ),
    );

    final reply = await ask('How am I doing today?');

    expect(reply.text, 'Canned coach reply');
    final prompt = veda.lastSystemPrompt;
    expect(prompt, isNotNull, reason: 'complete() must receive a prompt');
    expect(
      prompt,
      contains('- Nutrition today: 450 kcal logged of 2200 kcal target'),
      reason: 'the feed line states today\'s intake against the daily target',
    );
    expect(
      prompt,
      contains('meals: Roti & Dal (450 kcal)'),
      reason: 'meal list is formatted "<name> (<kcal> kcal)"',
    );
    // The user turn + the model reply were both routed through the transport.
    expect(veda.lastTurns, isNotEmpty);
    expect(veda.lastTurns.last.text, 'How am I doing today?');
  });

  test('offline, session-less: local reply still credits today\'s kcal',
      () async {
    final veda = _FakeVeda(error: Exception('offline'));
    final ask = AskVeda(
      veda,
      _FakeSessions(), // zero sessions: history + sessionsBetween both empty
      _FakePlan(),
      _FakeProgress(),
      _FakeWorkouts(),
      _FakeNutrition(
        entries: [_todayEntry()],
        targetValue: const MealTarget(dailyCalories: 2200),
      ),
    );

    final reply = await ask('How many kcal have I eaten?');

    expect(
      reply.text,
      contains('450 kcal logged today still counts'),
      reason: 'session-less fallback must acknowledge the nutrition feed',
    );
    expect(reply.text, contains('keep the meals coming'));
    expect(reply.role, ChatRole.assistant);
    // History is persisted locally even when the transport fails.
    expect(veda.saved.where((m) => m.role == ChatRole.user), hasLength(1));
    expect(veda.saved.where((m) => m.role == ChatRole.assistant), hasLength(1));
  });
}
