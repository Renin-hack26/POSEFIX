import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Tone of a [StatusPill].
enum PillTone { green, amber, dark, neutral }

/// Small rounded status chip (sample `.badge` / `.pill`): optional dot + label.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.tone = PillTone.green,
    this.dot = true,
  });

  final String label;
  final PillTone tone;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    final (bg, fg, dotColor) = switch (tone) {
      PillTone.green => (p.accentSoft, p.accentDeep, p.accentDeep),
      PillTone.amber => (p.amberPillBg, p.amberPillFg, p.amberPillFg),
      PillTone.dark => (p.selBg, p.selFg, p.selDot),
      PillTone.neutral => (p.trackStrong, p.ink2, p.ink3),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: dot ? 10 : 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
