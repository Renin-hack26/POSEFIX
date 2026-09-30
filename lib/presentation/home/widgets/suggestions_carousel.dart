import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../shared/glass_card.dart';
import '../../shared/status_pill.dart';

/// Payload of one suggestion card: title, media chip, reason line, glyph and
/// whether the thumbnail uses the accent (green) gradient.
typedef SuggestionItem = ({
  String title,
  String caption,
  String subtitle,
  IconData icon,
  bool accentThumb,
});

/// Horizontal "Suggested for you" carousel — workout cards that open the
/// workout details flow (sample suggestion row).
class SuggestionsCarousel extends StatelessWidget {
  const SuggestionsCarousel({super.key, required this.items, required this.onOpen});

  /// Suggested workouts shown left to right.
  final List<SuggestionItem> items;

  /// Opens the tapped suggestion (workout details).
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            _SuggestionCard(item: items[i], onTap: onOpen),
          ],
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.item, required this.onTap});

  final SuggestionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: 172,
      child: GlassCard(
        padding: const EdgeInsets.all(10),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 84,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: item.accentThumb
                      ? const [AppColors.accentBright, AppColors.accentMid]
                      : [p.ink3, p.ink2],
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      item.icon,
                      size: 40,
                      color: item.accentThumb ? AppColors.accentInk : p.selFg,
                    ),
                  ),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: StatusPill(
                      label: item.caption,
                      tone: PillTone.dark,
                      dot: false,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 9),
            Text(
              item.title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: p.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.subtitle,
              style: TextStyle(fontSize: 11.5, color: p.ink3),
            ),
          ],
        ),
      ),
    );
  }
}
