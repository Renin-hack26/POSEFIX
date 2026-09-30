/// Consistency strike + badge tiers (PLANNING §4.3 STRIKE_ENGINE / §5.2).
library;

/// Badge tier identifiers (days held) — order = display order.
const List<int> badgeTiers = [3, 7, 14, 30, 100];

/// Special `unlockedTiers` entry: form-mastery badge (a session finished at
/// ≥90% form accuracy). Stored alongside day tiers — never revoked.
const int formMasteryBadgeId = 0;

class StrikeState {
  const StrikeState({
    required this.currentStrike,
    required this.longestStrike,
    required this.lastActiveDateKey,
    this.unlockedTiers = const [],
    this.syncedAt,
  });

  final int currentStrike;
  final int longestStrike;

  /// `yyyy-MM-dd` of the most recent active day.
  final String lastActiveDateKey;

  /// Badge tiers already earned (never revoked — badges are achievements).
  final List<int> unlockedTiers;
  final DateTime? syncedAt;

  StrikeState copyWith({
    int? currentStrike,
    int? longestStrike,
    String? lastActiveDateKey,
    List<int>? unlockedTiers,
    DateTime? syncedAt,
    bool keepSynced = false,
  }) =>
      StrikeState(
        currentStrike: currentStrike ?? this.currentStrike,
        longestStrike: longestStrike ?? this.longestStrike,
        lastActiveDateKey: lastActiveDateKey ?? this.lastActiveDateKey,
        unlockedTiers: unlockedTiers ?? this.unlockedTiers,
        syncedAt: keepSynced ? this.syncedAt : (syncedAt ?? this.syncedAt),
      );

  /// Tiers earned for [strike] not yet recorded in [unlockedTiers].
  List<int> newlyEarned(int strike) =>
      badgeTiers.where((t) => strike >= t && !unlockedTiers.contains(t)).toList();
}
