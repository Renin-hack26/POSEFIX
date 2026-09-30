import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../shared/glass_card.dart';
import '../shared/grid_background.dart';
import '../shared/primary_button.dart';
import '../shared/section_header.dart';
import '../shared/status_pill.dart';

/// 11 — Session summary (sample `index.html`): completion headline, result
/// stats, per-exercise breakdown, streak banner and the exit actions.
class SessionSummaryScreen extends StatelessWidget {
  const SessionSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 30, 18, 26),
            children: [
              // ---- Completion header ----
              Container(
                width: 74,
                height: 74,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check, size: 40, color: p.accentDeep),
              ),
              const SizedBox(height: 14),
              Text(
                'Session complete',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: p.ink,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Lower Body Strength · 3 of 3 rounds',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: p.ink2),
              ),
              const SizedBox(height: 20),
              for (var i = 0; i < _stats.length; i += 2) ...[
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        value: _stats[i].$1,
                        label: _stats[i].$2,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        value: _stats[i + 1].$1,
                        label: _stats[i + 1].$2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 10),
              const SectionHeader(title: 'Breakdown'),
              const SizedBox(height: 10),
              for (final result in _results) ...[
                _BreakdownRow(result),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 4),
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      size: 24,
                      color: AppColors.amber,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Streak extended to 6 days',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: p.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Best this month — keep it going',
                            style: TextStyle(fontSize: 11.5, color: p.ink3),
                          ),
                        ],
                      ),
                    ),
                    const StatusPill(label: '+1', dot: false),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    flex: 10,
                    child: SecondaryButton(label: 'Share', icon: Icons.share),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 14,
                    child: PrimaryButton(
                      label: 'Done',
                      icon: Icons.check,
                      onPressed: () => context.go('/home'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Glass result tile (sample `.statcard`).
class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: p.ink2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Per-exercise result row with form-accuracy bar (sample `.lrow` + `.bar`).
class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow(this.result);

  final _ExerciseResult result;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 18,
      child: Row(
        children: [
          _Thumb(icon: result.icon, style: result.style, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  result.meta,
                  style: TextStyle(fontSize: 11.5, color: p.ink3),
                ),
                const SizedBox(height: 7),
                _ProgressBar(value: result.form),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin gradient progress bar (sample `.bar`).
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  /// Fill fraction, 0..1.
  final double value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      height: 9,
      decoration: BoxDecoration(
        color: p.track,
        borderRadius: BorderRadius.circular(999),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value.clamp(0.0, 1.0).toDouble(),
        child: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.accentMid, AppColors.accentBright],
            ),
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
        ),
      ),
    );
  }
}

/// Gradient media placeholder used by breakdown thumbs (sample `.ph-media`).
class _Thumb extends StatelessWidget {
  const _Thumb({required this.icon, required this.style, this.size = 56});

  final IconData icon;
  final _ThumbStyle style;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: switch (style) {
          _ThumbStyle.slate => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.lightInk3, AppColors.lightInk2],
          ),
          _ThumbStyle.green => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.accent, AppColors.lightAccentDeep],
          ),
          _ThumbStyle.dark => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.lightInk2, AppColors.lightInk],
          ),
        },
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, size: size * 0.46, color: Colors.white.withAlpha(235)),
    );
  }
}

/// Visual treatment of a media placeholder.
enum _ThumbStyle { slate, green, dark }

/// One exercised movement of the finished session.
class _ExerciseResult {
  const _ExerciseResult(
    this.title,
    this.meta,
    this.form,
    this.icon,
    this.style,
  );

  final String title;
  final String meta;
  final double form;
  final IconData icon;
  final _ThumbStyle style;
}

// UI-first demo data — phase P3 wires the real source.
const List<(String, String)> _stats = [
  ('96', 'Total reps'),
  ('91%', 'Form accuracy'),
  ('2.4s', 'Avg cadence / rep'),
  ('32:18', 'Total duration'),
];

const List<_ExerciseResult> _results = [
  _ExerciseResult(
    'Barbell Squat',
    '3 × 12 · form 94%',
    0.94,
    Icons.self_improvement,
    _ThumbStyle.green,
  ),
  _ExerciseResult(
    'Push Up',
    '3 × 12 · form 89%',
    0.89,
    Icons.accessibility_new,
    _ThumbStyle.slate,
  ),
  _ExerciseResult(
    'Jumping Jack',
    '3 × 20 · form 90%',
    0.90,
    Icons.directions_run,
    _ThumbStyle.dark,
  ),
];
