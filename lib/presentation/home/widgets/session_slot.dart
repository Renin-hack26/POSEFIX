import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Chartreuse "today's session" banner: schedule chip, workout title, meta
/// line and the ink start CTA (sample `.banner` + `.btn-ink`).
class SessionSlot extends StatelessWidget {
  const SessionSlot({
    super.key,
    required this.when,
    required this.title,
    required this.details,
    required this.onStart,
    this.actionLabel = 'Start session',
  });

  /// Schedule chip text, e.g. "TODAY · 17:00".
  final String when;

  /// Workout name shown on the banner.
  final String title;

  /// Exercise/round/duration summary under the title.
  final String details;

  /// Starts today's session.
  final VoidCallback onStart;

  /// CTA label — "Start session" by default, "Resume session" when a session
  /// is already in flight (PLANNING §5.2 slot state machine).
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accentBright,
            AppColors.accent,
            AppColors.accentMid,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentMid.withAlpha(115),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Decorative sheen (sample `.banner::after`).
            Positioned(
              right: -30,
              top: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.glassHi.withAlpha(36),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentInk.withAlpha(217),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.event_available,
                          size: 13,
                          color: AppColors.accentBright,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          when,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accentBright,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.38,
                      color: AppColors.accentInk,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    details,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentInk.withAlpha(217),
                    ),
                  ),
                  const SizedBox(height: 13),
                  Material(
                    color: AppColors.accentInk,
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      onTap: onStart,
                      borderRadius: BorderRadius.circular(999),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 11,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_arrow,
                              size: 18,
                              color: AppColors.accentBright,
                            ),
                            SizedBox(width: 8),
                            Text(
                              actionLabel,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.accentBright,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
