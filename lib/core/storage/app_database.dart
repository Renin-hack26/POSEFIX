import 'package:drift/drift.dart';

import '../../data/datasources/local/chat_dao.dart';
import '../../data/datasources/local/exercise_dao.dart';
import '../../data/datasources/local/nutrition_dao.dart';
import '../../data/datasources/local/plan_dao.dart';
import '../../data/datasources/local/progress_dao.dart';
import '../../data/datasources/local/session_dao.dart';
import 'tables.dart';

export 'tables.dart';

part 'app_database.g.dart';

/// FixPose local database — the primary store (offline-first; the server is
/// only an account mirror driven by the sync engine).
@DriftDatabase(tables: [
  WorkoutSessions,
  TrainingPlans,
  MealEntries,
  MealTargets,
  BodyMetrics,
  StrikeStates,
  ChatMessages,
  ExerciseProgress,
], daos: [
  SessionDao,
  PlanDao,
  NutritionDao,
  ProgressDao,
  ChatDao,
  ExerciseDao,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v1.1.11 (schema v2): the meal log gained a device-local
          // time-of-day (auto meal tag + log page ordering).
          if (from < 2) {
            await m.addColumn(mealEntries, mealEntries.timeMillis);
          }
        },
      );

  /// Wipes account data on sign-out / account switch (privacy boundary —
  /// bundled content is unaffected because it never lives in Drift).
  Future<void> wipeUserTables() => transaction(() async {
        await delete(workoutSessions).go();
        await delete(trainingPlans).go();
        await delete(mealEntries).go();
        await delete(mealTargets).go();
        await delete(bodyMetrics).go();
        await delete(strikeStates).go();
        await delete(chatMessages).go();
      });
}
