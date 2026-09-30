import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/di/app_dependencies.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/workout_session.dart';
import '../shared/anim/skeleton.dart';
import '../shared/glass_card.dart';
import '../shared/grid_background.dart';
import '../shared/primary_button.dart';
import '../shared/section_header.dart';
import '../shared/status_pill.dart';

/// 11 — Session summary: completion headline, result stats, per-exercise
/// breakdown, streak banner and the exit actions.
///
/// Data: resolved [WorkoutSession] (route id, else newest from history) +
/// real display names from the bundled exercise catalog + a 30-day streak
/// computed from [SessionRepository.sessionsBetween] — no demo constants.
class SessionSummaryScreen extends ConsumerStatefulWidget {
  const SessionSummaryScreen({super.key, this.sessionId});

  final String? sessionId;

  @override
  ConsumerState<SessionSummaryScreen> createState() => _SessionSummaryScreenState();
}

/// Everything the summary renders, resolved once per entry.
class _SummaryData {
  const _SummaryData({
    required this.session,
    required this.workoutName,
    required this.activeDays,
    required this.exerciseNames,
  });

  final WorkoutSession session;

  /// Catalog name of the session's workout (null → fall back to the raw id).
  final String? workoutName;

  /// Date-only `startedAt` of completed sessions inside the last 30 days —
  /// the streak source.
  final Set<DateTime> activeDays;

  /// Exercise id → catalog display name, for the breakdown rows.
  final Map<String, String> exerciseNames;
}

class _SessionSummaryScreenState extends ConsumerState<SessionSummaryScreen> {
  late final Future<_SummaryData?> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<_SummaryData?> _load() async {
    final repo = ref.read(sessionRepositoryProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Route id wins; otherwise the newest session in history.
    final history = await repo.history(limit: 100);
    WorkoutSession? session;
    if (widget.sessionId != null) {
      for (final s in history) {
        if (s.id == widget.sessionId) {
          session = s;
          break;
        }
      }
    } else {
      session = history.isEmpty ? null : history.first;
    }
    if (session == null) return null;

    // Streak source: completed sessions across the last 30 days (inclusive).
    // A failed read only costs the streak — it must not fail the summary.
    var activeDays = const <DateTime>{};
    try {
      final window = await repo.sessionsBetween(
        today.subtract(const Duration(days: 29)),
        today.add(const Duration(days: 1)),
      );
      activeDays = {
        for (final s in window)
          if (s.status == SessionStatus.completed)
            DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day),
      };
    } catch (_) {
      activeDays = const {};
    }

    String? workoutName;
    try {
      workoutName = (await ref.read(workoutRepositoryProvider).byId(session.workoutId))?.name;
    } catch (_) {
      // Fall back to the raw workout id.
    }

    var exerciseNames = const <String, String>{};
    try {
      final catalog = await ref.read(exerciseRepositoryProvider).catalog();
      exerciseNames = {for (final e in catalog) e.id: e.name};
    } catch (_) {
      // Fall back to prettified ids in the breakdown rows.
    }

    return _SummaryData(
      session: session,
      workoutName: workoutName,
      activeDays: activeDays,
      exerciseNames: exerciseNames,
    );
  }

  void _retry() => setState(() => _dataFuture = _load());

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: FutureBuilder<_SummaryData?>(
            future: _dataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return _buildSkeleton(p);
              }
              if (snapshot.hasError) {
                return _buildError(p);
              }
              final data = snapshot.data;
              if (data == null) {
                return _buildEmpty(p);
              }
              return _buildContent(context, data, p);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton(AppPalette p) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 30, 18, 26),
      children: [
        const Shimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SkeletonBox(width: 74, height: 74, radius: 37),
              SizedBox(height: 14),
              SkeletonText(width: 180),
              SizedBox(height: 5),
              SkeletonText(width: 140),
              SizedBox(height: 14),
              SkeletonBox(width: double.infinity, height: 28, radius: 8),
              SizedBox(height: 20),
            ],
          ),
        ),
        const Shimmer(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: SkeletonBox(height: 80, radius: 20)),
                  SizedBox(width: 10),
                  Expanded(child: SkeletonBox(height: 80, radius: 20)),
                ],
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: SkeletonBox(height: 80, radius: 20)),
                  SizedBox(width: 10),
                  Expanded(child: SkeletonBox(height: 80, radius: 20)),
                ],
              ),
              SizedBox(height: 10),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Shimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonText(width: 80),
              SizedBox(height: 10),
              SkeletonBox(height: 70, radius: 18),
              SizedBox(height: 10),
              SkeletonBox(height: 70, radius: 18),
              SizedBox(height: 10),
              SkeletonBox(height: 70, radius: 18),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Shimmer(
          child: SkeletonBox(height: 80, radius: 18),
        ),
        const SizedBox(height: 20),
        const Shimmer(
          child: Row(
            children: [
              Expanded(flex: 10, child: SkeletonBox(height: 48, radius: 999)),
              SizedBox(width: 10),
              Expanded(flex: 14, child: SkeletonBox(height: 48, radius: 999)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildError(AppPalette p) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 30, 18, 26),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Could not load session',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: p.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Something went wrong — your data stays on this device.',
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

  Widget _buildEmpty(AppPalette p) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 30, 18, 26),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.history, size: 48, color: p.ink2),
              const SizedBox(height: 12),
              Text(
                'No session yet',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: p.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Complete a workout to see your summary here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: p.ink2),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'Back to home',
                icon: Icons.home,
                onPressed: () => context.go('/home'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, _SummaryData data, AppPalette p) {
    final session = data.session;
    final completed = session.status == SessionStatus.completed;
    final streak = _computeStreak(data.activeDays);
    final totalRounds =
        session.exercises.fold<int>(0, (sum, e) => sum + e.roundsCompleted);
    final duration = _formatDuration(session.durationSec);
    final cadence = session.totalReps > 0 && session.durationSec > 0
        ? '${(session.durationSec / session.totalReps).toStringAsFixed(1)}s'
        : '—';
    final formPct = session.formAccuracyPct.round();
    final workoutLabel = data.workoutName ?? _prettyId(session.workoutId);

    return ListView(
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
          child: Icon(
            completed ? Icons.check : Icons.flag,
            size: 40,
            color: p.accentDeep,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          switch (session.status) {
            SessionStatus.completed => 'Session complete',
            SessionStatus.abandoned => 'Workout ended',
            _ => 'Session in progress',
          },
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
          '$workoutLabel · ${_formatDate(session.startedAt)} · '
          '$totalRounds round${totalRounds == 1 ? '' : 's'}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: p.ink2),
        ),
        const SizedBox(height: 20),
        // ---- Stats grid (all from the session entity) ----
        Row(
          children: [
            Expanded(
              child: _StatCard(
                value: '${session.totalReps}',
                label: 'Total reps',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                value: '$formPct%',
                label: 'Avg form',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                value: duration,
                label: 'Duration',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                value: cadence,
                label: 'Avg time / rep',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const SectionHeader(title: 'Breakdown'),
        const SizedBox(height: 10),
        // ---- Per-exercise breakdown (only what the session recorded) ----
        for (final ex in session.exercises) ...[
          _BreakdownRow(
            exerciseId: ex.exerciseId,
            name: data.exerciseNames[ex.exerciseId] ?? _prettyId(ex.exerciseId),
            rounds: ex.roundsCompleted,
            reps: ex.totalReps,
            formPct: ex.formAccuracyPct.round(),
            avgRepSec: _avgPerRepTime(ex.perRepTimesSec),
          ),
          const SizedBox(height: 10),
        ],
        if (session.exercises.isEmpty)
          _BreakdownRow(
            exerciseId: session.workoutId,
            name: workoutLabel,
            reps: session.totalReps,
            formPct: formPct,
          ),
        const SizedBox(height: 4),
        // ---- Streak banner (real consecutive days, last 30) ----
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(
                Icons.local_fire_department,
                size: 24,
                color: streak > 0 ? AppColors.amber : p.ink3,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      streak == 0
                          ? 'Start a streak today'
                          : streak == 1
                              ? '1 day streak — keep it going'
                              : '$streak day streak — keep it going',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      streak == 0
                          ? (data.activeDays.isEmpty
                              ? 'No workouts in the last 30 days — '
                                  'your first one starts the streak'
                              : 'Last workout '
                                  '${_daysSinceLast(data.activeDays)} days ago — '
                                  'start a new streak')
                          : '${data.activeDays.length} active '
                              '${data.activeDays.length == 1 ? 'day' : 'days'} '
                              'in the last 30 days',
                      style: TextStyle(fontSize: 11.5, color: p.ink3),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: streak > 0
                    ? (streak == 1 ? '1 day' : '$streak days')
                    : 'Start',
                tone: streak > 0 ? PillTone.green : PillTone.amber,
                dot: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // ---- Actions ----
        Row(
          children: [
            Expanded(
              flex: 10,
              child: SecondaryButton(
                label: 'Share',
                icon: Icons.share,
                onPressed: () => _shareSession(data),
              ),
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
    );
  }

  /// Consecutive-day streak over the last 30 days: today or yesterday anchors
  /// the streak (either counts as active), then every earlier day with a
  /// completed session extends it.
  int _computeStreak(Set<DateTime> activeDays) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final cursor = activeDays.contains(today)
        ? today
        : activeDays.contains(yesterday)
            ? yesterday
            : null;
    if (cursor == null) return 0;

    var streak = 1;
    var day = cursor;
    // 28 more steps back keeps the walk inside the 30-day window
    // (yesterday - 28d = today - 29d).
    for (var i = 0; i < 28; i++) {
      day = day.subtract(const Duration(days: 1));
      if (!activeDays.contains(day)) break;
      streak++;
    }
    return streak;
  }

  /// Whole days since the most recent active day (activeDays non-empty).
  int _daysSinceLast(Set<DateTime> activeDays) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var latest = activeDays.first;
    for (final d in activeDays) {
      if (d.isAfter(latest)) latest = d;
    }
    return today.difference(latest).inDays;
  }

  /// Average seconds between consecutive reps (null when not recorded).
  double? _avgPerRepTime(List<double> perRepTimesSec) {
    if (perRepTimesSec.isEmpty) return null;
    final sum = perRepTimesSec.fold<double>(0, (a, b) => a + b);
    return sum / perRepTimesSec.length;
  }

  /// mm:ss, or h:mm past the hour.
  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) return '$hours:${minutes.toString().padLeft(2, '0')}';
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Short date, e.g. "Oct 1".
  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  /// "side_lunge" → "Side lunge" (fallback when the catalog name is missing).
  String _prettyId(String id) {
    final words = id.replaceAll('_', ' ');
    if (words.isEmpty) return words;
    return '${words[0].toUpperCase()}${words.substring(1)}';
  }

  void _shareSession(_SummaryData data) {
    final session = data.session;
    final text = 'FixPose workout 💪\n\n'
        '${data.workoutName ?? _prettyId(session.workoutId)} · '
        '${_formatDate(session.startedAt)}\n'
        '• ${_formatDuration(session.durationSec)} total\n'
        '• ${session.totalReps} reps\n'
        '• ${session.formAccuracyPct.round()}% avg form accuracy\n\n'
        '#FixPose #Fitness';
    SharePlus.instance.share(ShareParams(text: text));
  }
}

/// Glass result tile.
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

/// One recorded exercise row with its real numbers and a form-accuracy bar.
class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.exerciseId,
    required this.name,
    required this.reps,
    required this.formPct,
    this.rounds = 0,
    this.avgRepSec,
  });

  final String exerciseId;
  final String name;
  final int rounds;
  final int reps;

  /// Rounded 0..100 form accuracy for this exercise.
  final int formPct;

  /// Average seconds between reps, when the session recorded them.
  final double? avgRepSec;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final formFraction = (formPct / 100).clamp(0.0, 1.0);
    final metaParts = <String>[
      if (rounds > 0) '$rounds round${rounds == 1 ? '' : 's'}',
      if (reps > 0) '$reps rep${reps == 1 ? '' : 's'}',
      if (avgRepSec != null) '${avgRepSec!.toStringAsFixed(1)}s / rep',
      if (formPct > 0) 'form $formPct%',
    ];

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 18,
      child: Row(
        children: [
          _Thumb(exerciseId: exerciseId, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 2),
                if (metaParts.isNotEmpty)
                  Text(
                    metaParts.join(' · '),
                    style: TextStyle(fontSize: 11.5, color: p.ink3),
                  ),
                const SizedBox(height: 7),
                _ProgressBar(value: formFraction),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin gradient progress bar.
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

/// Exercise thumbnail with gradient based on exercise type.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.exerciseId, this.size = 56});

  final String exerciseId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = _thumbStyleFor(exerciseId);
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
      child: Icon(
        _iconFor(exerciseId),
        size: size * 0.46,
        color: Colors.white.withAlpha(235),
      ),
    );
  }

  _ThumbStyle _thumbStyleFor(String id) {
    // Map exercise IDs to styles consistently
    final hash = id.codeUnits.fold<int>(0, (a, b) => a + b);
    return _ThumbStyle.values[hash % _ThumbStyle.values.length];
  }

  IconData _iconFor(String id) {
    switch (id) {
      case 'squat':
      case 'lunge':
      case 'side_lunge':
      case 'wall_sit':
      case 'glute_bridge':
      case 'deadlift':
      case 'calf_raise':
        return Icons.fitness_center;
      case 'push_up':
      case 'tricep_dip':
      case 'shoulder_press':
      case 'bicep_curl':
      case 'hammer_curl':
      case 'lateral_raise':
        return Icons.accessibility_new;
      case 'jumping_jack':
      case 'high_knees':
      case 'mountain_climber':
        return Icons.directions_run;
      case 'plank':
      case 'leg_raise':
        return Icons.self_improvement;
      default:
        return Icons.sports_gymnastics;
    }
  }
}

enum _ThumbStyle { slate, green, dark }
