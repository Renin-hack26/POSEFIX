import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Amber "under construction" banner (hackathon requirement: every surface
/// whose functionality is still pending shows this pill).
///
/// Uses the amber pill tokens from the active palette, so it reads correctly
/// in light and dark themes. Full-width; place inside a Column/ListView or a
/// `Positioned(left/right)` slot.
class UnderConstructionBanner extends StatelessWidget {
  const UnderConstructionBanner({
    super.key,
    this.message = 'Under construction — this feature is coming soon',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: p.amberPillBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.construction, size: 16, color: p.amberPillFg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: p.amberPillFg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
