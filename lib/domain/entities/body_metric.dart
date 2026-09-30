/// Body metrics — weight/height entries (Plan → Progress, Settings → Profile).
library;

class BodyMetric {
  const BodyMetric({
    required this.dateKey,
    required this.weightKg,
    this.heightCm,
    this.notes,
    this.syncedAt,
  });

  /// `yyyy-MM-dd` — one entry per day (last-writer-wins).
  final String dateKey;
  final double weightKg;
  final double? heightCm;
  final String? notes;
  final DateTime? syncedAt;

  BodyMetric copyWith({DateTime? syncedAt}) => BodyMetric(
        dateKey: dateKey,
        weightKg: weightKg,
        heightCm: heightCm,
        notes: notes,
        syncedAt: syncedAt,
      );
}
