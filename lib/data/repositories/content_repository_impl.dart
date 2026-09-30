import '../../../domain/entities/plan_template.dart';
import '../../../domain/repositories/content_repository.dart';
import '../datasources/content/content_loader.dart';

class ContentRepositoryImpl implements ContentRepository {
  ContentRepositoryImpl(this._loader);

  final ContentLoader _loader;

  @override
  Future<List<String>> tips() => _loader.tips();

  @override
  Future<List<PlanTemplate>> planTemplates() => _loader.planTemplates();
}
