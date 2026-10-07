/// Plan generation templates — bundled content describing weekly shapes
/// (days per week, category rotation, start times) that `GenerateWeeklyPlan`
/// turns into a concrete `TrainingPlan` for the user's level + goal.
library;

enum TemplateDayKind { workout, rest }

class TemplateDay {
  const TemplateDay({
    required this.dayOffset,
    required this.kind,
    this.categories = const [],
    this.startMin = 420,
  });

  /// 0 = Monday (first day of the plan week).
  final int dayOffset;
  final TemplateDayKind kind;

  /// Workout days pick a library workout matching one of these categories.
  final List<String> categories;

  /// Minutes since midnight (workout days).
  final int startMin;
}

class PlanTemplate {
  const PlanTemplate({
    required this.id,
    required this.levels,
    required this.goals,
    required this.days,
  });

  final String id;

  /// Difficulty levels this template serves (Difficulty.name values).
  final List<String> levels;

  /// Goal keys: fat_loss | muscle_gain | general_fitness.
  final List<String> goals;
  final List<TemplateDay> days;

  bool supports(String level, String goal) =>
      levels.contains(level) && goals.contains(goal);
}
