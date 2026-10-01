import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/di/app_dependencies.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/home_dashboard.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/workout.dart';
import '../../domain/entities/workout_session.dart';
import '../shared/app_logo.dart';
import '../shared/glass_card.dart';
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
///
/// Data: single [GetHomeDashboard] read (+ user profile + active workout
/// name) — no demo constants; every slot maps 1:1 from the aggregate.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

/// Everything HOME renders, resolved once per entry.
class _HomeData {
  const _HomeData({
    required this.dashboard,
    required this.user,
    required this.activeWorkout,
  });

  final HomeDashboard dashboard;
  final UserProfile? user;
  final Workout? activeWorkout;
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final Future<_HomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeData> _load() async {
    final dashboard = await ref.read(homeDashboardProvider)();
    UserProfile? user;
    try {
      user = await ref.read(userRepositoryProvider).currentUser();
    } catch (_) {
      user = null;
    }
    Workout? activeWorkout;
    final active = dashboard.activeSession;
    if (active != null) {
      try {
        activeWorkout =
            await ref.read(workoutRepositoryProvider).byId(active.workoutId);
      } catch (_) {
        activeWorkout = null;
      }
    }
    return _HomeData(
      dashboard: dashboard,
      user: user,
      activeWorkout: activeWorkout,
    );
  }

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: FutureBuilder<_HomeData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 6),
                      _HomeHeader(strike: 0),
                      SizedBox(height: 20),
                      _HomeSkeleton(),
                    ],
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      const _HomeHeader(strike: 0),
                      const SizedBox(height: 24),
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Could not load your dashboard',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: p.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Check your connection and try again — '
                              'your data stays on this device.',
                              style: TextStyle(fontSize: 12.5, color: p.ink2),
                            ),
                            const SizedBox(height: 14),
                            SecondaryButton(
                              label: 'Retry',
                              icon: Icons.refresh,
                              onPressed: _retry,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                return _HomeBody(data: snapshot.data!);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.strike});

  final int strike;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        const AppLogo(size: 38, radius: 12, iconSize: 20),
        const SizedBox(width: 9),
        StrikeBadge(days: strike),
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
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.data});

  final _HomeData data;

  @override
  Widget build(BuildContext context) {
    final d = data.dashboard;
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final fullName = (data.user?.fullName ?? '').trim();
    final name = fullName.isEmpty ? 'there' : fullName;
    final weekTotal = _formatMinutes(d.weekMinutes);
    final summary = switch (d.gapDays) {
      null => 'First session awaits · weekly total $weekTotal',
      0 => 'Trained today · weekly total $weekTotal',
      1 => 'Last workout yesterday · weekly total $weekTotal',
      final gap => 'Last workout $gap days ago · weekly total $weekTotal',
    };

    final suggestions = <SuggestionItem>[
      for (var i = 0; i < d.suggestions.length; i++)
        (
          title: d.suggestions[i].name,
          caption:
              '${d.suggestions[i].category.label} · ${d.suggestions[i].durationMin} min',
          subtitle: d.suggestions[i].goal,
          icon: _iconFor(d.suggestions[i].category),
          accentThumb: i.isEven,
        ),
    ];
    final tips = <TipItem>[
      for (final tip in d.tips) (title: 'Coach tip', body: tip),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        _HomeHeader(strike: d.strike.currentStrike),
        const SizedBox(height: 20),
        GreetingBanner(
          greeting: greeting,
          name: name,
          summary: summary,
        ),
        const SizedBox(height: 20),
        _SessionSlot(data: data),
        const SizedBox(height: 20),
        SectionHeader(
          title: 'Suggested for you',
          actionLabel: 'See all',
          onAction: () => context.go('/plan'),
        ),
        const SizedBox(height: 10),
        if (suggestions.isNotEmpty)
          SuggestionsCarousel(
            items: suggestions,
            onOpen: () => context.push('/workout-details'),
          ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Time spent this week'),
        const SizedBox(height: 10),
        _WeekGraph(dashboard: d),
        const SizedBox(height: 20),
        AnalyticsSection(stats: [
          (
            value: NumberFormat.decimalPattern().format(d.weekReps),
            label: 'Reps this week',
          ),
          (
            value: '${d.bestFormPct30d.round()}%',
            label: 'Best form accuracy',
          ),
        ]),
        const SizedBox(height: 20),
        if (tips.isNotEmpty) ...[
          TipsCarousel(tips: tips),
          const SizedBox(height: 20),
        ],
        Row(
          children: [
            // Progress report opens the reports flow — no route yet.
            // Expanded (tight) gives each button a bounded half-width, so the
            // inner SizedBox(double.infinity) resolves instead of overflowing.
            // Labels ellipsize inside the button (see primary_button.dart).
            Expanded(
              child: SecondaryButton(
                label: 'Progress report',
                icon: Icons.description,
                expand: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PrimaryButton(
                label: 'Chat with VEDA',
                icon: Icons.smart_toy,
                expand: true,
                onPressed: () => context.push('/veda'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Start/resume slot state machine (PLANNING §5.2): active/paused → Resume,
/// today's plan → Start, no plan → Generate, done → Completed note.
class _SessionSlot extends StatelessWidget {
  const _SessionSlot({required this.data});

  final _HomeData data;

  @override
  Widget build(BuildContext context) {
    final d = data.dashboard;
    final active = d.activeSession;

    if (active != null) {
      final paused = active.status == SessionStatus.paused;
      return SessionSlot(
        when: paused ? 'PAUSED · TAP TO RESUME' : 'IN PROGRESS',
        title: data.activeWorkout?.name ?? 'Workout in progress',
        details: paused
            ? 'Paused mid-session — your progress is saved'
            : 'Session underway — jump back in',
        actionLabel: paused ? 'Resume session' : 'Continue',
        onStart: () => context.push('/vision'),
      );
    }

    if (d.todaySessions.isNotEmpty) {
      final first = d.todaySessions.first;
      final workout = first.workout;
      final exercises = {
        for (final b in workout.blocks) b.exerciseId,
      }.length;
      final sets = workout.blocks.fold<int>(0, (sum, b) => sum + b.sets);
      final time =
          'TODAY · ${_formatStartMin(first.planSession.startTimeMin)}';
      return SessionSlot(
        when: time,
        title: workout.name,
        details:
            '$exercises exercises · $sets sets · about ${workout.durationMin} min',
        onStart: () => context.push('/workout-details'),
      );
    }

    if (!d.hasPlan) {
      return SessionSlot(
        when: 'NO PLAN YET',
        title: 'Build your week',
        details: 'Generate a plan to get today\u2019s session',
        actionLabel: 'Generate plan',
        onStart: () => context.push('/onboarding'),
      );
    }

    return SessionSlot(
      when: 'TODAY',
      title: 'Session completed',
      details: 'Nice work — see you tomorrow',
      actionLabel: 'Browse workouts',
      onStart: () => context.go('/workout'),
    );
  }
}

/// Last-7-day bars from the 28-day graph + delta versus the previous week.
class _WeekGraph extends StatelessWidget {
  const _WeekGraph({required this.dashboard});

  final HomeDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    const weekLetters = 'MTWTFSS';
    final graph = dashboard.graph;
    final last7 = graph.length <= 7 ? graph : graph.sublist(graph.length - 7);
    final maxMinutes = last7.fold<int>(
        0, (m, e) => e.minutes > m ? e.minutes : m);
    final bars = <WeekBar>[
      for (final e in last7)
        (
          day: weekLetters[e.date.weekday - 1],
          fill: maxMinutes == 0 ? 0.0 : e.minutes / maxMinutes,
          dim: e.minutes == 0,
        ),
    ];

    final weekStart =
        DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
    final weekStartDay =
        DateTime(weekStart.year, weekStart.month, weekStart.day);
    final prevWeek = [
      for (final e in graph)
        if (e.date.isBefore(weekStartDay) &&
            e.date.isAfter(weekStartDay.subtract(const Duration(days: 8))))
          e.minutes,
    ].fold<int>(0, (a, b) => a + b);
    final diff = dashboard.weekMinutes - prevWeek;
    final delta = diff == 0
        ? 'Same as last week'
        : '${diff > 0 ? '+' : '−'}${_formatMinutes(diff.abs())} vs last week';
    final trend = prevWeek <= 0
        ? '—'
        : '${diff >= 0 ? '+' : '−'}${(diff.abs() * 100 / prevWeek).round()}%';

    return ProgressGraph(
      total: _formatMinutes(dashboard.weekMinutes),
      delta: delta,
      trend: trend,
      bars: bars,
    );
  }
}

String _formatMinutes(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
}

String _formatStartMin(int startTimeMin) {
  final hour = startTimeMin ~/ 60;
  final minute = startTimeMin % 60;
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  final suffix = hour < 12 ? 'AM' : 'PM';
  return '$hour12:${minute.toString().padLeft(2, '0')} $suffix';
}

IconData _iconFor(WorkoutCategory category) => switch (category) {
      WorkoutCategory.strength => Icons.fitness_center,
      WorkoutCategory.hiit => Icons.bolt,
      WorkoutCategory.cardio => Icons.directions_run,
      WorkoutCategory.core => Icons.accessibility_new,
      WorkoutCategory.fullBody => Icons.sports,
      WorkoutCategory.mobility => Icons.self_improvement,
    };

/// Loading stand-in shaped like the greeting block, today's session banner
/// and the first two suggestion cards — same paddings as the real content so
/// the swap to loaded data doesn't jump.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
