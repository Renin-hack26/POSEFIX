import '../../core/utils/extensions.dart';
import '../../domain/entities/strike_state.dart';

/// STRIKE_ENGINE — continuous-day strike + badge tiers (PLANNING §4.3).
///
/// Pure, time-injected logic → unit-testable. Persistence happens in the
/// call sites (`EndSession`, `GetStrikeState`).
///
/// Rules (documented decision):
///  * a day counts when a session (completed or ended-early) finishes that day
///  * consecutive-day → +1; gap ≥ 2 days → reset to 1; same day → unchanged
///  * read-time rollover: streak shows 0 once `lastActive` is before yesterday
///  * badge tiers (3/7/14/30/100) unlock at thresholds and are never revoked
///  * form-mastery badge (`formMasteryBadgeId`) unlocks at ≥90% form session
class StrikeEngine {
  const StrikeEngine();

  StrikeState get initial => const StrikeState(
        currentStrike: 0,
        longestStrike: 0,
        lastActiveDateKey: '',
        unlockedTiers: [],
      );

  /// Call when a session ends with at least one minute of work.
  StrikeState onWorkoutCompleted(
    StrikeState? prev, {
    required DateTime now,
    double? formAccuracyPct,
  }) {
    final base = prev ?? initial;
    final todayKey = now.dateKey;
    if (base.lastActiveDateKey == todayKey) {
      // Already credited today — only a new form-mastery could unlock.
      if (formAccuracyPct != null && formAccuracyPct >= 90) {
        if (base.unlockedTiers.contains(formMasteryBadgeId)) return base;
        return _state(base, base.currentStrike, todayKey, [
          ...base.unlockedTiers,
          formMasteryBadgeId,
        ]..sort());
      }
      return base;
    }

    final yesterdayKey = now.subtract(const Duration(days: 1)).dateKey;
    final nextStrike = base.lastActiveDateKey == yesterdayKey
        ? base.currentStrike + 1
        : 1;

    final tiers = <int>{...base.unlockedTiers, ...base.newlyEarned(nextStrike)};
    if (formAccuracyPct != null && formAccuracyPct >= 90) {
      tiers.add(formMasteryBadgeId);
    }
    return _state(
      base,
      nextStrike,
      todayKey,
      tiers.toList()..sort(),
    );
  }

  /// Read-time rollover: returns `prev`, or a reset copy when the streak
  /// broke (caller persists the reset — dirty → synced next sweep).
  StrikeState onRead(StrikeState prev, DateTime now) {
    if (prev.currentStrike == 0) return prev;
    final todayKey = now.dateKey;
    final yesterdayKey = now.subtract(const Duration(days: 1)).dateKey;
    if (prev.lastActiveDateKey == todayKey ||
        prev.lastActiveDateKey == yesterdayKey) {
      return prev;
    }
    // Fresh instance → syncedAt null (dirty): reset must propagate.
    return _state(prev, 0, prev.lastActiveDateKey, prev.unlockedTiers);
  }

  /// Gap in days since `lastActive` (null when never trained).
  int? gapDays(StrikeState state, DateTime now) {
    if (state.lastActiveDateKey.isEmpty) return null;
    final last = DateTime.parse(state.lastActiveDateKey);
    return now.startOfDay.difference(last).inDays;
  }

  StrikeState _state(
    StrikeState base,
    int strike,
    String lastActive,
    List<int> tiers,
  ) =>
      StrikeState(
        currentStrike: strike,
        longestStrike:
            strike > base.longestStrike ? strike : base.longestStrike,
        lastActiveDateKey: lastActive,
        unlockedTiers: tiers,
      );
}
