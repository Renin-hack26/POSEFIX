import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../shared/glass_card.dart';
import '../../shared/status_pill.dart';

/// One weekday bar: label letter, 0..1 fill height and the dimmed
/// (below-target) styling.
typedef WeekBar = ({String day, double fill, bool dim});

/// "Time spent this week" card — total, delta chip and a 7-day bar chart
/// (sample weekly `.bars` graph).
class ProgressGraph extends StatelessWidget {
  const ProgressGraph({
    super.key,
    required this.total,
    required this.delta,
    required this.trend,
    required this.bars,
  });

  /// Total training time this week, e.g. "2h 48m".
  final String total;

  /// Change versus last week, e.g. "+38m vs last week".
  final String delta;

  /// Trend chip, e.g. "+18%".
  final String trend;

  /// Mon–Sun bars, in order.
  final List<WeekBar> bars;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      total,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      delta,
                      style: TextStyle(fontSize: 11.5, color: p.ink3),
                    ),
                  ],
                ),
              ),
              StatusPill(label: trend, tone: PillTone.green),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < bars.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _WeekBarColumn(bar: bars[i])),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Single day column: bar above the weekday letter, bottom-aligned.
class _WeekBarColumn extends StatelessWidget {
  const _WeekBarColumn({required this.bar});

  final WeekBar bar;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const radius = BorderRadius.only(
      topLeft: Radius.circular(8),
      topRight: Radius.circular(8),
      bottomLeft: Radius.circular(4),
      bottomRight: Radius.circular(4),
    );
    final decoration = bar.dim
        ? BoxDecoration(color: p.trackStrong, borderRadius: radius)
        : const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.accentBright, AppColors.accentMid],
            ),
            borderRadius: radius,
          );
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          height: (84 * bar.fill).roundToDouble(),
          decoration: decoration,
        ),
        const SizedBox(height: 6),
        Text(
          bar.day,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: p.ink3,
          ),
        ),
      ],
    );
  }
}
