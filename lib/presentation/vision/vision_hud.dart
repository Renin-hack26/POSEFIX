import 'package:flutter/material.dart';

import '../../core/pose/pose_analyzer.dart';
import '../../core/theme/app_theme.dart';

/// Banner copy per person-lock reason. Empty for [LockReason.ok]
/// (the banner is hidden while counting is live).
String lockReasonLine(LockReason reason) => switch (reason) {
      LockReason.ok => '',
      LockReason.noPerson => 'No person detected. Step into frame to begin.',
      LockReason.multiPerson =>
        'More than one person visible. Train solo so reps stay accurate.',
      LockReason.lostTracking =>
        'Tracking lost. Hold still so the coach can lock on again.',
      LockReason.occluded =>
        'Body partly hidden. Adjust so your key joints stay visible.',
      LockReason.videoPlayback =>
        'Looks like a video is playing — do the exercise yourself so your '
            'reps count.',
    };

/// Human-readable FSM state label (`bottom` → `Bottom`).
String prettifyExerciseState(String state) {
  final String normalized = state.trim();
  if (normalized.isEmpty || normalized == 'unknown') {
    return 'Getting ready';
  }
  final String spaced = normalized.replaceAll('_', ' ');
  return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
}

/// Big rep count tile shown over the camera preview.
class RepCounter extends StatelessWidget {
  const RepCounter({super.key, required this.reps});

  final int reps;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: p.glass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border, width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$reps',
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              height: 1,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'REPS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: p.ink3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Current FSM state pill (e.g. Bottom, Ascending).
class ExerciseStateChip extends StatelessWidget {
  const ExerciseStateChip({super.key, required this.state});

  final String state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: p.glass,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: p.border, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fitness_center, size: 15, color: p.accentDeep),
          const SizedBox(width: 7),
          Text(
            prettifyExerciseState(state),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: p.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Live form-score readout.
class FormScoreReadout extends StatelessWidget {
  const FormScoreReadout({super.key, required this.formScore});

  final int formScore;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: p.glass,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: p.border, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.grade, size: 15, color: p.accentDeep),
          const SizedBox(width: 7),
          Text(
            'Form $formScore',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: p.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Person-lock banner — visible only while counting is paused.
/// Rendered only for non-ok reasons; [LockReason.ok] yields an empty box.
class PersonLockBanner extends StatelessWidget {
  const PersonLockBanner({super.key, required this.reason});

  final LockReason reason;

  @override
  Widget build(BuildContext context) {
    if (reason == LockReason.ok) return const SizedBox.shrink();
    final p = context.palette;
    final IconData icon = switch (reason) {
      LockReason.noPerson => Icons.person_off,
      LockReason.multiPerson => Icons.group,
      LockReason.lostTracking => Icons.person_search,
      LockReason.occluded => Icons.visibility_off,
      LockReason.videoPlayback => Icons.smart_display,
      LockReason.ok => Icons.person,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border, width: 1.2),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: p.amberPillFg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              lockReasonLine(reason),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: p.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Camera-adjustment cue card — visible only when framing needs fixing.
/// [FramingCue.ok] yields an empty box.
class FramingCueCard extends StatelessWidget {
  const FramingCueCard({super.key, required this.framing});

  final FramingCue framing;

  @override
  Widget build(BuildContext context) {
    if (framing == FramingCue.ok) return const SizedBox.shrink();
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border, width: 1.2),
      ),
      child: Row(
        children: [
          Icon(Icons.videocam, size: 20, color: p.accentDeep),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              framingCueLine(framing),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: p.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
