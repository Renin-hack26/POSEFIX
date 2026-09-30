import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../shared/glass_card.dart';

/// Payload of one stat tile: big value plus caption.
typedef StatItem = ({String value, String label});

/// Two-up stat tiles under the graph — weekly reps and best form accuracy
/// (sample `.grid2` analytics row).
class AnalyticsSection extends StatelessWidget {
  const AnalyticsSection({super.key, required this.stats});

  /// Stats rendered left to right, two per row.
  final List<StatItem> stats;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              radius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stats[i].value,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.42,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    stats[i].label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: p.ink2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
