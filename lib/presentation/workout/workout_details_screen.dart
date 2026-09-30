import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../shared/app_back_button.dart';
import '../shared/glass_card.dart';
import '../shared/grid_background.dart';
import '../shared/primary_button.dart';
import '../shared/section_header.dart';
import '../shared/status_pill.dart';

/// 08 — Workout details (sample `index.html`): hero, badge, stats, start CTA,
/// exercise plan and the goal card. Opened from every library card; each
/// exercise row opens the instruction video.
class WorkoutDetailsScreen extends StatelessWidget {
  const WorkoutDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 26),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppBackButton(fallback: '/workout'),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Text(
                        'Workout details',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: p.ink,
                        ),
                      ),
                    ),
                  ),
                  const _BookmarkButton(),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    // Hero (sample `.ph-media.dark` + FULL BODY badge).
                    Stack(
                      children: [
                        Container(
                          height: 190,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppColors.lightInk2, AppColors.lightInk],
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.accessibility_new,
                              size: 56,
                              color: Colors.white.withAlpha(235),
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 10,
                          bottom: 10,
                          child: StatusPill(
                            label: 'FULL BODY',
                            tone: PillTone.dark,
                            dot: false,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Full Body Strength',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Build strength across every major muscle group — '
                      'no equipment needed.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: p.ink2,
                      ),
                    ),
                    const SizedBox(height: 20),
                    GlassCard(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _Stat(
                            icon: Icons.schedule,
                            value: '30 min',
                            label: 'Duration',
                          ),
                          _Stat(
                            icon: Icons.speed,
                            value: 'Moderate',
                            label: 'Intensity',
                          ),
                          _Stat(
                            icon: Icons.local_fire_department,
                            iconColor: AppColors.amber,
                            value: '365',
                            label: 'kcal',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: 'Start workout',
                      icon: Icons.play_arrow,
                      onPressed: () => context.push('/vision'),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(
                          child: SectionHeader(title: 'Workout plan'),
                        ),
                        Text(
                          '4 exercises',
                          style: TextStyle(fontSize: 11.5, color: p.ink3),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final item in _plan) ...[
                      _PlanRow(item),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 4),
                    GlassCard(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: p.accentSoft,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.flag,
                              size: 21,
                              color: p.accentDeep,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your goal',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: p.ink,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Train 4× per week · lose 4 kg in 8 weeks — '
                                  'this session counts toward it',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    height: 1.4,
                                    color: p.ink3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Numbered exercise row (sample `.lrow`) → instruction video.
class _PlanRow extends StatelessWidget {
  const _PlanRow(this.item);

  final _PlanItem item;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 18,
      onTap: () => context.push('/instruction-video'),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.selBg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '${item.index}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: p.selFg,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _Thumb(icon: item.icon, style: item.style, size: 44, radius: 13),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.sets,
                  style: TextStyle(fontSize: 11.5, color: p.ink3),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 20, color: p.ink3),
        ],
      ),
    );
  }
}

/// Icon + value + caption trio inside the stats card (sample `.stat`).
class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: iconColor ?? p.ink2),
        const SizedBox(width: 7),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: p.ink,
              ),
            ),
            Text(label, style: TextStyle(fontSize: 11.5, color: p.ink3)),
          ],
        ),
      ],
    );
  }
}

/// Bookmark toggle in the header (sample `.icon-btn` bookmark).
class _BookmarkButton extends StatefulWidget {
  const _BookmarkButton();

  @override
  State<_BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends State<_BookmarkButton> {
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(right: 18, top: 8),
      child: Material(
        color: p.glass,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _saved = !_saved),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              _saved ? Icons.bookmark : Icons.bookmark_border,
              size: 21,
              color: _saved ? p.accentDeep : p.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// Gradient media placeholder used by plan thumbs (sample `.ph-media`).
class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.icon,
    required this.style,
    this.size = 56,
    this.radius = 15,
  });

  final IconData icon;
  final _ThumbStyle style;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final amber = style == _ThumbStyle.amber;
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
          _ThumbStyle.amber => LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.amber, p.amberPillFg],
          ),
        },
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        icon,
        size: size * 0.46,
        color: amber ? AppColors.accentInk : Colors.white.withAlpha(235),
      ),
    );
  }
}

/// Visual treatment of a media placeholder.
enum _ThumbStyle { slate, green, dark, amber }

/// One exercise of the workout plan.
class _PlanItem {
  const _PlanItem(this.index, this.title, this.sets, this.icon, this.style);

  final int index;
  final String title;
  final String sets;
  final IconData icon;
  final _ThumbStyle style;
}

// UI-first demo data — phase P3 wires the real source.
const List<_PlanItem> _plan = [
  _PlanItem(
    1,
    'Push Ups',
    '3 sets × 12 reps',
    Icons.accessibility_new,
    _ThumbStyle.slate,
  ),
  _PlanItem(
    2,
    'Squats',
    '3 sets × 12 reps',
    Icons.self_improvement,
    _ThumbStyle.green,
  ),
  _PlanItem(
    3,
    'Plank',
    '3 sets × 45 s hold',
    Icons.timelapse,
    _ThumbStyle.dark,
  ),
  _PlanItem(
    4,
    'Mountain Climbers',
    '3 sets × 20 reps',
    Icons.directions_run,
    _ThumbStyle.amber,
  ),
];
