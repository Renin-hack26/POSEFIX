import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/di/app_dependencies.dart';
import '../../core/search/library_search.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/extensions.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/meal.dart';
import '../../domain/entities/training_plan.dart';
import '../../domain/entities/workout.dart';
import '../../domain/entities/workout_session.dart';
import '../shared/glass_card.dart';
import '../shared/grid_background.dart';
import '../shared/primary_button.dart';
import '../shared/section_header.dart';
import '../shared/status_pill.dart';

/// 12 · Plan tab (sample/index.html): week header + navigation, quick chips,
/// day strip, next session with Start, exercise library, meals and history.
///
/// Data (all real, no demo constants):
/// * week strip + next session ? [PlanRepository] current plan
///   (+ [WorkoutRepository] names for the session card),
/// * library preview ? [ExerciseRepository] catalog (first 3),
/// * meals ? [NutritionRepository] entriesFor(today) + target,
/// * history ? [SessionRepository] recent sessions (expandable, rows open
///   the session summary).
///
/// Tapping any date in the day strip selects it (ongoing week only) · the
/// slot below then shows that day's full set of workouts, past or upcoming.
/// Tapping a session card (or the calendar icon in the week header) opens
/// the session editor sheet · time, status and rounds persist via
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

  /// workoutId ? resolved workout (session card + history rows).
  final Map<String, Workout> workouts;

  /// exerciseId ? display name (session "moves" line).
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
        // Leave unresolved · rows fall back to generic titles.
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
    // Meals (and target) are resolved once per entry in initState — but the
    // Plan screen's own "Log meal" link pushes /meal ON TOP of this tab, so
    // returning used to show the stale snapshot ("No meals logged yet" right
    // after logging). Reload whenever today's nutrition data changes.
    ref.listen(mealsRevisionProvider, (previous, next) {
      if (previous != next) setState(() => _future = _load());
    });
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
                          'Check your connection and try again · '
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

class _PlanBody extends StatefulWidget {
  const _PlanBody({required this.data, required this.onEditSession});

  final _PlanData data;

  /// Opens the session editor sheet for a scheduled session.
  final ValueChanged<PlanSession> onEditSession;

  @override
  State<_PlanBody> createState() => _PlanBodyState();
}

class _PlanBodyState extends State<_PlanBody> {
  /// Highlighted day-strip date (dateKey · ongoing week only). Null until
  /// the user taps a date → auto-default below.
  String? _selectedKey;

  /// Floor height reserved for the day-slot region = the rest card's natural
  /// height. Measured once after the first frame (so it follows the system
  /// font scale) and then held constant: every day reserves at least this
  /// much space, so the sections below the slot keep their y-position when
  /// the selected day swaps between rest and sessions. Null until measured
  /// (the very first frame lays out naturally).
  double? _slotFloor;

  /// Offstage reference rest card used to measure [_slotFloor]: laid out at
  /// the slot's width, but never painted, never hit-testable and taking no
  /// layout space of its own.
  final GlobalKey _slotFloorKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureSlotFloor());
  }

  void _measureSlotFloor() {
    if (!mounted || _slotFloor != null) return;
    final renderObject = _slotFloorKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    setState(() => _slotFloor = renderObject.size.height);
  }

  /// Auto-selection: today when it has sessions, else the next upcoming day
  /// with sessions (preserves the original "next slot" default), else today
  /// (renders the rest card).
  String _autoSelectedKey(TrainingPlan plan, DateTime now) {
    if (plan.sessionsFor(now).isNotEmpty) return now.dateKey;
    final days = [...plan.days]..sort((a, b) => a.date.compareTo(b.date));
    for (final day in days) {
      if (day.date.dateKey.compareTo(now.dateKey) > 0 &&
          day.sessions.isNotEmpty) {
        return day.date.dateKey;
      }
    }
    return now.dateKey;
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.data.plan!;
    final now = DateTime.now();
    final selectedKey = _selectedKey ?? _autoSelectedKey(plan, now);
    // Resolve the selected strip date (fallback: today — e.g. a stale plan
    // whose days all sit in a previous week).
    var selectedDay = now;
    for (final day in plan.days) {
      if (day.date.dateKey == selectedKey) selectedDay = day.date;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WeekHeader(
          label: _weekLabelFor(plan),
          onEditSchedule: () {
            // Edit chip opens the editor for today's/next scheduled session.
            final session = _nextEditableSession(plan, now);
            if (session != null) widget.onEditSession(session);
          },
        ),
        const SizedBox(height: 14),
        _PlanChips(source: plan.source),
        const SizedBox(height: 10),
        _WeekStrip(
          days: plan.days,
          selectedKey: selectedKey,
          onDayTap: (day) =>
              setState(() => _selectedKey = day.date.dateKey),
        ),
        const SizedBox(height: 20),
        _DaySessionsSlot(
          data: widget.data,
          day: selectedDay,
          floorHeight: _slotFloor,
          onEditSession: widget.onEditSession,
        ),
        // Sizing reference for the slot floor (see [_measureSlotFloor]): laid
        // out at the slot's width so its height can be measured once, but
        // Offstage keeps it out of the layout (zero size), the paint and the
        // hit tests — default finders skip it too.
        Offstage(key: _slotFloorKey, child: const _RestDayCard()),
        const SizedBox(height: 20),
        _LibrarySection(exercises: widget.data.exercises),
        const SizedBox(height: 20),
        _MealsSection(
          meals: widget.data.meals,
          target: widget.data.target,
        ),
        const SizedBox(height: 20),
        _HistorySection(data: widget.data),
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
  return '${fmt.format(start)} · ${fmt.format(end)}';
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
      // Platform channel unavailable (e.g. widget tests) · keep display-only.
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
          // Nothing scheduled · just make sure nothing is pending.
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
  const _WeekStrip({
    required this.days,
    required this.selectedKey,
    required this.onDayTap,
  });

  final List<PlanDay> days;

  /// dateKey of the highlighted cell (today, or the user's selection).
  final String selectedKey;

  /// Selects the tapped date — every date of the ongoing week is
  /// accessible, with or without scheduled sessions.
  final ValueChanged<PlanDay> onDayTap;

  @override
  Widget build(BuildContext context) {
    final letterFmt = DateFormat('E');
    return Row(
      children: [
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) const SizedBox(width: 7),
          Flexible(
            fit: FlexFit.loose,
            child: _DayCell(
              letter: letterFmt.format(days[i].date)[0],
              date: '${days[i].date.day}',
              hasSession: days[i].sessions.isNotEmpty,
              selected: days[i].date.dateKey == selectedKey,
              onTap: () => onDayTap(days[i]),
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

  /// Tap selects the date — any day of the ongoing week is selectable.
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
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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

/// The selected day's set of workouts — today by default, or whichever date
/// the user picked in the week strip (ongoing week only). Empty day →
/// rest card. Each session card taps through to the editor.
///
/// Layout stability (the "slots are moving" fix): the stack keeps a stable
/// floor ([floorHeight] — the rest card's height) on every day, card order
/// follows the start time and the whole region animates its size on day
/// switches instead of snapping, so the sections below never jump.
class _DaySessionsSlot extends StatelessWidget {
  const _DaySessionsSlot({
    required this.data,
    required this.day,
    required this.floorHeight,
    required this.onEditSession,
  });

  final _PlanData data;

  /// Selected strip date.
  final DateTime day;

  /// Reserved minimum height (measured rest card) — null before the first
  /// measurement, where the slot lays out at its natural height.
  final double? floorHeight;

  /// Opens the session editor sheet for a tapped session.
  final ValueChanged<PlanSession> onEditSession;

  @override
  Widget build(BuildContext context) {
    // Stable order: cards of a day always render by start time, so a day's
    // slot never reshuffles between visits.
    final sessions = [...data.plan!.sessionsFor(day)]
      ..sort((a, b) => a.startTimeMin.compareTo(b.startTimeMin));
    final isToday = day.dateKey == DateTime.now().dateKey;
    final Widget content = sessions.isEmpty
        ? const _RestDayCard()
        : Column(
            children: [
              for (var i = 0; i < sessions.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _sessionCard(context, sessions[i], isToday),
              ],
            ],
          );
    return ConstrainedBox(
      // Floor: same minimum height on every day (rest card's height) —
      // only days with MORE cards than the floor grow the region, and they
      // do so smoothly via the AnimatedSize below.
      constraints: BoxConstraints(minHeight: floorHeight ?? 0),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.fastOutSlowIn,
        alignment: Alignment.topCenter,
        child: content,
      ),
    );
  }

  Widget _sessionCard(
      BuildContext context, PlanSession session, bool isToday) {
    final workout = data.workouts[session.workoutId];
    final time = _formatStartMin(session.startTimeMin);
    final pill =
        isToday ? time : '${DateFormat('EEE').format(day)} · $time';
    final firstExercise = (workout?.blocks.isNotEmpty ?? false)
        ? workout!.blocks.first.exerciseId
        : null;
    return _NextSessionCard(
      timeLabel: pill,
      title: workout?.name ?? 'Planned session',
      moves: _movesLine(workout, data.exerciseNames),
      onEdit: () => onEditSession(session),
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
                  'Enjoy recovery · or browse the library',
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

/// Selected-day session card with the Start CTA (sample `.btn`).
/// Tapping the card (outside Start) opens the session editor sheet.
class _NextSessionCard extends StatelessWidget {
  const _NextSessionCard({
    required this.timeLabel,
    required this.title,
    required this.moves,
    required this.onEdit,
    required this.onStart,
  });

  final String timeLabel;
  final String title;
  final String moves;

  /// Opens the session editor sheet for this session.
  final VoidCallback onEdit;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GlassCard(
      padding: const EdgeInsets.all(18),
      onTap: onEdit,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusPill(label: timeLabel, tone: PillTone.green),
                const SizedBox(height: 8),
                // Single line + ellipsis: every card of a day keeps the same
                // height (long workout names must not make one card taller
                // than its neighbours).
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  moves,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

/// Horizontal "Exercise library" carousel from the bundled catalog, with
/// smart search (WS7.4): exercise names, muscles, difficulty and description,
/// plus related-word (synonym) expansion and typo tolerance — the same
/// [LibrarySearch] semantics as the WorkoutScreen, scoped to exercises.
class _LibrarySection extends StatefulWidget {
  const _LibrarySection({required this.exercises});

  final List<Exercise> exercises;

  @override
  State<_LibrarySection> createState() => _LibrarySectionState();
}

class _LibrarySectionState extends State<_LibrarySection> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final searching = _query.trim().isNotEmpty;
    final source = searching
        ? LibrarySearch.filterExercises(widget.exercises, _query)
        : widget.exercises;
    // Search shows more matches; browsing keeps the curated 3-card preview.
    final preview = searching ? source.take(8).toList() : source.take(3).toList();
    final Widget listing;
    if (preview.isEmpty && searching) {
      listing = GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No exercises match "$_query".',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: p.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try a muscle (legs, chest), a goal (fat burn), '
              'or an exercise (squat).',
              style: TextStyle(fontSize: 12.5, color: p.ink3),
            ),
          ],
        ),
      );
    } else if (preview.isEmpty) {
      listing = const _LibraryEmpty();
    } else {
      listing = SizedBox(
        // 146 = thumb(72) + spacing + text block + 1.2px border + 10px
        // padding with ~7px slack — at 138 the column overflowed by
        // ~5px with real device font metrics (stripes on every card).
        height: 146,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (var i = 0; i < preview.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              _LibraryCard(exercise: preview[i], toneIndex: i % 3),
            ],
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Exercise library',
          actionLabel: preview.isEmpty ? null : 'See all',
          onAction: preview.isEmpty ? null : () => context.go('/workout'),
        ),
        const SizedBox(height: 10),
        _LibrarySearchField(
          onChanged: (v) => setState(() => _query = v),
          onClear: () => setState(() => _query = ''),
        ),
        const SizedBox(height: 10),
        listing,
      ],
    );
  }
}

/// Compact search field for the plan's exercise library — same glass styling
/// as the WorkoutScreen field, but without autofocus (the plan screen must
/// not steal focus on open).
class _LibrarySearchField extends StatefulWidget {
  const _LibrarySearchField({required this.onChanged, required this.onClear});

  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  State<_LibrarySearchField> createState() => _LibrarySearchFieldState();
}

class _LibrarySearchFieldState extends State<_LibrarySearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
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
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          hintText: 'Search exercises...',
          hintStyle: TextStyle(fontSize: 13, color: p.ink3),
          prefixIcon: Icon(Icons.search, size: 21, color: p.ink3),
          suffixIcon: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => _controller.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: Icon(Icons.clear, size: 21, color: p.ink3),
                    onPressed: () {
                      _controller.clear();
                      widget.onClear();
                    },
                  ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        style: TextStyle(fontSize: 13, color: p.ink),
      ),
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
/// Tapping the card opens the exercise's instruction video — the section
/// lists catalog [Exercise]s, so `/instruction-video?ex=<id>` is the route.
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
    final card = Container(
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
            height: 72,
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
          // Expanded: the text block can never overflow the card (system
          // font scaling used to push it past the fixed height → striped
          // overflow warnings on every card).
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
          ),
        ],
      ),
    );
    // Material + InkWell make the card tappable; both paint nothing while
    // the card is at rest, so the rendered pixels stay identical.
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.go('/instruction-video?ex=${exercise.id}'),
        child: card,
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
        Row(
          children: [
            const Expanded(child: SectionHeader(title: 'Meals today')),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => context.push('/meal'),
                child: const _LinkLabel('Log meal'),
              ),
            ),
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

/// Recent sessions list (sample `.list .lrow` + `.idx`) — latest five
/// inline; "View all" opens the full activity log (sessions + meals).
/// Rows open the session summary.
class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.data});

  final _PlanData data;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final numbers = NumberFormat.decimalPattern();
    final visible = data.history.take(5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SectionHeader(title: 'History')),
            if (data.history.isNotEmpty)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => context.push('/log'),
                  child: const _LinkLabel('View all'),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (data.history.isEmpty)
          GlassCard(
            child: Text(
              'No sessions yet · your completed workouts will appear here.',
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

/// Accent section action copy (sample `.link`) · tap target for section
/// actions (Log meal → /meal, View all → /log).
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
    return const Center(child: CircularProgressIndicator());
  }
}

/// Session editor sheet · time, status and rounds for one scheduled session.
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
