/// JSON codec for the plan's nested day/session structure (shared by the
/// local DAO and the sync payload).
library;

import 'dart:convert';

import '../../domain/entities/training_plan.dart';

String encodePlanDays(List<PlanDay> days) =>
    jsonEncode(days.map(planDayToMap).toList());

List<PlanDay> decodePlanDays(String source) =>
    (jsonDecode(source) as List<dynamic>)
        .map((d) => planDayFromMap(d as Map<String, dynamic>))
        .toList();

Map<String, dynamic> planDayToMap(PlanDay day) => {
      'dateMs': day.date.millisecondsSinceEpoch,
      'sessions': day.sessions.map(planSessionToMap).toList(),
    };

PlanDay planDayFromMap(Map<String, dynamic> m) => PlanDay(
      date: DateTime.fromMillisecondsSinceEpoch(
          (m['dateMs'] as num).toInt()),
      sessions: ((m['sessions'] as List?) ?? const [])
          .map((s) => planSessionFromMap(s as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> planSessionToMap(PlanSession s) => {
      'id': s.id,
      'workoutId': s.workoutId,
      'startTimeMin': s.startTimeMin,
      'status': s.status.name,
      if (s.roundsOverride != null) 'roundsOverride': s.roundsOverride,
    };

PlanSession planSessionFromMap(Map<String, dynamic> m) => PlanSession(
      id: m['id'] as String,
      workoutId: m['workoutId'] as String,
      startTimeMin: (m['startTimeMin'] as num).toInt(),
      status: PlanSessionStatus.values.byName(m['status'] as String),
      roundsOverride: (m['roundsOverride'] as num?)?.toInt(),
    );
