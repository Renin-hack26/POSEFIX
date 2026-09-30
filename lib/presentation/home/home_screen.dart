import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../shared/app_logo.dart';
import '../shared/grid_background.dart';
import '../shared/primary_button.dart';
import '../shared/section_header.dart';
import 'widgets/analytics_section.dart';
import 'widgets/greeting_banner.dart';
import 'widgets/progress_graph.dart';
import 'widgets/session_slot.dart';
import 'widgets/strike_badge.dart';
import 'widgets/suggestions_carousel.dart';
import 'widgets/tips_carousel.dart';

/// 06 — Home (sample/index.html): header with logo/strike/bell, greeting,
/// today's session banner, suggestions, weekly graph, stat tiles, rotating
/// tips and the report/VEDA action row.
///
/// Rendered inside the AppShell tab (bottom nav provided there), so this
/// screen only stacks `Scaffold > GridBackground > SafeArea > scroll view`.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // UI-first demo data — phase P4 wires the real source.
  static const _summary = 'Last workout 1 day ago · weekly total 2h 15m';
  static const _sessionWhen = 'TODAY · 17:00';
  static const _sessionTitle = 'Lower Body Strength';
  static const _sessionDetails = '4 exercises · 3 rounds · about 32 min';
  static const _total = '2h 48m';
  static const _delta = '+38m vs last week';
  static const _trend = '+18%';

  static const _suggestions = <SuggestionItem>[
    (
      title: 'Mobility Reset',
      caption: 'Core · 18 min',
      subtitle: 'You skipped stretching twice',
      icon: Icons.self_improvement,
      accentThumb: false,
    ),
    (
      title: 'HIIT Jump Circuit',
      caption: 'Cardio · 20 min',
      subtitle: 'Based on last week',
      icon: Icons.directions_run,
      accentThumb: true,
    ),
  ];

  static const _bars = <WeekBar>[
    (day: 'M', fill: 0.38, dim: false),
    (day: 'T', fill: 0.0, dim: false),
    (day: 'W', fill: 0.72, dim: false),
    (day: 'T', fill: 0.12, dim: true),
    (day: 'F', fill: 0.56, dim: false),
    (day: 'S', fill: 0.88, dim: false),
    (day: 'S', fill: 0.0, dim: true),
  ];

  static const _stats = <StatItem>[
    (value: '1,240', label: 'Reps this week'),
    (value: '92%', label: 'Best form accuracy'),
  ];

  static const _tips = <TipItem>[
    (
      title: 'Form tip',
      body:
          'Push your knees outward during squats — they should track over your '
          'toes, never cave in.',
    ),
    (
      title: 'Breathing',
      body:
          'Exhale through the hardest part of the lift — hold your breath only '
          'for a single rep.',
    ),
    (
      title: 'Recovery',
      body:
          'Two rest days a week let the muscle rebuild stronger than the '
          'session itself.',
    ),
    (
      title: 'Hydration',
      body:
          'Sip water between rounds — a two percent drop in fluids cuts your '
          'rep count.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Row(
                  children: [
                    const AppLogo(size: 38, radius: 12, iconSize: 20),
                    const SizedBox(width: 9),
                    const StrikeBadge(days: 5),
                    const Spacer(),
                    // Bell has no destination yet — kept as a static affordance.
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.glass,
                        shape: BoxShape.circle,
                        border: Border.all(color: p.border, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: p.shadowSoft,
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(Icons.notifications, size: 21, color: p.ink),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const GreetingBanner(
                  greeting: 'Good morning',
                  name: 'Alex Carter',
                  summary: _summary,
                ),
                const SizedBox(height: 20),
                SessionSlot(
                  when: _sessionWhen,
                  title: _sessionTitle,
                  details: _sessionDetails,
                  onStart: () => context.push('/workout-details'),
                ),
                const SizedBox(height: 20),
                SectionHeader(
                  title: 'Suggested for you',
                  actionLabel: 'See all',
                  onAction: () => context.go('/plan'),
                ),
                const SizedBox(height: 10),
                SuggestionsCarousel(
                  items: _suggestions,
                  onOpen: () => context.push('/workout-details'),
                ),
                const SizedBox(height: 20),
                const SectionHeader(title: 'Time spent this week'),
                const SizedBox(height: 10),
                const ProgressGraph(
                  total: _total,
                  delta: _delta,
                  trend: _trend,
                  bars: _bars,
                ),
                const SizedBox(height: 20),
                const AnalyticsSection(stats: _stats),
                const SizedBox(height: 20),
                const TipsCarousel(tips: _tips),
                const SizedBox(height: 20),
                Row(
                  children: [
                    // Progress report opens the reports flow — no route yet.
                    const Expanded(
                      child: SecondaryButton(
                        label: 'Progress report',
                        icon: Icons.description,
                        expand: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Chat with VEDA',
                        icon: Icons.smart_toy,
                        expand: false,
                        onPressed: () => context.push('/veda'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
