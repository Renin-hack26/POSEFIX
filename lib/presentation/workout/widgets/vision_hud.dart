import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Rep-count HUD (sample `.hud`) overlaid on the top-left of the live preview:
/// big rep total plus round and time chips.
class VisionHud extends StatelessWidget {
  const VisionHud({
    super.key,
    required this.reps,
    required this.round,
    required this.time,
    this.targetReps,
  });

  /// Counted reps of the current exercise.
  final int reps;

  /// Round indicator, e.g. `2 / 3`.
  final String round;

  /// Elapsed session time, e.g. `04:35`.
  final String time;

  /// Per-round rep target — shown as `OF 12` under the count (WS2.3).
  final int? targetReps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _hudChip(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$reps',
                style: const TextStyle(
                  fontSize: 30,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 4),
              const _HudLabel('REPS'),
              if (targetReps != null && targetReps! > 0) ...[
                const SizedBox(height: 2),
                _HudLabel('OF $targetReps'),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        _hudChip(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _HudLabel('ROUND'),
              Text(
                round,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _hudChip(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _HudLabel('TIME'),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Frosted dark chip used by the HUD (sample `.hud .chip-glass`).
Widget _hudChip({required Widget child, required EdgeInsetsGeometry padding}) {
  return Container(
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.darkPage.withAlpha(140),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withAlpha(41)),
    ),
    child: child,
  );
}

/// Uppercase HUD caption (sample `.hud .lab`).
class _HudLabel extends StatelessWidget {
  const _HudLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 9.5,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
        color: Colors.white.withAlpha(153),
      ),
    );
  }
}
