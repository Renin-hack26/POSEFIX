import '../../../domain/entities/body_metric.dart';
import '../../../domain/entities/strike_state.dart';
import '../../../domain/repositories/progress_repository.dart';
import '../datasources/local/progress_dao.dart';

/// Body metrics + strike state over Drift (synced to the account).
class ProgressRepositoryImpl implements ProgressRepository {
  ProgressRepositoryImpl(this._dao);

  final ProgressDao _dao;

  @override
  Future<StrikeState?> strike() => _dao.strike();

  @override
  Future<void> saveStrike(StrikeState state) => _dao.saveStrike(state);

  @override
  Future<List<BodyMetric>> metrics({int limit = 365}) =>
      _dao.metrics(limit: limit);

  @override
  Future<void> addMetric(BodyMetric metric) => _dao.upsertMetric(metric);
}
