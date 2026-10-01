/// EndSession use case — the post-workout chain that used to be dead code:
/// a finished session (≥ 1 min) is persisted AND credited to the strike
/// exactly once; a sub-minute session still finalizes but earns nothing
/// ("showing up" means actual work, PLANNING §4.3).
library;

import 'package:fixpose/domain/entities/body_metric.dart';
import 'package:fixpose/domain/entities/strike_state.dart';
import 'package:fixpose/domain/entities/training_plan.dart';
import 'package:fixpose/domain/entities/workout_session.dart';
import 'package:fixpose/domain/repositories/plan_repository.dart';
import 'package:fixpose/domain/repositories/progress_repository.dart';
import 'package:fixpose/domain/repositories/session_repository.dart';
import 'package:fixpose/domain/usecases/end_session.dart';
import 'package:fixpose/engines/strike_engine/strike_engine.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fakes (recording pattern from test/report/progress_report_test.dart)
// ---------------------------------------------------------------------------

class _RecordingSessionRepo implements SessionRepository {
  final List<WorkoutSession> completed = [];

  @override
  Future<WorkoutSession?> activeSession() async => null;

  @override
  Future<void> saveActive(WorkoutSession session) async {}

  @override
  Future<void> clearActive() async {}

  @override
  Future<void> completeSession(WorkoutSession session) async =>
      completed.add(session);

  @override
  Future<List<WorkoutSession>> history({int limit = 100}) async => completed;

  @override
  Future<List<WorkoutSession>> sessionsBetween(DateTime from, DateTime to) async =>
      const [];
}

class _RecordingProgressRepo implements ProgressRepository {
  /// Every state the use case persisted (empty → never trained).
  final List<StrikeState> saved = [];

  @override
  Future<StrikeState?> strike() async => saved.isNotEmpty ? saved.last : null;

  @override
  Future<void> saveStrike(StrikeState state) async => saved.add(state);

  @override
  Future<List<BodyMetric>> metrics({int limit = 365}) async => const [];

  @override
  Future<void> addMetric(BodyMetric metric) async {}
}

class _FakePlanRepo implements PlanRepository {
  @override
  Future<TrainingPlan?> currentPlan() async => null;

  @override
  Future<void> savePlan(TrainingPlan plan) async {}

  @override
  Future<void> updateSession(PlanSession session) async {}
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

WorkoutSession _session({required int durationSec}) => WorkoutSession(
      id: 's1',
      workoutId: 'w1',
      startedAt: DateTime(2026, 10, 1, 7),
      endedAt: DateTime(2026, 10, 1, 7).add(Duration(seconds: durationSec)),
      status: SessionStatus.active,
      durationSec: durationSec,
      totalReps: 40,
      formAccuracyPct: 95,
    );

EndSession _usecase(ProgressRepository progress, SessionRepository sessions) =>
    EndSession(sessions, progress, _FakePlanRepo(), const StrikeEngine());

// ---------------------------------------------------------------------------

void main() {
  test('session ≥ 60s finalizes once and credits the strike exactly once',
      () async {
    final sessions = _RecordingSessionRepo();
    final progress = _RecordingProgressRepo();

    final report = await _usecase(progress, sessions)(_session(durationSec: 120));

    // Persisted exactly once, as a completed session.
    expect(sessions.completed, hasLength(1));
    expect(sessions.completed.single.status, SessionStatus.completed);
    expect(sessions.completed.single.durationSec, 120);

    // One strike write → first day of a streak.
    expect(progress.saved, hasLength(1));
    expect(progress.saved.single.currentStrike, 1);
    expect(progress.saved.single.lastActiveDateKey, isNotEmpty);

    // The post-workout report is built from the finalized session.
    expect(report.sessionId, 's1');
    expect(report.durationSec, 120);
  });

  test('same-day follow-up session does not double-count the strike',
      () async {
    final sessions = _RecordingSessionRepo();
    final progress = _RecordingProgressRepo();

    final usecase = _usecase(progress, sessions);
    await usecase(_session(durationSec: 90));
    await usecase(_session(durationSec: 90));

    // Both sessions land in history, but the strike is written only once.
    expect(sessions.completed, hasLength(2));
    expect(progress.saved, hasLength(1));
    expect(progress.saved.single.currentStrike, 1);
  });

  test('session < 60s still finalizes but earns no credit', () async {
    final sessions = _RecordingSessionRepo();
    final progress = _RecordingProgressRepo();

    final report = await _usecase(progress, sessions)(_session(durationSec: 59));

    expect(sessions.completed, hasLength(1));
    expect(report.durationSec, 59);
    expect(progress.saved, isEmpty,
        reason: 'a sub-minute session must not touch the strike');
  });
}
