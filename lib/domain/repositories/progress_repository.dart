import '../../domain/entities/body_metric.dart';
import '../../domain/entities/strike_state.dart';

/// Progress data — consistency strike state + body metrics (weight/height).
/// Local-first; both sync to the account (LWW per record).
abstract class ProgressRepository {
  Future<StrikeState?> strike();

  Future<void> saveStrike(StrikeState state);

  /// Newest first, limited.
  Future<List<BodyMetric>> metrics({int limit = 365});

  /// One entry per `dateKey` (overwrites same-day).
  Future<void> addMetric(BodyMetric metric);
}
