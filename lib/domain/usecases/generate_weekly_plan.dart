import '../../core/utils/extensions.dart';
import '../../core/utils/id_gen.dart';
import '../entities/exercise.dart';
import '../entities/plan_template.dart';
import '../entities/training_plan.dart';
import '../entities/workout.dart';
import '../repositories/content_repository.dart';
import '../repositories/plan_repository.dart';
import '../repositories/workout_repository.dart';

/// Generates the weekly plan from bundled templates + the workout library
/// (PLANNING §5.4 — local rules offline; deterministic per week so
/// regeneration never surprises the user within the same week).
class GenerateWeeklyPlan {
  GenerateWeeklyPlan(this._content, this._workouts, this._plan);

  final ContentRepository _content;
  final WorkoutRepository _workouts;
  final PlanRepository _plan;

  Future<TrainingPlan> call({
    required Difficulty level,
    required String goal,
  }) async {
    final templates = await _content.planTemplates();
    final template = _pickTemplate(templates, level, goal);
    final library = await _workouts.library();

    final now = DateTime.now();
    final weekStart = now.startOfWeek;
    final weekIndex = now.startOfWeek.difference(DateTime(2026)).inDays ~/ 7;

    final used = <String>{};
    final days = <PlanDay>[];
    for (final td in template.days) {
      final date = weekStart.add(Duration(days: td.dayOffset));
      if (td.kind == TemplateDayKind.rest ||
          td.categories.isEmpty) {
        days.add(PlanDay(date: date));
        continue;
      }
      final workout = _pickWorkout(
        library,
        td,
        level,
        seed: weekIndex * 7 + td.dayOffset,
        used: used,
      );
      if (workout == null) {
        days.add(PlanDay(date: date));
        continue;
      }
      used.add(workout.id);
      days.add(PlanDay(date: date, sessions: [
        PlanSession(
          id: newId(),
          workoutId: workout.id,
          startTimeMin: td.startMin,
        ),
      ]));
    }

    final generated = TrainingPlan(
      id: newId(),
      weekStart: weekStart,
      days: days,
      source: PlanSource.ai,
      lastUpdated: now,
    );
    await _plan.savePlan(generated);
    return generated;
  }

  PlanTemplate _pickTemplate(
    List<PlanTemplate> templates,
    Difficulty level,
    String goal,
  ) {
    for (final t in templates) {
      if (t.supports(level.name, goal)) return t;
    }
    for (final t in templates) {
      if (t.levels.contains(level.name)) return t;
    }
    for (final t in templates) {
      if (t.goals.contains(goal)) return t;
    }
    return templates.first;
  }

  Workout? _pickWorkout(
    List<Workout> library,
    TemplateDay td,
    Difficulty level, {
    required int seed,
    required Set<String> used,
  }) {
    final candidates = library
        .where((w) => td.categories.contains(w.category.name))
        .toList()
      ..sort((a, b) {
        final la = a.level == level
            ? 0
            : (a.level.index - level.index).abs();
        final lb = b.level == level
            ? 0
            : (b.level.index - level.index).abs();
        if (la != lb) return la.compareTo(lb);
        return a.id.compareTo(b.id);
      });
    if (candidates.isEmpty) return null;

    // Deterministic rotation; skip workouts already scheduled this week.
    for (var i = 0; i < candidates.length; i++) {
      final pick = candidates[(seed + i) % candidates.length];
      if (!used.contains(pick.id)) return pick;
    }
    return candidates[seed % candidates.length];
  }
}
