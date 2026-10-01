import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/app_dependencies.dart';
import '../../core/storage/hive_service.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/workout.dart';
import '../shared/app_back_button.dart';
import '../shared/glass_card.dart';
import '../shared/grid_background.dart';
import '../shared/primary_button.dart';
import '../shared/section_header.dart';
import '../shared/status_pill.dart';

/// 08 — Workout details: hero, badge, stats, start CTA, exercise plan,
/// muscles, and bookmark. Opened from every library card; each exercise
/// row opens the instruction video.
class WorkoutDetailsScreen extends ConsumerStatefulWidget {
  const WorkoutDetailsScreen({super.key, this.workoutId});

  /// Query parameter `id` from `/workout-details?id=<workoutId>`; null → the
  /// first library workout is shown.
  final String? workoutId;

  @override
  ConsumerState<WorkoutDetailsScreen> createState() => _WorkoutDetailsScreenState();
}

class _WorkoutDetailsScreenState extends ConsumerState<WorkoutDetailsScreen> {
  /// Hive settings key holding the bookmarked workout ids (device-local).
  static const _bookmarksKey = 'bookmarkedWorkouts';

  late Future<_DetailData> _future;

  /// Bookmark state written by [_toggleBookmark] before the data future is
  /// rebuilt; null → fall back to the persisted state in [_DetailData].
  bool? _bookmarkOverride;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DetailData> _load() async {
    await HiveService.init();
    final workoutRepo = ref.read(workoutRepositoryProvider);
    final exerciseRepo = ref.read(exerciseRepositoryProvider);

    // No id (or blank) → fall back to the first library workout; an id that
    // does not resolve shows the not-found card below (never a crash).
    var targetId = widget.workoutId;
    if (targetId == null || targetId.isEmpty) {
      final library = await workoutRepo.library();
      targetId = library.isNotEmpty ? library.first.id : null;
    }

    Workout? workout;
    if (targetId != null) {
      workout = await workoutRepo.byId(targetId);
    }
    if (workout == null) {
      return const _DetailData(workout: null, plan: <_PlanEntry>[], bookmarked: false);
    }

    final plan = <_PlanEntry>[];
    for (final block in workout.blocks) {
      final exercise = await exerciseRepo.byId(block.exerciseId);
      plan.add(_PlanEntry(block: block, exercise: exercise));
    }

    return _DetailData(
      workout: workout,
      plan: plan,
      bookmarked: _isBookmarked(workout.id),
    );
  }

  bool _isBookmarked(String workoutId) {
    final stored = HiveService.settings.get(_bookmarksKey);
    return stored is List && stored.contains(workoutId);
  }

  /// Persist the bookmark flip in the Hive settings box.
  Future<void> _toggleBookmark(String workoutId) async {
    await HiveService.init();
    final stored = HiveService.settings.get(_bookmarksKey);
    final bookmarks = (stored is List) ? stored.whereType<String>().toSet() : <String>{};
    final nowSaved = !bookmarks.contains(workoutId);
    if (nowSaved) {
      bookmarks.add(workoutId);
    } else {
      bookmarks.remove(workoutId);
    }
    await HiveService.settings.put(_bookmarksKey, bookmarks.toList());
    setState(() => _bookmarkOverride = nowSaved);
  }

  void _retry() {
    setState(() {
      _bookmarkOverride = null;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 26),
            children: [
              _buildHeader(p),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: FutureBuilder<_DetailData>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const _DetailSkeleton();
                    }
                    if (snapshot.hasError || !snapshot.hasData) {
                      return _buildError(p);
                    }
                    final data = snapshot.data!;
                    if (data.workout == null) {
                      return _buildNotFound(p);
                    }
                    return _DetailBody(data: data);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppPalette p) {
    return Row(
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
        FutureBuilder<_DetailData>(
          future: _future,
          builder: (context, snapshot) {
            final workout = snapshot.data?.workout;
            if (workout == null) {
              // Keeps the title centered while the bookmark slot is empty.
              return const SizedBox(width: 60);
            }
            return Padding(
              padding: const EdgeInsets.only(right: 18, top: 8),
              child: _BookmarkButton(
                saved: _bookmarkOverride ?? snapshot.data!.bookmarked,
                onToggle: () => _toggleBookmark(workout.id),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildError(AppPalette p) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not load workout',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Check your connection and try again.',
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

  Widget _buildNotFound(AppPalette p) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.fitness_center, size: 48, color: p.ink3),
          const SizedBox(height: 12),
          Text(
            'Workout not found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'This workout may have been removed.',
            style: TextStyle(fontSize: 12.5, color: p.ink3),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Back to library',
            icon: Icons.arrow_back,
            onPressed: () => context.go('/workout'),
          ),
        ],
      ),
    );
  }
}

/// Aggregated data for the detail screen ([workout] null → id not found).
class _DetailData {
  const _DetailData({
    required this.workout,
    required this.plan,
    required this.bookmarked,
  });

  final Workout? workout;
  final List<_PlanEntry> plan;
  final bool bookmarked;
}

/// One plan row: a real block prescription plus its catalog exercise
/// (null when the catalog misses the id — the raw id is shown instead).
class _PlanEntry {
  const _PlanEntry({required this.block, required this.exercise});

  final WorkoutBlock block;
  final Exercise? exercise;
}

/// Body with all real data — hero, title, description, stats, plan, muscles.
class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.data});

  final _DetailData data;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final workout = data.workout!;
    final plan = data.plan;
    final firstExerciseId = plan.isNotEmpty ? plan.first.block.exerciseId : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _buildHero(p, workout),
        const SizedBox(height: 20),
        Text(
          workout.name,
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: p.ink,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          workout.goal,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: p.accentDeep,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          workout.description,
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: p.ink2,
          ),
        ),
        const SizedBox(height: 20),
        _buildStatsCard(p, workout, plan.length),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Start workout',
          icon: Icons.play_arrow,
          onPressed: firstExerciseId != null
              ? () => context.push('/vision?ex=$firstExerciseId')
              : null,
        ),
        const SizedBox(height: 20),
        _buildPlanSection(p, context, plan),
        const SizedBox(height: 4),
        _buildMusclesCard(p, workout.focusMuscles),
      ],
    );
  }

  Widget _buildHero(AppPalette p, Workout workout) {
    final (gradient, icon) = _heroStyleFor(p, workout.category);
    return Stack(
      children: [
        Container(
          height: 190,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Icon(icon, size: 56, color: Colors.white.withAlpha(235)),
          ),
        ),
        Positioned(
          left: 10,
          bottom: 10,
          child: StatusPill(
            label: workout.category.label.toUpperCase(),
            tone: _pillToneFor(workout.category),
            dot: false,
          ),
        ),
      ],
    );
  }

  (LinearGradient, IconData) _heroStyleFor(AppPalette p, WorkoutCategory category) {
    return switch (category) {
      WorkoutCategory.strength => (
          const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.lightInk3, AppColors.lightInk2],
          ),
          Icons.fitness_center,
        ),
      WorkoutCategory.hiit => (
          const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.accent, AppColors.lightAccentDeep],
          ),
          Icons.bolt,
        ),
      WorkoutCategory.cardio => (
          LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.accentMid, p.accentDeep],
          ),
          Icons.directions_run,
        ),
      WorkoutCategory.core => (
          const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.lightInk2, AppColors.lightInk],
          ),
          Icons.accessibility_new,
        ),
      WorkoutCategory.fullBody => (
          LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.amber, p.amberPillFg],
          ),
          Icons.sports,
        ),
      WorkoutCategory.mobility => (
          const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.lightInk3, AppColors.lightInk],
          ),
          Icons.self_improvement,
        ),
    };
  }

  PillTone _pillToneFor(WorkoutCategory category) {
    return switch (category) {
      WorkoutCategory.strength => PillTone.green,
      WorkoutCategory.hiit => PillTone.amber,
      WorkoutCategory.cardio => PillTone.dark,
      WorkoutCategory.core => PillTone.neutral,
      WorkoutCategory.fullBody => PillTone.dark,
      WorkoutCategory.mobility => PillTone.neutral,
    };
  }

  Widget _buildStatsCard(
    AppPalette p,
    Workout workout,
    int exercisesCount,
  ) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Stat(
            icon: Icons.schedule,
            value: '${workout.durationMin} min',
            label: 'Duration',
          ),
          _Stat(
            icon: Icons.trending_up,
            value: workout.level.label,
            label: 'Level',
          ),
          _Stat(
            icon: Icons.local_fire_department,
            iconColor: p.amberPillFg,
            value: workout.estimatedCalories > 0
                ? '${workout.estimatedCalories} kcal'
                : '—',
            label: 'Est. burn',
          ),
          _Stat(
            icon: Icons.fitness_center,
            value: '$exercisesCount',
            label: 'Exercises',
          ),
        ],
      ),
    );
  }

  Widget _buildPlanSection(
    AppPalette p,
    BuildContext context,
    List<_PlanEntry> plan,
  ) {
    // The blocks carry no explicit round grouping → the real exercise list is
    // shown as a single circuit. When every block shares one set count, that
    // count is surfaced as the circuit's round count (real data only).
    final rounds =
        plan.length > 1 && plan.every((e) => e.block.sets == plan.first.block.sets)
            ? plan.first.block.sets
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SectionHeader(title: 'Workout plan')),
            Text(
              '${plan.length} exercise${plan.length == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 11.5, color: p.ink3),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (rounds != null) ...[
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            radius: 18,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.accentSoft,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '$rounds',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: p.accentDeep,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$rounds round${rounds == 1 ? '' : 's'} × '
                        '${plan.length} exercise${plan.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: p.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Circuit — every exercise shares the same set count',
                        style: TextStyle(fontSize: 11.5, color: p.ink3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        for (var i = 0; i < plan.length; i++) ...[
          _PlanRow(
            index: i + 1,
            entry: plan[i],
            onTap: () => context.push('/instruction-video?ex=${plan[i].block.exerciseId}'),
          ),
          if (i < plan.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildMusclesCard(AppPalette p, List<MuscleGroup> muscles) {
    if (muscles.isEmpty) return const SizedBox.shrink();
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Target muscles',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final m in muscles) _MuscleChip(muscle: m)],
          ),
        ],
      ),
    );
  }
}

/// Muscle chip for the target muscles section.
class _MuscleChip extends StatelessWidget {
  const _MuscleChip({required this.muscle});

  final MuscleGroup muscle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: p.glass,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: p.border),
      ),
      child: Text(
        muscle.label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: p.ink,
        ),
      ),
    );
  }
}

/// Individual exercise row in the plan — taps through to the instruction video.
class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.index,
    required this.entry,
    required this.onTap,
  });

  final int index;
  final _PlanEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final block = entry.block;
    final exercise = entry.exercise;
    final name = exercise?.name ?? block.exerciseId;
    final sets = block.sets;
    final setsLabel = block.seconds > 0
        ? '$sets set${sets == 1 ? '' : 's'} × ${block.seconds}s hold'
        : '$sets set${sets == 1 ? '' : 's'} × ${block.reps} rep${block.reps == 1 ? '' : 's'}';

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 18,
      onTap: onTap,
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
              '$index',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: p.selFg,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _PlanThumb(exercise: exercise),
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
                Text(
                  setsLabel,
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

/// Thumbnail for a plan row — colored by the exercise's primary muscle.
class _PlanThumb extends StatelessWidget {
  const _PlanThumb({required this.exercise});

  final Exercise? exercise;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final muscles = exercise?.primaryMuscles ?? const <MuscleGroup>[];
    final primaryMuscle = muscles.isNotEmpty ? muscles.first : MuscleGroup.fullBody;
    final (gradient, icon) = _styleForMuscle(p, primaryMuscle);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, size: 20, color: Colors.white.withAlpha(235)),
    );
  }

  (LinearGradient, IconData) _styleForMuscle(AppPalette p, MuscleGroup muscle) {
    return switch (muscle) {
      MuscleGroup.chest => (
          const LinearGradient(colors: [AppColors.lightInk3, AppColors.lightInk2]),
          Icons.fitness_center,
        ),
      MuscleGroup.back => (
          const LinearGradient(colors: [AppColors.lightInk2, AppColors.lightInk]),
          Icons.sports,
        ),
      MuscleGroup.legs => (
          const LinearGradient(colors: [AppColors.accent, AppColors.lightAccentDeep]),
          Icons.directions_run,
        ),
      MuscleGroup.glutes => (
          LinearGradient(colors: [p.accentSoft, p.accentDeep]),
          Icons.directions_walk,
        ),
      MuscleGroup.shoulders => (
          const LinearGradient(colors: [AppColors.lightInk3, AppColors.lightInk2]),
          Icons.accessibility_new,
        ),
      MuscleGroup.arms => (
          const LinearGradient(colors: [AppColors.lightInk2, AppColors.lightInk]),
          Icons.front_hand,
        ),
      MuscleGroup.core => (
          const LinearGradient(colors: [AppColors.accent, AppColors.lightAccentDeep]),
          Icons.self_improvement,
        ),
      MuscleGroup.cardio => (
          LinearGradient(colors: [AppColors.accentMid, p.accentDeep]),
          Icons.bolt,
        ),
      MuscleGroup.fullBody => (
          LinearGradient(colors: [AppColors.amber, p.amberPillFg]),
          Icons.sports,
        ),
      MuscleGroup.mobility => (
          LinearGradient(colors: [p.glassHi, p.glass]),
          Icons.self_improvement,
        ),
    };
  }
}

/// Stat item for the stats card.
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

/// Bookmark toggle in the header.
class _BookmarkButton extends StatelessWidget {
  const _BookmarkButton({required this.saved, required this.onToggle});

  final bool saved;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.glass,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onToggle,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            saved ? Icons.bookmark : Icons.bookmark_border,
            size: 21,
            color: saved ? p.accentDeep : p.ink,
          ),
        ),
      ),
    );
  }
}

/// Loading skeleton for the detail screen.
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
