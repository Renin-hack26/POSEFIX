import 'package:drift/native.dart';
import 'package:fixpose/core/groq/groq_plan_service.dart';
import 'package:fixpose/core/storage/app_database.dart';
import 'package:fixpose/data/datasources/content/content_loader.dart';
import 'package:fixpose/data/datasources/local/plan_dao.dart';
import 'package:fixpose/data/datasources/local/session_dao.dart';
import 'package:fixpose/data/repositories/content_repository_impl.dart';
import 'package:fixpose/data/repositories/plan_repository_impl.dart';
import 'package:fixpose/data/repositories/workout_repository_impl.dart';
import 'package:fixpose/domain/entities/exercise.dart';
import 'package:fixpose/domain/usecases/generate_weekly_plan.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reproduces the onboarding `_generate()` chain exactly as it runs on
/// device (keyless build → GROQ skipped → local-template fallback).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('trace: full plan generation chain (asset load + DB + use case)',
      () async {
    final loader = ContentLoader();
    final templates = await loader.planTemplates();
    // ignore: avoid_print
    print('TRACE templates=${templates.length}');
    final workouts = await loader.workouts();
    // ignore: avoid_print
    print('TRACE workouts=${workouts.length}');

    final db = AppDatabase(NativeDatabase.memory());
    final planRepo = PlanRepositoryImpl(PlanDao(db));
    final gen = GenerateWeeklyPlan(
      ContentRepositoryImpl(loader),
      WorkoutRepositoryImpl(loader, SessionDao(db)),
      planRepo,
      GroqPlanService(),
    );

    for (final level in Difficulty.values) {
      for (final goal in ['fat_loss', 'muscle_gain', 'general_fitness']) {
        final plan = await gen(level: level, goal: goal);
        // ignore: avoid_print
        print('TRACE ok level=${level.name} goal=$goal source=${plan.source.name} '
            'days=${plan.days.length} '
            'withSessions=${plan.days.where((d) => d.sessions.isNotEmpty).length}');
      }
    }

    final current = await planRepo.currentPlan();
    // ignore: avoid_print
    print('TRACE currentPlan null=${current == null}');
    await db.close();
  });
}
