import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/di/app_dependencies.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/extensions.dart';
import '../../domain/entities/meal.dart';
import '../../domain/entities/workout_session.dart';
import '../shared/app_back_button.dart';
import '../shared/glass_card.dart';
import '../shared/grid_background.dart';

/// Log page — one chronological feed of everything the user did: workout
/// sessions and meals, grouped by day (trailing 30 days) with per-day totals.
class LogScreen extends ConsumerStatefulWidget {
  const LogScreen({super.key});

  @override
  ConsumerState<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends ConsumerState<LogScreen> {
  static const int _windowDays = 30;

  Future<_LogData>? _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_LogData> _load() async {
    final from =
        DateTime.now().subtract(const Duration(days: _windowDays - 1));
    final sessions = await ref
        .read(sessionRepositoryProvider)
        .history(limit: 100);
    final meals =
        await ref.read(nutritionRepositoryProvider).entriesBetween(
              from,
              DateTime.now(),
            );
    final library = await ref.read(workoutRepositoryProvider).library();

    final windowSessions = sessions
        .where((s) =>
            s.status == SessionStatus.completed &&
            !s.startedAt.isBefore(from.startOfDay))
        .toList();
    final names = {for (final w in library) w.id: w.name};

    // Group by local day bucket (newest first).
    final groups = <String, _DayGroup>{};
    _DayGroup forDay(String key) =>
        groups.putIfAbsent(key, () => _DayGroup());
    for (final s in windowSessions) {
      forDay(s.startedAt.dateKey).sessions.add(s);
    }
    for (final m in meals) {
      forDay(m.dateKey).meals.add(m);
    }
    final keys = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    return _LogData(keys: keys, groups: groups, names: names);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
                child: Row(
                  children: [
                    const AppBackButton(fallback: '/plan'),
                    Expanded(
                      child: Text(
                        'Activity log',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: p.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Log a meal',
                      onPressed: () => context.push('/meal'),
                      icon: Icon(Icons.add, size: 22, color: p.ink),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<_LogData>(
                  future: _data,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Text(
                          'Could not load the log.',
                          style: TextStyle(fontSize: 13, color: p.ink3),
                        ),
                      );
                    }
                    final data = snap.data!;
                    if (data.keys.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Nothing logged in the last $_windowDays days yet.\n'
                            'Complete a session or log a meal to fill this page.',
                            textAlign: TextAlign.center,
                            style:
                                TextStyle(fontSize: 13, color: p.ink3),
                          ),
                        ),
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                      children: [
                        for (final key in data.keys) ...[
                          _dayHeader(p, key, data.groups[key]!),
                          const SizedBox(height: 8),
                          _dayCard(p, key, data.groups[key]!, data.names),
                          const SizedBox(height: 16),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dayLabel(String dateKey) {
    final date = DateTime.parse(dateKey);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(DateTime(date.year, date.month, date.day)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEEE, d MMM yyyy').format(date);
  }

  Widget _dayHeader(AppPalette p, String dateKey, _DayGroup group) {
    final kcal = group.meals.fold<int>(0, (sum, m) => sum + m.calories);
    final parts = <String>[
      if (kcal > 0) '$kcal kcal',
      if (group.sessions.isNotEmpty)
        '${group.sessions.length} session${group.sessions.length == 1 ? '' : 's'}',
    ];
    return Row(
      children: [
        Expanded(
          child: Text(
            _dayLabel(dateKey),
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: p.ink,
            ),
          ),
        ),
        if (parts.isNotEmpty)
          Text(
            parts.join(' · '),
            style: TextStyle(fontSize: 11.5, color: p.ink3),
          ),
      ],
    );
  }

  Widget _dayCard(
    AppPalette p,
    String dateKey,
    _DayGroup group,
    Map<String, String> names,
  ) {
    final dayStart = DateTime.parse(dateKey).millisecondsSinceEpoch;
    final events = <_Event>[
      for (final m in group.meals)
        _Event(millis: m.timeMillis ?? dayStart, meal: m),
      for (final s in group.sessions)
        _Event(millis: s.startedAt.millisecondsSinceEpoch, session: s),
    ]..sort((a, b) => b.millis.compareTo(a.millis));

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        children: [
          for (final e in events) ...[
            if (e.meal != null) _mealRow(p, e.meal!) else _sessionRow(p, e.session!, names),
            if (e != events.last)
              Divider(height: 12, color: p.line, thickness: 0.6),
          ],
        ],
      ),
    );
  }

  Widget _mealRow(AppPalette p, MealEntry m) => Row(
        children: [
          Icon(_mealIcon(m.mealType), size: 17, color: p.ink2),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: p.ink),
                ),
                Text(
                  '${m.mealType.label}'
                  '${m.time == null ? '' : ' · ${DateFormat('h:mm a').format(m.time!)}'}',
                  style: TextStyle(fontSize: 11, color: p.ink3),
                ),
              ],
            ),
          ),
          Text(
            '${m.calories} kcal',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: p.ink,
            ),
          ),
        ],
      );

  Widget _sessionRow(
    AppPalette p,
    WorkoutSession s,
    Map<String, String> names,
  ) =>
      InkWell(
        onTap: () => context.push('/summary?session=${s.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.fitness_center, size: 17),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      names[s.workoutId] ?? s.workoutId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                    Text(
                      '${(s.durationSec / 60).round()} min · '
                      '${s.totalReps} reps · '
                      '${s.formAccuracyPct.round()}% form',
                      style: TextStyle(fontSize: 11, color: p.ink3),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: p.ink3),
            ],
          ),
        ),
      );

  IconData _mealIcon(MealType t) => switch (t) {
        MealType.breakfast => Icons.free_breakfast,
        MealType.lunch => Icons.restaurant,
        MealType.dinner => Icons.dinner_dining,
        MealType.snack => Icons.cookie,
      };
}

class _DayGroup {
  final meals = <MealEntry>[];
  final sessions = <WorkoutSession>[];
}

class _Event {
  const _Event({required this.millis, this.meal, this.session});

  final int millis;
  final MealEntry? meal;
  final WorkoutSession? session;
}

class _LogData {
  const _LogData({
    required this.keys,
    required this.groups,
    required this.names,
  });

  final List<String> keys;
  final Map<String, _DayGroup> groups;
  final Map<String, String> names;
}
