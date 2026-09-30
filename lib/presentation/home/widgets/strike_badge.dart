import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../shared/glass_card.dart';

/// Glass "day streak" pill for the home header — fire glyph, count and label
/// (sample header badge: `local_fire_department` + `5` + `day streak`).
class StrikeBadge extends StatelessWidget {
  const StrikeBadge({super.key, this.days = 5});

  /// Consecutive active days displayed in the badge.
  final int days;

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
            '$days',
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
