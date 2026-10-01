import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/app_dependencies.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/training_plan.dart';
import '../../domain/entities/workout.dart';
import '../shared/glass_card.dart';
import '../shared/grid_background.dart';
import '../shared/primary_button.dart';
import '../shared/section_header.dart';
import '../shared/status_pill.dart';

/// 07 — Workout tab: header, today's session resume card, category chips,
/// search, and the workout library. Every card opens its details page.
///
/// Data: real repositories only — the library comes from
/// [WorkoutRepository.library]; the resume card from the active plan
/// ([PlanRepository.currentPlan]) or the top suggestion
/// ([WorkoutRepository.suggestions]).
class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key});

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  /// Chip → predicate over real [Workout] fields:
  /// All      → every workout;
  /// Strength → `category == strength || fullBody`;
  /// Cardio   → `category == cardio || hiit`;
  /// Mobility → `category == mobility`;
  /// Core     → `category == core`.
  static final _categories = <_CategoryFilter>[
    _CategoryFilter.all(),
    _CategoryFilter.strength(),
    _CategoryFilter.cardio(),
    _CategoryFilter.mobility(),
    _CategoryFilter.core(),
  ];

  late Future<List<Workout>> _libraryFuture;
  late Future<_ResumeData> _resumeFuture;

  int _category = 0;
  String _searchQuery = '';
  bool _showSearch = false;
  bool _sortByDuration = false;

  @override
  void initState() {
    super.initState();
    _libraryFuture = ref.read(workoutRepositoryProvider).library();
    _resumeFuture = _loadResumeData();
  }

  /// Reloads both futures (error-card retry).
  void _retry() {
    setState(() {
      _libraryFuture = ref.read(workoutRepositoryProvider).library();
      _resumeFuture = _loadResumeData();
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
              _buildHeader(p),
              const SizedBox(height: 16),
              _buildResumeCard(),
              const SizedBox(height: 16),
              _buildCategoryChips(),
              const SizedBox(height: 18),
              _buildLibraryHeader(p),
              const SizedBox(height: 10),
              _buildWorkoutLibrary(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppPalette p) {
    return Row(
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
        if (!_showSearch) ...[
          _GlassIcon(
            icon: Icons.search,
            onTap: () => setState(() => _showSearch = true),
          ),
          const SizedBox(width: 8),
          _GlassIcon(
            icon: Icons.tune,
            active: _sortByDuration,
            onTap: () => setState(() => _sortByDuration = !_sortByDuration),
          ),
        ] else ...[
          Expanded(
            child: _SearchField(
              onChanged: (v) => setState(() => _searchQuery = v),
              onClear: () => setState(() => _searchQuery = ''),
            ),
          ),
          const SizedBox(width: 8),
          _GlassIcon(
            icon: Icons.close,
            onTap: () => setState(() {
              _showSearch = false;
              _searchQuery = '';
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildResumeCard() {
    return FutureBuilder<_ResumeData>(
      future: _resumeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _ResumeCardSkeleton();
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.workout == null) {
          // Hidden only when there is neither a plan session nor a suggestion.
          return const SizedBox.shrink();
        }
        final data = snapshot.data!;
        final workout = data.workout!;
        return _ResumeCard(
          workout: workout,
          sourceLabel: data.sourceLabel,
          onStart: () => context.push('/workout-details?id=${workout.id}'),
        );
      },
    );
  }

  /// Today's plan session when one is scheduled, else the top suggestion.
  Future<_ResumeData> _loadResumeData() async {
    try {
      final plan = await ref.read(planRepositoryProvider).currentPlan();
      if (plan != null) {
        final todaySessions = plan.sessionsFor(DateTime.now());
        final planned = todaySessions.where((s) => s.status == PlanSessionStatus.planned);
        final session = planned.isNotEmpty ? planned.first : (todaySessions.isNotEmpty ? todaySessions.first : null);
        if (session != null) {
          final workout = await ref.read(workoutRepositoryProvider).byId(session.workoutId);
          if (workout != null) {
            return _ResumeData(workout, "Today's plan");
          }
        }
      }
    } catch (_) {
      // Plan storage unavailable — fall through to suggestions.
    }
    final suggestions = await ref.read(workoutRepositoryProvider).suggestions(limit: 1);
    if (suggestions.isNotEmpty) {
      return _ResumeData(suggestions.first, 'Suggested for you');
    }
    return const _ResumeData(null, '');
  }

  Widget _buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < _categories.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _CategoryChip(
              label: _categories[i].label,
              selected: i == _category,
              onTap: () => setState(() => _category = i),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLibraryHeader(AppPalette p) {
    return FutureBuilder<List<Workout>>(
      future: _libraryFuture,
      builder: (context, snapshot) {
        final loaded = snapshot.connectionState == ConnectionState.done;
        final allWorkouts = snapshot.data ?? const <Workout>[];
        final count = _filterWorkouts(allWorkouts).length;
        return Row(
          children: [
            const Expanded(child: SectionHeader(title: 'Workout library')),
            if (loaded)
              Text(
                '$count workout${count == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: p.accentDeep,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildWorkoutLibrary() {
    return FutureBuilder<List<Workout>>(
      future: _libraryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _WorkoutSkeleton();
        }
        if (snapshot.hasError) {
          return _ErrorCard(
            message: 'Could not load workout library',
            onRetry: _retry,
          );
        }
        final filtered = _filterWorkouts(snapshot.data ?? const <Workout>[]);
        if (filtered.isEmpty) {
          return const _EmptyLibrary();
        }
        return Column(
          children: [
            for (var i = 0; i < filtered.length; i++) ...[
              _WorkoutRow(
                workout: filtered[i],
                onTap: () => context.push('/workout-details?id=${filtered[i].id}'),
              ),
              if (i < filtered.length - 1) const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }

  List<Workout> _filterWorkouts(List<Workout> workouts) {
    var result = workouts;

    // Category filter — see the mapping comment on [_categories].
    final categoryFilter = _categories[_category];
    result = result.where(categoryFilter.predicate).toList();

    // Search filter — case-insensitive match on the workout name.
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((w) => w.name.toLowerCase().contains(query)).toList();
    }

    // Sort toggle — real field ([Workout.durationMin]), shortest first.
    if (_sortByDuration) {
      result.sort((a, b) => a.durationMin.compareTo(b.durationMin));
    }

    return result;
  }
}

/// Category filter with label and predicate over [Workout] fields.
class _CategoryFilter {
  const _CategoryFilter(this.label, this.predicate);

  final String label;
  final bool Function(Workout) predicate;

  static _CategoryFilter all() => _CategoryFilter('All', (_) => true);

  static _CategoryFilter strength() => _CategoryFilter(
        'Strength',
        (w) =>
            w.category == WorkoutCategory.strength ||
            w.category == WorkoutCategory.fullBody,
      );

  static _CategoryFilter cardio() => _CategoryFilter(
        'Cardio',
        (w) =>
            w.category == WorkoutCategory.cardio ||
            w.category == WorkoutCategory.hiit,
      );

  static _CategoryFilter mobility() => _CategoryFilter(
        'Mobility',
        (w) => w.category == WorkoutCategory.mobility,
      );

  static _CategoryFilter core() => _CategoryFilter(
        'Core',
        (w) => w.category == WorkoutCategory.core,
      );
}

/// Data for the resume card.
class _ResumeData {
  const _ResumeData(this.workout, this.sourceLabel);

  final Workout? workout;
  final String sourceLabel;
}

/// "Today's session" card with stats and a start/resume action.
class _ResumeCard extends StatelessWidget {
  const _ResumeCard({
    required this.workout,
    required this.sourceLabel,
    required this.onStart,
  });

  final Workout workout;
  final String sourceLabel;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final exercisesCount = workout.blocks.length;
    final totalSets = workout.blocks.fold<int>(0, (sum, b) => sum + b.sets);
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                        sourceLabel,
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
                  workout.name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$exercisesCount exercise${exercisesCount == 1 ? '' : 's'} · '
                  '$totalSets set${totalSets == 1 ? '' : 's'} · '
                  'about ${workout.durationMin} min',
                  style: TextStyle(fontSize: 11.5, color: p.ink3),
                ),
                const SizedBox(height: 10),
                const _ProgressBar(value: 0),
                const SizedBox(height: 6),
                Text(
                  'Ready to start',
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

/// Skeleton for the resume card while loading.
class _ResumeCardSkeleton extends StatelessWidget {
  const _ResumeCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
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

/// Library row — taps through to the details screen.
class _WorkoutRow extends StatelessWidget {
  const _WorkoutRow({
    required this.workout,
    required this.onTap,
  });

  final Workout workout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final exercisesCount = workout.blocks.length;
    final totalSets = workout.blocks.fold<int>(0, (sum, b) => sum + b.sets);
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 18,
      onTap: onTap,
      child: Row(
        children: [
          _Thumb(category: workout.category),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${workout.durationMin} min · ${workout.level.label} · '
                  '$exercisesCount exercise${exercisesCount == 1 ? '' : 's'} · '
                  '$totalSets set${totalSets == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 11.5, color: p.ink3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusPill(label: workout.category.label, tone: _pillToneFor(workout.category), dot: false),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 20, color: p.ink3),
        ],
      ),
    );
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
}

/// Category-based thumbnail.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.category});

  final WorkoutCategory category;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (gradient, icon, iconColor) = switch (category) {
      WorkoutCategory.strength => (
          const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.lightInk3, AppColors.lightInk2],
          ),
          Icons.fitness_center,
          Colors.white.withAlpha(235),
        ),
      WorkoutCategory.hiit => (
          const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.accent, AppColors.lightAccentDeep],
          ),
          Icons.bolt,
          Colors.white.withAlpha(235),
        ),
      WorkoutCategory.cardio => (
          LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [p.accentSoft, p.accentDeep],
          ),
          Icons.directions_run,
          Colors.white.withAlpha(235),
        ),
      WorkoutCategory.core => (
          const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.lightInk2, AppColors.lightInk],
          ),
          Icons.accessibility_new,
          Colors.white.withAlpha(235),
        ),
      WorkoutCategory.fullBody => (
          LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.amber, p.amberPillFg],
          ),
          Icons.sports,
          AppColors.accentInk,
        ),
      WorkoutCategory.mobility => (
          LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [p.glassHi, p.glass],
          ),
          Icons.self_improvement,
          p.ink,
        ),
    };
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, size: 26, color: iconColor),
    );
  }
}

/// Thin gradient progress bar.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

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
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [p.accentSoft, p.accentDeep],
            ),
            borderRadius: const BorderRadius.all(Radius.circular(999)),
          ),
        ),
      ),
    );
  }
}

/// Square glass icon tile.
class _GlassIcon extends StatelessWidget {
  const _GlassIcon({required this.icon, this.active = false, this.onTap});

  final IconData icon;

  /// Tints the tile with the accent when the toggle it mirrors is on.
  final bool active;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final child = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: p.glass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: active ? p.accentDeep : p.border),
        boxShadow: [
          BoxShadow(
            color: p.shadowSoft,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, size: 21, color: active ? p.accentDeep : p.ink),
    );
    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: child,
      ),
    );
  }
}

/// Inline search field — filters the library by workout name.
class _SearchField extends StatefulWidget {
  const _SearchField({
    required this.onChanged,
    required this.onClear,
  });

  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
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
        autofocus: true,
        controller: _controller,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          hintText: 'Search workouts...',
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

/// Error card with retry.
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
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
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// Empty library state.
class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.fitness_center, size: 48, color: p.ink3),
          const SizedBox(height: 12),
          Text(
            'No workouts match your filters',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try adjusting your search or category',
            style: TextStyle(fontSize: 12.5, color: p.ink3),
          ),
        ],
      ),
    );
  }
}

/// Loading stand-in: resume card, category chips, library header and workout rows.
class _WorkoutSkeleton extends StatelessWidget {
  const _WorkoutSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
