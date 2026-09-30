import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/di/app_dependencies.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/extensions.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/meal.dart';
import '../../domain/entities/training_plan.dart';
import '../../domain/entities/workout.dart';
import '../../domain/entities/workout_session.dart';
import '../shared/anim/skeleton.dart';
import '../shared/glass_card.dart';
import '../shared/grid_background.dart';
import '../shared/primary_button.dart';
import '../shared/section_header.dart';
import '../shared/status_pill.dart';

/// 12 — Plan tab (sample/index.html): week header + navigation, quick chips,
/// day strip, next session with Start, exercise library, meals and history.
///
/// Data (all real, no demo constants):
/// * week strip + next session ← [PlanRepository] current plan
///   (+ [WorkoutRepository] names for the session card),
/// * library preview ← [ExerciseRepository] catalog (first 3),
/// * meals ← [NutritionRepository] entriesFor(today) + target,
/// * history ← [SessionRepository] recent sessions (expandable, rows open
///   the session summary).
///
/// Tapping a scheduled day (or the calendar icon in the week header) opens
/// the session editor sheet — time, status and rounds persist via
/// [PlanRepository]. The Reminders chip toggles the real daily reminder.
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

/// Everything PLAN renders, resolved once per entry.
class _PlanData {
  const _PlanData({
    required this.plan,
    required this.exercises,
    required this.meals,
    required this.target,
    required this.history,
    required this.workouts,
    required this.exerciseNames,
  });

  final TrainingPlan? plan;
  final List<Exercise> exercises;
  final List<MealEntry> meals;
  final MealTarget? target;
  final List<WorkoutSession> history;

  /// workoutId → resolved workout (session card + history rows).
  final Map<String, Workout> workouts;

  /// exerciseId → display name (session "moves" line).
  final Map<String, String> exerciseNames;
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  late Future<_PlanData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PlanData> _load() async {
    final plan = await ref.read(planRepositoryProvider).currentPlan();

    final exerciseRepo = ref.read(exerciseRepositoryProvider);
    final workoutRepo = ref.read(workoutRepositoryProvider);
    final nutritionRepo = ref.read(nutritionRepositoryProvider);
    final sessionRepo = ref.read(sessionRepositoryProvider);

    List<Exercise> catalog = const [];
    try {
      catalog = await exerciseRepo.catalog();
    } catch (_) {
      catalog = const [];
    }

    final todayKey = DateTime.now().dateKey;
    List<MealEntry> meals = const [];
    try {
      meals = await nutritionRepo.entriesFor(todayKey);
    } catch (_) {
      meals = const [];
    }
    MealTarget? target;
    try {
      target = await nutritionRepo.target();
    } catch (_) {
      target = null;
    }

    List<WorkoutSession> history = const [];
    try {
      // Load enough for the expandable history section (5 shown, rest on tap).
      history = await sessionRepo.history(limit: 100);
    } catch (_) {
      history = const [];
    }

    final workoutIds = <String>{};
    if (plan != null) {
      for (final day in plan.days) {
        for (final session in day.sessions) {
          workoutIds.add(session.workoutId);
        }
      }
    }
    for (final session in history) {
      workoutIds.add(session.workoutId);
    }
    final workouts = <String, Workout>{};
    for (final id in workoutIds) {
      try {
        final workout = await workoutRepo.byId(id);
        if (workout != null) workouts[id] = workout;
      } catch (_) {
        // Leave unresolved — rows fall back to generic titles.
      }
    }

    final exerciseNames = <String, String>{
      for (final exercise in catalog) exercise.id: exercise.name,
    };
    return _PlanData(
      plan: plan,
      exercises: catalog,
      meals: meals,
      target: target,
      history: history,
      workouts: workouts,
      exerciseNames: exerciseNames,
    );
  }

  void _retry() {
    setState(() {
      _future = _load();
    });
  }

  /// Opens the session editor sheet for [session]; persists the result via
  /// [PlanRepository.updateSession] (marks the plan dirty for the sync sweep)
  /// and reloads the screen data.
  Future<void> _editSession(PlanSession session) async {
    final PlanSession? edited = await showModalBottomSheet<PlanSession>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SessionEditorSheet(session: session),
    );
    if (edited == null) return;
    try {
      await ref.read(planRepositoryProvider).updateSession(edited);
    } catch (_) {
      // Persistence failure must not crash the UI; reload still runs.
    }
    if (mounted) _retry();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            child: FutureBuilder<_PlanData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const _PlanSkeleton();
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Could not load your plan',
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
                  );
                }
                final data = snapshot.data!;
                if (data.plan == null) {
                  return _NoPlanState(
                    onBuild: () => context.push('/onboarding'),
                  );
                }
                return _PlanBody(
                  data: data,
                  onEditSession: _editSession,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty state before onboarding generates the first weekly plan.
class _NoPlanState extends StatelessWidget {
  const _NoPlanState({required this.onBuild});

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusPill(label: 'NO PLAN YET', tone: PillTone.neutral, dot: false),
          const SizedBox(height: 10),
          Text(
            'No training plan yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Generate your weekly plan to see sessions, meals and history here.',
            style: TextStyle(fontSize: 12.5, color: p.ink2),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Build my plan',
            icon: Icons.auto_awesome,
            onPressed: onBuild,
          ),
        ],
      ),
    );
  }
}

class _PlanBody extends StatelessWidget {
  const _PlanBody({required this.data, required this.onEditSession});

  final _PlanData data;

  /// Opens the session editor sheet for a scheduled session.
  final ValueChanged<PlanSession> onEditSession;

  @override
  Widget build(BuildContext context) {
    final plan = data.plan!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WeekHeader(
          label: _weekLabelFor(plan),
          onEditSchedule: () {
            // Edit chip opens the editor for today's/next scheduled session.
            final now = DateTime.now();
            final session = _nextEditableSession(plan, now);
            if (session != null) onEditSession(session);
          },
        ),
        const SizedBox(height: 14),
        _PlanChips(source: plan.source),
        const SizedBox(height: 10),
        _WeekStrip(days: plan.days, onDayTap: (day) {
          if (day.sessions.isNotEmpty) onEditSession(day.sessions.first);
        }),
        const SizedBox(height: 20),
        _NextSessionSlot(data: data),
        const SizedBox(height: 20),
        _LibrarySection(exercises: data.exercises),
        const SizedBox(height: 20),
        _MealsSection(meals: data.meals, target: data.target),
        const SizedBox(height: 20),
        _HistorySection(data: data),
      ],
    );
  }
}

/// Today's first session, else the next scheduled one this week.
PlanSession? _nextEditableSession(TrainingPlan plan, DateTime now) {
  final todays = plan.sessionsFor(now);
  if (todays.isNotEmpty) return todays.first;
  for (final day in plan.days) {
    if (day.date.dateKey.compareTo(now.dateKey) > 0 &&
        day.sessions.isNotEmpty) {
      return day.sessions.first;
    }
  }
  return null;
}

String _weekLabelFor(TrainingPlan plan) {
  final days = [...plan.days]
    ..sort((a, b) => a.date.compareTo(b.date));
  final DateTime start = days.isNotEmpty ? days.first.date : plan.weekStart;
  final DateTime end = days.isNotEmpty
      ? days.last.date
      : plan.weekStart.add(const Duration(days: 6));
  final fmt = DateFormat('MMM d');
  return '${fmt.format(start)} – ${fmt.format(end)}';
}

/// Local duplicate of home's start-time helper (no home internals import).
String _formatStartMin(int startTimeMin) {
  final hour = startTimeMin ~/ 60;
  final minute = startTimeMin % 60;
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  final suffix = hour < 12 ? 'AM' : 'PM';
  return '$hour12:${minute.toString().padLeft(2, '0')} $suffix';
}

String _relativeDay(DateTime date) {
  final now = DateTime.now().startOfDay;
  final day = date.startOfDay;
  final diff = now.difference(day).inDays;
  if (diff <= 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '$diff days ago';
}

/// "Training plan" eyebrow + real week range, with the Edit-schedule action.
class _WeekHeader extends StatelessWidget {
  const _WeekHeader({required this.label, required this.onEditSchedule});

  final String label;

  /// Opens the session editor sheet (Edit-schedule affordance).
  final VoidCallback onEditSchedule;

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
                label,
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
        _IconBox(
          Icons.edit_calendar,
          onTap: onEditSchedule,
        ),
      ],
    );
  }
}

/// Glass square icon button (sample `.icon-btn`).
class _IconBox extends StatelessWidget {
  const _IconBox(this.icon, {this.onTap});

  final IconData icon;

  /// When null the icon is display-only; with a callback it acts as a button.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Widget content = Container(
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
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// Quick status chips row: plan source, Edit schedule, Reminders (real
/// toggle backed by [NotificationEngine]).
class _PlanChips extends ConsumerStatefulWidget {
  const _PlanChips({required this.source});

  final PlanSource source;

  @override
  ConsumerState<_PlanChips> createState() => _PlanChipsState();
}

class _PlanChipsState extends ConsumerState<_PlanChips> {
  bool? _remindersOn;

  @override
  void initState() {
    super.initState();
    _refreshReminderState();
  }

  Future<void> _refreshReminderState() async {
    try {
      final enabled =
          await ref.read(notificationEngineProvider).areNotificationsEnabled();
      if (mounted) setState(() => _remindersOn = enabled);
    } catch (_) {
      // Platform channel unavailable (e.g. widget tests) — keep display-only.
    }
  }

  Future<void> _toggleReminders() async {
    final engine = ref.read(notificationEngineProvider);
    final turningOn = !(_remindersOn ?? false);
    try {
      if (turningOn) {
        // Schedule the daily reminder for the next planned session.
        final plan = await ref.read(planRepositoryProvider).currentPlan();
        if (plan == null) return;
        final session = _nextEditableSession(plan, DateTime.now());
        if (session == null) {
          // Nothing scheduled — just make sure nothing is pending.
          await engine.cancelAll();
        } else {
          final workout =
              await ref.read(workoutRepositoryProvider).byId(session.workoutId);
          await engine.scheduleDailyReminder(
            hour: session.startTimeMin ~/ 60,
            minute: session.startTimeMin % 60,
            workoutName: workout?.name ?? 'Your workout',
            workoutId: session.workoutId,
          );
        }
      } else {
        await engine.cancelAll();
      }
    } catch (_) {
      // Notification failures must never break the UI.
    }
    if (mounted) setState(() => _remindersOn = turningOn);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 8,
      children: [
        _Chip(
          label: widget.source == PlanSource.ai ? 'AI generated' : 'Manual plan',
          icon: Icons.auto_awesome,
          selected: true,
        ),
        _Chip(
          label: 'Reminders ${_remindersOn == false ? 'off' : 'on'}',
          icon: _remindersOn == false
              ? Icons.notifications_off
              : Icons.notifications_active,
          onTap: _toggleReminders,
        ),
      ],
    );
  }
}

/// Rounded glass chip (sample `.chip`, `.chip.on`).
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool selected;

  /// When null the chip is display-only; with a callback it acts as a button.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Widget chip = Container(
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
    if (onTap == null) return chip;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: chip,
      ),
    );
  }
}

/// Day strip from the real plan week; today is selected, dots mark days
/// with scheduled sessions (empty days show no dot). Tapping a day with a
/// session opens the session editor.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.days, required this.onDayTap});

  final List<PlanDay> days;

  /// Invoked when a day cell is tapped (only days with sessions act).
  final ValueChanged<PlanDay> onDayTap;

  @override
  Widget build(BuildContext context) {
    final todayKey = DateTime.now().dateKey;
    final letterFmt = DateFormat('E');
    return Row(
      children: [
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) const SizedBox(width: 7),
          Expanded(
            child: _DayCell(
              letter: letterFmt.format(days[i].date)[0],
              date: '${days[i].date.day}',
              hasSession: days[i].sessions.isNotEmpty,
              selected: days[i].date.dateKey == todayKey,
              onTap: days[i].sessions.isNotEmpty
                  ? () => onDayTap(days[i])
                  : null,
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
    this.onTap,
  });

  final String letter;
  final String date;
  final bool hasSession;
  final bool selected;

  /// Non-null only for days with scheduled sessions.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Widget cell = AspectRatio(
      aspectRatio: 1 / 1.25,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? p.selBg : p.glass,
          borderRadius: BorderRadius.circular(15),
          border:
              Border.all(color: selected ? p.selBg : p.border, width: 1.2),
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
                  color: selected ? p.selDot : p.accentDeep,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return cell;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: cell,
      ),
    );
  }
}

/// Next-session slot: today's first planned session, else the next future
/// planned session, else a rest-day card.
class _NextSessionSlot extends StatelessWidget {
  const _NextSessionSlot({required this.data});

  final _PlanData data;

  @override
  Widget build(BuildContext context) {
    final plan = data.plan!;
    final now = DateTime.now();
    final todayKey = now.dateKey;

    PlanSession? chosen;
    DateTime? chosenDate;
    bool isToday = true;

    final todays = plan.sessionsFor(now);
    if (todays.isNotEmpty) {
      final planned = todays.where(
        (s) => s.status == PlanSessionStatus.planned,
      );
      chosen = planned.isNotEmpty ? planned.first : todays.first;
      chosenDate = now;
      isToday = true;
    } else {
      final days = [...plan.days]
        ..sort((a, b) => a.date.compareTo(b.date));
      for (final day in days) {
        if (day.date.dateKey.compareTo(todayKey) > 0 &&
            day.sessions.isNotEmpty) {
          final planned = day.sessions.where(
            (s) => s.status == PlanSessionStatus.planned,
          );
          chosen = planned.isNotEmpty ? planned.first : day.sessions.first;
          chosenDate = day.date;
          isToday = false;
          break;
        }
      }
    }

    if (chosen == null || chosenDate == null) {
      return const _RestDayCard();
    }
    final workout = data.workouts[chosen.workoutId];
    final time = _formatStartMin(chosen.startTimeMin);
    final pill = isToday ? time : '${DateFormat('EEE').format(chosenDate)} · $time';
    final firstExercise = (workout?.blocks.isNotEmpty ?? false)
        ? workout!.blocks.first.exerciseId
        : null;
    return _NextSessionCard(
      timeLabel: pill,
      title: workout?.name ?? 'Planned session',
      moves: _movesLine(workout, data.exerciseNames),
      onStart: () =>
          context.push('/vision${firstExercise == null ? '' : '?ex=$firstExercise'}'),
    );
  }
}

String _movesLine(Workout? workout, Map<String, String> exerciseNames) {
  if (workout == null) return 'Scheduled session';
  final seen = <String>[];
  for (final block in workout.blocks) {
    final name = exerciseNames[block.exerciseId] ?? block.exerciseId;
    if (!seen.contains(name)) seen.add(name);
    if (seen.length == 4) break;
  }
  if (seen.isEmpty) {
    return '${workout.blocks.length} moves · about ${workout.durationMin} min';
  }
  return seen.join(' · ');
}

/// Rest-day fallback when no planned sessions remain this week.
class _RestDayCard extends StatelessWidget {
  const _RestDayCard();

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
                StatusPill(
                  label: 'REST DAY',
                  tone: PillTone.neutral,
                  dot: false,
                ),
                const SizedBox(height: 8),
                Text(
                  'No sessions scheduled',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Enjoy recovery — or browse the library',
                  style: TextStyle(fontSize: 11.5, color: p.ink3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PrimaryButton(
            label: 'Browse',
            icon: Icons.fitness_center,
            expand: false,
            onPressed: () => context.go('/workout'),
          ),
        ],
      ),
    );
  }
}

/// Today's/next session card with the Start CTA (sample `.btn`).
class _NextSessionCard extends StatelessWidget {
  const _NextSessionCard({
    required this.timeLabel,
    required this.title,
    required this.moves,
    required this.onStart,
  });

  final String timeLabel;
  final String title;
  final String moves;
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
                StatusPill(label: timeLabel, tone: PillTone.green),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  moves,
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

/// Horizontal "Exercise library" carousel from the bundled catalog.
class _LibrarySection extends StatelessWidget {
  const _LibrarySection({required this.exercises});

  final List<Exercise> exercises;

  @override
  Widget build(BuildContext context) {
    final preview = exercises.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Exercise library',
          actionLabel: preview.isEmpty ? null : 'See all',
          onAction: preview.isEmpty ? null : () => context.go('/workout'),
        ),
        const SizedBox(height: 10),
        if (preview.isEmpty)
          const _LibraryEmpty()
        else
          SizedBox(
            height: 138,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < preview.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  _LibraryCard(exercise: preview[i], toneIndex: i % 3),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _LibraryEmpty extends StatelessWidget {
  const _LibraryEmpty();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GlassCard(
      child: Text(
        'Exercise library is empty on this device.',
        style: TextStyle(fontSize: 12.5, color: p.ink2),
      ),
    );
  }
}

/// One exercise preview card: gradient thumbnail + name + muscle/cues meta.
class _LibraryCard extends StatelessWidget {
  const _LibraryCard({required this.exercise, required this.toneIndex});

  final Exercise exercise;
  final int toneIndex;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (colors, glyphColor) = switch (toneIndex) {
      0 => ([p.ink3, p.ink2], p.selFg),
      1 => ([p.accentSoft, p.accentDeep], p.selBg),
      _ => ([p.trackStrong, p.selBg], p.selFg),
    };
    final muscle = exercise.primaryMuscles.isNotEmpty
        ? exercise.primaryMuscles.first.label
        : 'General';
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
              child: Icon(
                _iconForMuscle(exercise.primaryMuscles),
                size: 38,
                color: glyphColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            exercise.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$muscle · ${exercise.formCues.length} cues',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: p.ink3),
          ),
        ],
      ),
    );
  }
}

IconData _iconForMuscle(List<MuscleGroup> muscles) {
  if (muscles.isEmpty) return Icons.fitness_center;
  return switch (muscles.first) {
    MuscleGroup.chest => Icons.fitness_center,
    MuscleGroup.back => Icons.sports,
    MuscleGroup.legs => Icons.directions_run,
    MuscleGroup.glutes => Icons.directions_walk,
    MuscleGroup.shoulders => Icons.accessibility_new,
    MuscleGroup.arms => Icons.front_hand,
    MuscleGroup.core => Icons.self_improvement,
    MuscleGroup.cardio => Icons.bolt,
    MuscleGroup.fullBody => Icons.sports,
    MuscleGroup.mobility => Icons.self_improvement,
  };
}

/// "Meals today": kcal card with progress bar + per-type tiles from real entries.
class _MealsSection extends StatelessWidget {
  const _MealsSection({required this.meals, required this.target});

  final List<MealEntry> meals;
  final MealTarget? target;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final trackWidth = MediaQuery.sizeOf(context).width - 72;
    final eaten = meals.fold<int>(0, (sum, e) => sum + e.calories);
    final goal = target?.dailyCalories ?? 2000;
    final remaining = goal - eaten;
    final progress = goal <= 0 ? 0.0 : (eaten / goal).clamp(0.0, 1.0);
    final numbers = NumberFormat.decimalPattern();
    final remainingCopy = remaining >= 0
        ? '${numbers.format(remaining)} kcal remaining'
        : '${numbers.format(remaining.abs())} kcal over goal';

    final totals = <MealType, int>{};
    for (final entry in meals) {
      totals[entry.mealType] = (totals[entry.mealType] ?? 0) + entry.calories;
    }
    const order = [
      MealType.breakfast,
      MealType.lunch,
      MealType.dinner,
      MealType.snack,
    ];
    final present = [
      for (final type in order)
        if (totals.containsKey(type)) type,
    ].take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Expanded(child: SectionHeader(title: 'Meals today')),
            _LinkLabel('Log meal'),
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
                              numbers.format(eaten),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: p.ink,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '/ ${numbers.format(goal)} kcal',
                              style: TextStyle(fontSize: 12.5, color: p.ink2),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          meals.isEmpty
                              ? 'No meals logged yet'
                              : remainingCopy,
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
                    width: trackWidth * progress,
                    height: 9,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [p.accentSoft, p.accentDeep],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (present.isEmpty)
          GlassCard(
            child: Text(
              'Log your first meal to track today\u2019s calories.',
              style: TextStyle(fontSize: 12.5, color: p.ink2),
            ),
          )
        else
          Row(
            children: [
              for (var i = 0; i < present.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: _MealTile(
                    type: present[i],
                    calories: totals[present[i]]!,
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

/// Compact per-meal row (sample `.grid2 .lrow`).
class _MealTile extends StatelessWidget {
  const _MealTile({required this.type, required this.calories});

  final MealType type;
  final int calories;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final numbers = NumberFormat.decimalPattern();
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
            _mealIcon(type),
            size: 20,
            color: type == MealType.breakfast
                ? p.amberPillFg
                : p.accentDeep,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${numbers.format(calories)} kcal',
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

IconData _mealIcon(MealType type) => switch (type) {
      MealType.breakfast => Icons.breakfast_dining,
      MealType.lunch => Icons.lunch_dining,
      MealType.dinner => Icons.dinner_dining,
      MealType.snack => Icons.cookie,
    };

/// Recent sessions list (sample `.list .lrow` + `.idx`) — expandable when
/// more than five sessions exist; rows open the session summary.
class _HistorySection extends StatefulWidget {
  const _HistorySection({required this.data});

  final _PlanData data;

  @override
  State<_HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends State<_HistorySection> {
  /// False shows the latest 5; true shows the full loaded history.
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final p = context.palette;
    final numbers = NumberFormat.decimalPattern();
    final visible = _expanded ? data.history : data.history.take(5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SectionHeader(title: 'History')),
            if (data.history.length > 5)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: _LinkLabel(_expanded ? 'Show less' : 'View all'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (data.history.isEmpty)
          GlassCard(
            child: Text(
              'No sessions yet — your completed workouts will appear here.',
              style: TextStyle(fontSize: 12.5, color: p.ink2),
            ),
          )
        else
          for (final session in visible) ...[
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () =>
                    context.push('/summary?session=${Uri.encodeComponent(session.id)}'),
                child: Container(
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
                      color: p.accentSoft,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      Icons.check,
                      size: 14,
                      color: p.accentDeep,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.workouts[session.workoutId]?.name ?? 'Workout',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: p.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_relativeDay(session.startedAt)} · '
                          '${numbers.format(session.totalReps)} reps · '
                          'form ${session.formAccuracyPct.round()}%',
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
              ),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

/// Accent section action copy (sample `.link`) — tap target for expand/collapse.
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

/// Loading stand-in: week-header/chip/strip stubs plus three card rows,
/// using the real paddings so the swap to loaded data doesn't jump.
class _PlanSkeleton extends StatelessWidget {
  const _PlanSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkeletonText(width: 96),
          SizedBox(height: 6),
          SkeletonBox(width: 168, height: 24, radius: 8),
          SizedBox(height: 14),
          Row(
            children: [
              SkeletonBox(width: 108, height: 36, radius: 999),
              SizedBox(width: 7),
              SkeletonBox(width: 98, height: 36, radius: 999),
              SizedBox(width: 7),
              SkeletonBox(width: 94, height: 36, radius: 999),
            ],
          ),
          SizedBox(height: 16),
          SkeletonBox(height: 54, radius: 15),
          SizedBox(height: 20),
          _SkeletonPlanRow(),
          SizedBox(height: 20),
          _SkeletonPlanRow(),
          SizedBox(height: 20),
          _SkeletonPlanRow(),
        ],
      ),
    );
  }
}

/// One card-shaped loading row: pill + title line + meta line.
class _SkeletonPlanRow extends StatelessWidget {
  const _SkeletonPlanRow();

  @override
  Widget build(BuildContext context) {
    return const GlassCard(
      weak: true,
      padding: EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 76, height: 24, radius: 12),
          SizedBox(height: 10),
          SkeletonBox(width: 192, height: 18, radius: 8),
          SizedBox(height: 6),
          SkeletonText(width: 244),
        ],
      ),
    );
  }
}

/// Session editor sheet — time, status and rounds for one scheduled session.
///
/// Returns the edited [PlanSession] via `Navigator.pop` (null when closed
/// without saving). Persistence happens in the screen via
/// [PlanRepository.updateSession].
class _SessionEditorSheet extends StatefulWidget {
  const _SessionEditorSheet({required this.session});

  final PlanSession session;

  @override
  State<_SessionEditorSheet> createState() => _SessionEditorSheetState();
}

class _SessionEditorSheetState extends State<_SessionEditorSheet> {
  late PlanSessionStatus _status = widget.session.status;
  late int _startMin = widget.session.startTimeMin;
  late int _rounds = widget.session.roundsOverride ?? 0;
  late bool _overrideRounds = widget.session.roundsOverride != null;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: p.solid,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: p.border, width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit session',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: p.ink,
              ),
            ),
            const SizedBox(height: 14),
            // -- Time --
            _EditorRow(
              icon: Icons.schedule,
              label: 'Start time',
              value: _formatStartMin(_startMin),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime:
                      TimeOfDay(hour: _startMin ~/ 60, minute: _startMin % 60),
                );
                if (picked != null) {
                  setState(() {
                    _startMin = picked.hour * 60 + picked.minute;
                  });
                }
              },
            ),
            const SizedBox(height: 10),
            // -- Status --
            Text(
              'Status',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: p.ink2,
              ),
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 7,
              runSpacing: 8,
              children: [
                for (final status in PlanSessionStatus.values)
                  _Chip(
                    label: switch (status) {
                      PlanSessionStatus.planned => 'Planned',
                      PlanSessionStatus.done => 'Done',
                      PlanSessionStatus.skipped => 'Skipped',
                    },
                    icon: switch (status) {
                      PlanSessionStatus.planned => Icons.event,
                      PlanSessionStatus.done => Icons.check,
                      PlanSessionStatus.skipped => Icons.skip_next,
                    },
                    selected: _status == status,
                    onTap: () => setState(() => _status = status),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            // -- Rounds override --
            _EditorRow(
              icon: Icons.repeat,
              label: 'Rounds override',
              value: _overrideRounds ? '$_rounds' : 'Default',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RoundButton(
                    icon: Icons.remove,
                    onTap: () => setState(() {
                      if (_overrideRounds && _rounds > 1) _rounds--;
                    }),
                  ),
                  const SizedBox(width: 8),
                  _RoundButton(
                    icon: _overrideRounds ? Icons.add : Icons.edit,
                    onTap: () => setState(() {
                      if (_overrideRounds) {
                        _rounds++;
                      } else {
                        _overrideRounds = true;
                        _rounds = 1;
                      }
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(
                    label: 'Save',
                    icon: Icons.check,
                    onPressed: () => Navigator.of(context).pop(
                      widget.session.copyWith(
                        startTimeMin: _startMin,
                        status: _status,
                        roundsOverride:
                            _overrideRounds ? _rounds : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One editor row: icon + label + value (+ optional trailing controls).
class _EditorRow extends StatelessWidget {
  const _EditorRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Widget row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border, width: 1.2),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: p.accentDeep),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: p.ink,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 12.5, color: p.ink2),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: row,
      ),
    );
  }
}

/// Small round +/- control inside the editor.
class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.accentSoft,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, size: 16, color: p.accentDeep),
        ),
      ),
    );
  }
}
