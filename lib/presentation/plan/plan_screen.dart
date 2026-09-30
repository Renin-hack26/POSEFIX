import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../shared/glass_card.dart';
import '../shared/grid_background.dart';
import '../shared/primary_button.dart';
import '../shared/section_header.dart';
import '../shared/status_pill.dart';

// UI-first demo data — phase P5 wires the real source.
const _weekLabel = 'Sep 29 – Oct 5';
const _selectedDay = '30';
const _weekDays = [
  (letter: 'M', date: '29', hasSession: true),
  (letter: 'T', date: '30', hasSession: true),
  (letter: 'W', date: '1', hasSession: false),
  (letter: 'T', date: '2', hasSession: true),
  (letter: 'F', date: '3', hasSession: false),
  (letter: 'S', date: '4', hasSession: false),
  (letter: 'S', date: '5', hasSession: false),
];
const _session = (
  time: '17:00',
  title: 'Lower Body Strength',
  moves: 'Squat · Push Up · Jumping Jack · Plank',
);
const _library = [
  (
    icon: Icons.self_improvement,
    title: 'Squats',
    meta: 'Legs · 6 rules',
    tone: _MediaTone.steel,
  ),
  (
    icon: Icons.accessibility,
    title: 'Push Ups',
    meta: 'Chest · 5 rules',
    tone: _MediaTone.chartreuse,
  ),
  (
    icon: Icons.directions_run,
    title: 'Jumping Jacks',
    meta: 'Cardio · 4 rules',
    tone: _MediaTone.slate,
  ),
];
const _meals = (
  eaten: '1,450',
  goal: '2,000',
  remaining: '550 kcal remaining',
  progress: 0.72,
);
const _mealTiles = [
  (icon: Icons.breakfast_dining, title: 'Breakfast', meta: '420 kcal', amber: true),
  (icon: Icons.lunch_dining, title: 'Lunch', meta: '610 kcal', amber: false),
];
const _history = [
  (title: 'Full Body Strength', meta: 'Yesterday · 88 reps · form 91%'),
  (title: 'HIIT Jump Circuit', meta: '2 days ago · 120 reps · form 87%'),
];

/// Placeholder thumbnail tones for the exercise library cards (sample
/// `.ph-media`, `.ph-media.green`, `.ph-media.dark`).
enum _MediaTone { steel, chartreuse, slate }

/// 12 — Plan tab (sample/index.html): week header + navigation, quick chips,
/// day strip, next session with Start, exercise library, meals and history.
///
/// UI-first: only the session Start button is wired (`/vision`); the section
/// links are static copy until their screens land in the router.
class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _WeekHeader(),
                const SizedBox(height: 14),
                const _PlanChips(),
                const SizedBox(height: 16),
                const _WeekStrip(),
                const SizedBox(height: 20),
                _NextSessionCard(onStart: () => context.push('/vision')),
                const SizedBox(height: 20),
                const _LibrarySection(),
                const SizedBox(height: 20),
                const _MealsSection(),
                const SizedBox(height: 20),
                const _HistorySection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Training plan" eyebrow + week range, with the two week arrows.
class _WeekHeader extends StatelessWidget {
  const _WeekHeader();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Training plan',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: p.ink2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _weekLabel,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: p.ink,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const _IconBox(Icons.chevron_left),
        const SizedBox(width: 7),
        const _IconBox(Icons.chevron_right),
      ],
    );
  }
}

/// Glass square icon button (sample `.icon-btn`) — decorative in this screen.
class _IconBox extends StatelessWidget {
  const _IconBox(this.icon);

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
        border: Border.all(color: p.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: p.shadowSoft,
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, size: 21, color: p.ink),
    );
  }
}

/// Quick status chips row: AI generated (selected), Edit schedule, Reminders.
class _PlanChips extends StatelessWidget {
  const _PlanChips();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 8,
      children: const [
        _Chip(label: 'AI generated', icon: Icons.auto_awesome, selected: true),
        _Chip(label: 'Edit schedule'),
        _Chip(label: 'Reminders on'),
      ],
    );
  }
}

/// Rounded glass chip (sample `.chip`, `.chip.on`).
class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.icon, this.selected = false});

  final String label;
  final IconData? icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? p.selBg : p.glass,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: selected ? p.selBg : p.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: p.shadowSoft,
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: selected ? p.selFg : p.accentDeep),
            const SizedBox(width: 7),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? p.selFg : p.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mon–Sun strip; today is selected, dots mark scheduled sessions.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _weekDays.length; i++) ...[
          if (i > 0) const SizedBox(width: 7),
          Expanded(
            child: _DayCell(
              letter: _weekDays[i].letter,
              date: _weekDays[i].date,
              hasSession: _weekDays[i].hasSession,
              selected: _weekDays[i].date == _selectedDay,
            ),
          ),
        ],
      ],
    );
  }
}

/// Single day cell (sample `.day`, `.day.on`).
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.letter,
    required this.date,
    required this.hasSession,
    required this.selected,
  });

  final String letter;
  final String date;
  final bool hasSession;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AspectRatio(
      aspectRatio: 1 / 1.25,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? p.selBg : p.glass,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: selected ? p.selBg : p.border, width: 1.2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              letter,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: selected ? p.selFg : p.ink3,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              date,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: selected ? p.selFg : p.ink,
              ),
            ),
            if (hasSession) ...[
              const SizedBox(height: 3),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: selected ? p.selDot : AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Today's session card with the Start CTA (sample `.btn`).
class _NextSessionCard extends StatelessWidget {
  const _NextSessionCard({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusPill(label: _session.time, tone: PillTone.green),
                const SizedBox(height: 8),
                Text(
                  _session.title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _session.moves,
                  style: TextStyle(fontSize: 11.5, color: p.ink3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PrimaryButton(
            label: 'Start',
            icon: Icons.play_arrow,
            expand: false,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}

/// Horizontal "Exercise library" carousel with a "See all" link label.
class _LibrarySection extends StatelessWidget {
  const _LibrarySection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SectionHeader(title: 'Exercise library')),
            const _LinkLabel('See all'),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 138,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < _library.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                _LibraryCard(item: _library[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One exercise preview card: gradient thumbnail + name + muscle/rules meta.
class _LibraryCard extends StatelessWidget {
  const _LibraryCard({required this.item});

  final ({IconData icon, String title, String meta, _MediaTone tone}) item;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (colors, glyphColor) = switch (item.tone) {
      _MediaTone.steel => ([p.ink3, p.ink2], p.selFg),
      _MediaTone.chartreuse => (
          [AppColors.accentBright, AppColors.accentMid],
          AppColors.accentInk,
        ),
      _MediaTone.slate => ([p.ink2, p.selBg], p.selFg),
    };
    return Container(
      width: 130,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: p.glass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: p.shadowSoft,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 76,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
            ),
            child: Center(
              child: Icon(item.icon, size: 38, color: glyphColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.meta,
            style: TextStyle(fontSize: 11.5, color: p.ink3),
          ),
        ],
      ),
    );
  }
}

/// "Meals today": kcal card with progress bar + two meal tiles.
class _MealsSection extends StatelessWidget {
  const _MealsSection();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final trackWidth = MediaQuery.sizeOf(context).width - 72;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SectionHeader(title: 'Meals today')),
            const _LinkLabel('Log meal'),
          ],
        ),
        const SizedBox(height: 10),
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              _meals.eaten,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: p.ink,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '/ ${_meals.goal} kcal',
                              style: TextStyle(fontSize: 12.5, color: p.ink2),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _meals.remaining,
                          style: TextStyle(fontSize: 11.5, color: p.ink3),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.restaurant, size: 26, color: p.accentDeep),
                ],
              ),
              const SizedBox(height: 11),
              Container(
                height: 9,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: p.track,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: trackWidth * _meals.progress,
                    height: 9,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.accentMid, AppColors.accentBright],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < _mealTiles.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: _MealTile(tile: _mealTiles[i])),
            ],
          ],
        ),
      ],
    );
  }
}

/// Compact per-meal row (sample `.grid2 .lrow`).
class _MealTile extends StatelessWidget {
  const _MealTile({required this.tile});

  final ({IconData icon, String title, String meta, bool amber}) tile;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: p.shadowSoft,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            tile.icon,
            size: 20,
            color: tile.amber ? AppColors.amber : p.accentDeep,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tile.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tile.meta,
                  style: TextStyle(fontSize: 11.5, color: p.ink3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Recent sessions list (sample `.list .lrow` + `.idx`).
class _HistorySection extends StatelessWidget {
  const _HistorySection();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SectionHeader(title: 'History')),
            const _LinkLabel('View all'),
          ],
        ),
        const SizedBox(height: 10),
        for (final row in _history) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: p.glass,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.border, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: p.shadowSoft,
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.accentMid,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 14,
                    color: AppColors.accentInk,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: p.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        row.meta,
                        style: TextStyle(fontSize: 11.5, color: p.ink3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, size: 20, color: p.ink3),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Accent section action copy (sample `.link`) — static until routed.
class _LinkLabel extends StatelessWidget {
  const _LinkLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: p.accentDeep,
        ),
      ),
    );
  }
}
