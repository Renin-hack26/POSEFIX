import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../shared/glass_card.dart';

/// Payload of one rotating tip: heading plus advice copy.
typedef TipItem = ({String title, String body});

/// Rotating tip card — swipeable [PageView] with pagination dots
/// (sample "Form tip" block under the analytics row).
class TipsCarousel extends StatefulWidget {
  const TipsCarousel({super.key, required this.tips});

  /// Tips cycled through the carousel.
  final List<TipItem> tips;

  @override
  State<TipsCarousel> createState() => _TipsCarouselState();
}

class _TipsCarouselState extends State<TipsCarousel> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tips = widget.tips;
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 92,
            width: double.infinity,
            child: PageView.builder(
              itemCount: tips.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => _TipSlide(tip: tips[i]),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < tips.length; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                _Dot(active: i == _index),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Single tip: accent icon tile, heading and body copy.
class _TipSlide extends StatelessWidget {
  const _TipSlide({required this.tip});

  final TipItem tip;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: p.accentSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.tips_and_updates, size: 19, color: p.accentDeep),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tip.title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: p.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tip.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, height: 1.45, color: p.ink2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Pagination pill: wide + accent when selected, narrow track otherwise.
class _Dot extends StatelessWidget {
  const _Dot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: active ? 16 : 6,
      height: 5,
      margin: const EdgeInsets.only(right: 5),
      decoration: BoxDecoration(
        color: active ? AppColors.accent : p.trackStrong,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}
