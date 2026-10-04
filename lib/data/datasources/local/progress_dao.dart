import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../../core/storage/app_database.dart';
import '../../../domain/entities/body_metric.dart';
import '../../../domain/entities/strike_state.dart';

part 'progress_dao.g.dart';

/// Body metrics (per-day rows) + strike state (single row).
@DriftAccessor(tables: [BodyMetrics, StrikeStates])
class ProgressDao extends DatabaseAccessor<AppDatabase>
    with _$ProgressDaoMixin {
  ProgressDao(super.db);

  // --- strike ------------------------------------------------------------

  static const int _strikeRowId = 1;

  Future<StrikeState?> strike() async {
    final row = await (select(strikeStates)
          ..where((t) => t.id.equals(_strikeRowId)))
        .getSingleOrNull();
    if (row == null) return null;
    try {
      return _strikeFromRow(
        row.currentStrike,
        row.longestStrike,
        row.lastActiveDateKey,
        row.unlockedTiersJson,
        row.syncedAt,
      );
    } catch (e) {
      // A corrupt tiers payload must not kill the strike badge — degrade
      // to "no strike" (self-heals on the next saveStrike).
      debugPrint('progress: unreadable strike row ($e)');
      return null;
    }
  }

  StrikeState _strikeFromRow(
    int currentStrike,
    int longestStrike,
    String lastActiveDateKey,
    String unlockedTiersJson,
    DateTime? syncedAt,
  ) {
    final tiers = ((jsonDecode(unlockedTiersJson) as List<dynamic>)
            .map((v) => (v as num).toInt()))
        .toList();
    return StrikeState(
      currentStrike: currentStrike,
      longestStrike: longestStrike,
      lastActiveDateKey: lastActiveDateKey,
      unlockedTiers: tiers,
      syncedAt: syncedAt,
    );
  }

  Future<void> saveStrike(StrikeState state) =>
      into(strikeStates).insertOnConflictUpdate(StrikeStatesCompanion.insert(
        id: Value(_strikeRowId),
        currentStrike: Value(state.currentStrike),
        longestStrike: Value(state.longestStrike),
        lastActiveDateKey: state.lastActiveDateKey,
        unlockedTiersJson: Value(jsonEncode(state.unlockedTiers)),
        syncedAt: Value(state.syncedAt),
      ));

  // --- metrics -----------------------------------------------------------

  Future<List<BodyMetric>> metrics({int limit = 365}) async {
    final rows = await (select(bodyMetrics)
          ..orderBy([(t) => OrderingTerm.desc(t.dateKey)])
          ..limit(limit))
        .get();
    return rows
        .map((r) => BodyMetric(
              dateKey: r.dateKey,
              weightKg: r.weightKg,
              heightCm: r.heightCm,
              notes: r.notes,
              syncedAt: r.syncedAt,
            ))
        .toList();
  }

  Future<void> upsertMetric(BodyMetric metric) =>
      into(bodyMetrics).insertOnConflictUpdate(BodyMetricsCompanion.insert(
        dateKey: metric.dateKey,
        weightKg: metric.weightKg,
        heightCm: Value(metric.heightCm),
        notes: Value(metric.notes),
        syncedAt: Value(metric.syncedAt),
      ));

  /// Merge lookup for the sync engine.
  Future<BodyMetric?> metricById(String dateKey) async {
    final row = await (select(bodyMetrics)
          ..where((t) => t.dateKey.equals(dateKey)))
        .getSingleOrNull();
    if (row == null) return null;
    return BodyMetric(
      dateKey: row.dateKey,
      weightKg: row.weightKg,
      heightCm: row.heightCm,
      notes: row.notes,
      syncedAt: row.syncedAt,
    );
  }

  // --- sync -------------------------------------------------------------

  Future<List<BodyMetric>> dirtyMetrics() async {
    final rows = await (select(bodyMetrics)
          ..where((t) => t.syncedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.dateKey)]))
        .get();
    return rows
        .map((r) => BodyMetric(
              dateKey: r.dateKey,
              weightKg: r.weightKg,
              heightCm: r.heightCm,
              notes: r.notes,
              syncedAt: r.syncedAt,
            ))
        .toList();
  }

  Future<void> markMetricSynced(String dateKey, DateTime at) =>
      (update(bodyMetrics)
            ..where((t) => t.dateKey.equals(dateKey) & t.syncedAt.isNull()))
          .write(BodyMetricsCompanion(syncedAt: Value(at)));

  Future<StrikeState?> dirtyStrike() async {
    final row = await (select(strikeStates)
          ..where((t) => t.syncedAt.isNull() & t.id.equals(_strikeRowId)))
        .getSingleOrNull();
    if (row == null) return null;
    try {
      return _strikeFromRow(
        row.currentStrike,
        row.longestStrike,
        row.lastActiveDateKey,
        row.unlockedTiersJson,
        row.syncedAt,
      );
    } catch (e) {
      // Skips this sweep's strike upload; retries (or self-heals via
      // saveStrike) instead of wedging the pass.
      debugPrint('progress: unreadable dirty strike row ($e)');
      return null;
    }
  }

  Future<void> markStrikeSynced(DateTime at) =>
      (update(strikeStates)
            ..where((t) => t.id.equals(_strikeRowId) & t.syncedAt.isNull()))
          .write(StrikeStatesCompanion(syncedAt: Value(at)));
}
