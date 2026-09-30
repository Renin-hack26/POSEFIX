/// Entity ⇄ Supabase row payloads (snake_case columns) for the account-sync
/// tables. Server `updated_at` (set by DB trigger) becomes the entity's
/// `syncedAt` on download — non-null `syncedAt` locally = "matches server".
library;

import '../../domain/entities/body_metric.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/meal.dart';
import '../../domain/entities/strike_state.dart';
import '../../domain/entities/training_plan.dart';
import '../../domain/entities/workout_session.dart';
import '../mappers/plan_json.dart';
import '../mappers/session_json.dart';

DateTime? _updated(Map<String, dynamic> r) {
  final v = r['updated_at'];
  return v == null ? null : DateTime.parse(v as String).toLocal();
}

String? _iso(DateTime? dt) => dt?.toUtc().toIso8601String();

// --- workout_sessions ----------------------------------------------------

Map<String, dynamic> sessionToServer(WorkoutSession s, String userId) => {
      'id': s.id,
      'user_id': userId,
      'workout_id': s.workoutId,
      'plan_session_id': s.planSessionId,
      'started_at': _iso(s.startedAt),
      'ended_at': _iso(s.endedAt),
      'status': s.status.name,
      'exercises': s.exercises.map(exerciseToMap).toList(),
      'rest': s.restDurationsSec,
      'paused':
          s.pausedState == null ? null : pausedToMap(s.pausedState!),
      'duration_sec': s.durationSec,
      'total_reps': s.totalReps,
      'avg_cadence_rpm': s.avgCadenceRpm,
      'form_accuracy_pct': s.formAccuracyPct,
    };

WorkoutSession sessionFromServer(Map<String, dynamic> r) => WorkoutSession(
      id: r['id'] as String,
      workoutId: r['workout_id'] as String,
      planSessionId: r['plan_session_id'] as String?,
      startedAt: DateTime.parse(r['started_at'] as String).toLocal(),
      endedAt: r['ended_at'] == null
          ? null
          : DateTime.parse(r['ended_at'] as String).toLocal(),
      status: SessionStatus.values.byName(r['status'] as String),
      exercises: ((r['exercises'] as List?) ?? const [])
          .map((e) => exerciseFromMap(e as Map<String, dynamic>))
          .toList(),
      restDurationsSec:
          ((r['rest'] as List?) ?? const []).cast<double>(),
      pausedState: r['paused'] == null
          ? null
          : pausedFromMap(r['paused'] as Map<String, dynamic>),
      durationSec: (r['duration_sec'] as num?)?.toInt() ?? 0,
      totalReps: (r['total_reps'] as num?)?.toInt() ?? 0,
      avgCadenceRpm: (r['avg_cadence_rpm'] as num?)?.toDouble() ?? 0,
      formAccuracyPct: (r['form_accuracy_pct'] as num?)?.toDouble() ?? 0,
      syncedAt: _updated(r),
    );

// --- training_plans ------------------------------------------------------

Map<String, dynamic> planToServer(TrainingPlan p, String userId) => {
      'id': p.id,
      'user_id': userId,
      'week_start': _iso(p.weekStart),
      'source': p.source.name,
      'days': p.days.map(planDayToMap).toList(),
      'last_updated': _iso(p.lastUpdated),
    };

TrainingPlan planFromServer(Map<String, dynamic> r) => TrainingPlan(
      id: r['id'] as String,
      weekStart: DateTime.parse(r['week_start'] as String).toLocal(),
      source: PlanSource.values.byName(r['source'] as String),
      days: ((r['days'] as List?) ?? const [])
          .map((d) => planDayFromMap(d as Map<String, dynamic>))
          .toList(),
      lastUpdated: DateTime.parse(r['last_updated'] as String).toLocal(),
      syncedAt: _updated(r),
    );

// --- meal_entries --------------------------------------------------------

Map<String, dynamic> mealEntryToServer(MealEntry e, String userId) => {
      'id': e.id,
      'user_id': userId,
      'date_key': e.dateKey,
      'name': e.name,
      'calories': e.calories,
      'meal_type': e.mealType.name,
    };

MealEntry mealEntryFromServer(Map<String, dynamic> r) => MealEntry(
      id: r['id'] as String,
      dateKey: r['date_key'] as String,
      name: r['name'] as String,
      calories: (r['calories'] as num).toInt(),
      mealType: MealType.values.byName(r['meal_type'] as String),
      syncedAt: _updated(r),
    );

// --- meal_targets (one row per user) -------------------------------------

Map<String, dynamic> mealTargetToServer(MealTarget t, String userId) => {
      'user_id': userId,
      'daily_calories': t.dailyCalories,
    };

MealTarget mealTargetFromServer(Map<String, dynamic> r) => MealTarget(
      dailyCalories: (r['daily_calories'] as num).toInt(),
      syncedAt: _updated(r),
    );

// --- body_metrics (one row per day per user) -----------------------------

Map<String, dynamic> metricToServer(BodyMetric m, String userId) => {
      'user_id': userId,
      'date_key': m.dateKey,
      'weight_kg': m.weightKg,
      'height_cm': m.heightCm,
      'notes': m.notes,
    };

BodyMetric metricFromServer(Map<String, dynamic> r) => BodyMetric(
      dateKey: r['date_key'] as String,
      weightKg: (r['weight_kg'] as num).toDouble(),
      heightCm: (r['height_cm'] as num?)?.toDouble(),
      notes: r['notes'] as String?,
      syncedAt: _updated(r),
    );

// --- strike_states (one row per user) ------------------------------------

Map<String, dynamic> strikeToServer(StrikeState s, String userId) => {
      'user_id': userId,
      'current_strike': s.currentStrike,
      'longest_strike': s.longestStrike,
      'last_active_date_key': s.lastActiveDateKey,
      'unlocked_tiers': s.unlockedTiers,
    };

StrikeState strikeFromServer(Map<String, dynamic> r) => StrikeState(
      currentStrike: (r['current_strike'] as num).toInt(),
      longestStrike: (r['longest_strike'] as num).toInt(),
      lastActiveDateKey: r['last_active_date_key'] as String,
      unlockedTiers: ((r['unlocked_tiers'] as List?) ?? const [])
          .map((v) => (v as num).toInt())
          .toList(),
      syncedAt: _updated(r),
    );

// --- chat_messages -------------------------------------------------------

Map<String, dynamic> chatToServer(ChatMessage m, String userId) => {
      'id': m.id,
      'user_id': userId,
      'role': m.role.name,
      'content': m.text,
      'created_at': _iso(m.createdAt),
      'context_ref': m.contextRef,
    };

ChatMessage chatFromServer(Map<String, dynamic> r) => ChatMessage(
      id: r['id'] as String,
      role: ChatRole.values.byName(r['role'] as String),
      text: r['content'] as String,
      createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
      contextRef: r['context_ref'] as String?,
      syncedAt: _updated(r),
    );
