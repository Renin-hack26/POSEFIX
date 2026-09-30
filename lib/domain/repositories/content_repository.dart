import '../../domain/entities/plan_template.dart';

/// Bundled coaching content that doesn't belong to a single domain repo —
/// rotating tips (Home) and plan templates (plan generation).
abstract class ContentRepository {
  Future<List<String>> tips();

  Future<List<PlanTemplate>> planTemplates();
}
