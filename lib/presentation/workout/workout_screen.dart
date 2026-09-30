import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../shared/anim/skeleton.dart';
import '../shared/glass_card.dart';
import '../shared/grid_background.dart';
import '../shared/primary_button.dart';
import '../shared/section_header.dart';
import '../shared/status_pill.dart';

/// 07 — Workout tab (sample `index.html`): header, today's session resume card,
/// category chips and the workout library. Every card opens its details page.
class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  static const _categories = <String>[
    'All',
    'Strength',
    'Cardio',
    'Mobility',
    'Core',
  ];

  /// Index of the active chip — the sample opens with "All" selected.
  int _category = 0;

  /// True while the screen shows its loading skeleton.
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Mock initial-load delay — P1 swaps this for the real data source.
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Workout',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: p.ink2,
                          ),
                        ),
                        Text(
                          'Train today',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: p.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _GlassIcon(icon: Icons.search),
                  const SizedBox(width: 8),
                  const _GlassIcon(icon: Icons.tune),
                ],
              ),
              const SizedBox(height: 16),
              if (_loading)
                const _WorkoutSkeleton()
              else ...[
                const _ResumeCard(),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < _categories.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        _CategoryChip(
                          label: _categories[i],
                          selected: i == _category,
                          onTap: () => setState(() => _category = i),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: SectionHeader(title: 'Workout library'),
                    ),
                    Text(
                      '14 workouts',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: p.accentDeep,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final workout in _workouts) ...[
                  _WorkoutRow(workout),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Today's session" card with progress and a resume action (sample §07).
class _ResumeCard extends StatelessWidget {
  const _ResumeCard();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: p.accentSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule, size: 13, color: p.accentDeep),
                      const SizedBox(width: 5),
                      Text(
                        '17:00 · TODAY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: p.accentDeep,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Lower Body Strength',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '4 exercises · 3 rounds · about 32 min',
                  style: TextStyle(fontSize: 11.5, color: p.ink3),
                ),
                const SizedBox(height: 10),
                const _ProgressBar(value: 0.35),
                const SizedBox(height: 6),
                Text(
                  'Round 1 of 3 — resume where you left',
                  style: TextStyle(fontSize: 11.5, color: p.ink3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PrimaryButton(
            label: 'Resume',
            icon: Icons.play_arrow,
            expand: false,
            onPressed: () => context.push('/vision'),
          ),
        ],
      ),
    );
  }
}

/// Rounded pill filter (sample `.chip` / `.chip.on`).
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? p.selBg : p.glass,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? p.selBg : p.border),
            boxShadow: [
              BoxShadow(
                color: p.shadowSoft,
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? p.selFg : p.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// Library row (sample `.lrow`) — taps through to the details screen.
class _WorkoutRow extends StatelessWidget {
  const _WorkoutRow(this.workout);

  final _Workout workout;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 18,
      onTap: () => context.push('/workout-details'),
      child: Row(
        children: [
          _Thumb(icon: workout.icon, style: workout.style),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  workout.meta,
                  style: TextStyle(fontSize: 11.5, color: p.ink3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusPill(label: workout.pill, tone: workout.pillTone, dot: false),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 20, color: p.ink3),
        ],
      ),
    );
  }
}

/// Gradient media placeholder used by list thumbs (sample `.ph-media`).
class _Thumb extends StatelessWidget {
  const _Thumb({required this.icon, required this.style});

  final IconData icon;
  final _ThumbStyle style;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final amber = style == _ThumbStyle.amber;
    return Container(
      width: 56,
      height: 56,
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
          _ThumbStyle.amber => LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.amber, p.amberPillFg],
          ),
        },
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(
        icon,
        size: 26,
        color: amber ? AppColors.accentInk : Colors.white.withAlpha(235),
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

/// Square glass icon tile (sample `.icon-btn`).
class _GlassIcon extends StatelessWidget {
  const _GlassIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: p.glass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
        boxShadow: [
          BoxShadow(
            color: p.shadowSoft,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, size: 21, color: p.ink),
    );
  }
}

/// Visual treatment of a media placeholder.
enum _ThumbStyle { slate, green, dark, amber }

/// One library entry (sample workout cards).
class _Workout {
  const _Workout(
    this.title,
    this.meta,
    this.icon,
    this.style,
    this.pill,
    this.pillTone,
  );

  final String title;
  final String meta;
  final IconData icon;
  final _ThumbStyle style;
  final String pill;
  final PillTone pillTone;
}

// UI-first demo data — phase P3 wires the real source.
const List<_Workout> _workouts = [
  _Workout(
    'Full Body Strength',
    '30 min · Moderate · 365 kcal',
    Icons.accessibility_new,
    _ThumbStyle.slate,
    '3 × 12',
    PillTone.green,
  ),
  _Workout(
    'HIIT Jump Circuit',
    '20 min · Hard · 300 kcal',
    Icons.directions_run,
    _ThumbStyle.green,
    'HIIT',
    PillTone.amber,
  ),
  _Workout(
    'Mobility Reset',
    '18 min · Easy · 120 kcal',
    Icons.self_improvement,
    _ThumbStyle.dark,
    'Rest day',
    PillTone.green,
  ),
  _Workout(
    'Core Blast',
    '15 min · Moderate · 180 kcal',
    Icons.fitness_center,
    _ThumbStyle.amber,
    'New',
    PillTone.green,
  ),
];

/// Loading stand-in: resume card, category chips, library header and four
/// workout rows — same paddings as the real content so the swap doesn't jump.
class _WorkoutSkeleton extends StatelessWidget {
  const _WorkoutSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassCard(
            weak: true,
            padding: EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 96, height: 24, radius: 12),
                SizedBox(height: 10),
                SkeletonBox(width: 190, height: 18, radius: 8),
                SizedBox(height: 6),
                SkeletonText(width: 244),
                SizedBox(height: 10),
                SkeletonBox(height: 9, radius: 999),
                SizedBox(height: 8),
                SkeletonText(width: 200),
              ],
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              SkeletonBox(width: 64, height: 36, radius: 999),
              SizedBox(width: 8),
              SkeletonBox(width: 84, height: 36, radius: 999),
              SizedBox(width: 8),
              SkeletonBox(width: 70, height: 36, radius: 999),
              SizedBox(width: 8),
              SkeletonBox(width: 82, height: 36, radius: 999),
            ],
          ),
          SizedBox(height: 18),
          SkeletonBox(width: 150, height: 20, radius: 6),
          SizedBox(height: 10),
          _SkeletonWorkoutRow(),
          SizedBox(height: 10),
          _SkeletonWorkoutRow(),
          SizedBox(height: 10),
          _SkeletonWorkoutRow(),
          SizedBox(height: 10),
          _SkeletonWorkoutRow(),
        ],
      ),
    );
  }
}

/// One library-row placeholder: media thumb + title/meta lines.
class _SkeletonWorkoutRow extends StatelessWidget {
  const _SkeletonWorkoutRow();

  @override
  Widget build(BuildContext context) {
    return const GlassCard(
      weak: true,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 18,
      child: Row(
        children: [
          SkeletonBox(width: 56, height: 56, radius: 15),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonText(width: 140, height: 14),
                SizedBox(height: 6),
                SkeletonText(width: 184),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
