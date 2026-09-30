import '../../domain/entities/training_plan.dart';

/// Current weekly plan — local-first (Drift primary), uploaded to the account
/// by the sync engine (conflict policy: last-writer-wins via `lastUpdated`).
abstract class PlanRepository {
  /// The active plan (null before onboarding generation).
  Future<TrainingPlan?> currentPlan();

  /// Full write — marks the record dirty for the next sync sweep.
  Future<void> savePlan(TrainingPlan plan);

  /// Single-session edit (drag/reschedule/status); bumps `lastUpdated`.
  Future<void> updateSession(PlanSession session);
}
