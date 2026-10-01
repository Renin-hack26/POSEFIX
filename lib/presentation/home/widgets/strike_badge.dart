import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../shared/glass_card.dart';

/// Glass "day streak" pill for the home header — fire glyph, count and label
/// (sample header badge: `local_fire_department` + `5` + `day streak`).
class StrikeBadge extends StatelessWidget {
  const StrikeBadge({super.key, this.days = 5});

  /// Consecutive active days displayed in the badge. Null while the count
  /// is unknown (dashboard loading/error) → the number is replaced by a
  /// neutral dash so the badge never claims a streak it hasn't loaded.
  final int? days;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      radius: 14,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department,
            size: 17,
            color: AppColors.amber,
          ),
          const SizedBox(width: 7),
          Text(
            // '—' while the streak is unknown: no numeric claim until the
            // dashboard has actually loaded (a real 0 still renders '0').
            days?.toString() ?? '—',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: p.ink,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            'day streak',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: p.ink3,
            ),
          ),
        ],
      ),
    );
  }
}
