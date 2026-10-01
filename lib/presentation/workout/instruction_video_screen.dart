import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../core/di/app_dependencies.dart';
import '../../core/pose/exercise_definition.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/exercise.dart';
import '../shared/glass_card.dart';
import '../shared/grid_background.dart';
import '../shared/primary_button.dart';
import '../shared/status_pill.dart';

/// 09 — Instruction screen: form-demo player (falls back to a static form
/// guide when no clip is bundled), coaching steps derived from the exercise's
/// FSM definition, and the hand-off into the live camera session.
class InstructionVideoScreen extends ConsumerStatefulWidget {
  const InstructionVideoScreen({super.key, this.exerciseId});

  final String? exerciseId;

  @override
  ConsumerState<InstructionVideoScreen> createState() => _InstructionVideoScreenState();
}

/// Everything the instruction screen renders, resolved once per entry.
class _ExerciseData {
  const _ExerciseData({
    required this.exercise,
    required this.definition,
    required this.exerciseId,
  });

  final Exercise exercise;
  final ExerciseDefinition? definition;
  final String exerciseId;
}

class _InstructionVideoScreenState extends ConsumerState<InstructionVideoScreen> {
  late final Future<_ExerciseData> _dataFuture;
  VideoPlayerController? _videoController;

  /// Bundled demo GIF (animated `Image.asset`) when the content pack
  /// declares one — GIFs play natively, no video_player needed.
  String? _gifPath;
  bool _videoLoading = false;
  bool _videoInitialized = false;
  bool _videoLoadFailed = false;

  @override
  void initState() {
    super.initState();
    // Route contract: a missing id resolves to the squat FSM.
    _dataFuture = _loadExerciseData(widget.exerciseId ?? 'squat');
  }

  Future<_ExerciseData> _loadExerciseData(String id) async {
    final exerciseRepo = ref.read(exerciseRepositoryProvider);
    final exercise = await exerciseRepo.byId(id);
    final definition = ExerciseRegistry.instance.resolve(id);
    if (exercise == null) {
      throw StateError('Unknown exercise: $id');
    }
    return _ExerciseData(
      exercise: exercise,
      definition: definition,
      exerciseId: id,
    );
  }

  /// Plays the clip declared by the content pack (`Exercise.demoVideoAsset`).
  /// A missing/unbundled asset fails here and the UI falls back to the
  /// static form-guide panel.
  Future<void> _initVideo(String assetPath) async {
    final controller = VideoPlayerController.asset(assetPath);
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(true);
      await controller.play();
      setState(() {
        _videoController = controller;
        _videoInitialized = true;
      });
    } catch (_) {
      await controller.dispose();
      if (mounted) {
        setState(() {
          _videoLoadFailed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: FutureBuilder<_ExerciseData>(
            future: _dataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return _buildSkeleton(p);
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return _buildNotFound(p);
              }
              final data = snapshot.data!;
              final exercise = data.exercise;
              final steps = _deriveCoachingSteps(data.definition, exercise);
              final meta = _buildMetaLine(exercise, data.definition);

              // Kick the media load once, only when the content pack declares
              // an asset path for this exercise. `.gif` renders via
              // Image.asset (native animation); video paths go to
              // video_player.
              final clipAsset = exercise.demoVideoAsset;
              if (clipAsset != null &&
                  !_videoLoading &&
                  !_videoInitialized &&
                  _gifPath == null &&
                  !_videoLoadFailed) {
                if (clipAsset.toLowerCase().endsWith('.gif')) {
                  _gifPath = clipAsset;
                } else {
                  _videoLoading = true;
                  _initVideo(clipAsset);
                }
              }

              return ListView(
                padding: const EdgeInsets.only(bottom: 26),
                children: [
                  // Header with close, media pill
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 20, top: 8),
                        child: Material(
                          color: p.glass,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => context.canPop()
                                ? context.pop()
                                : context.go('/workout'),
                            child: const SizedBox(
                              width: 42,
                              height: 42,
                              child: Icon(Icons.close, size: 21),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: StatusPill(
                            // The pill mirrors the actual media: a demo is
                            // only "Form demo" once it is really playing.
                            label: (_videoInitialized || _gifPath != null)
                                ? 'Form demo'
                                : 'Form guide',
                            dot: false,
                            tone: (_videoInitialized || _gifPath != null)
                                ? PillTone.green
                                : PillTone.neutral,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 14),
                        // Video player or static form-guide panel
                        _buildMediaPanel(exercise, steps, p),
                        const SizedBox(height: 20),
                        // Exercise title
                        Text(
                          exercise.name,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: p.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Meta line (sets/reps or hold, muscles, level)
                        Text(
                          meta,
                          style: TextStyle(fontSize: 13, color: p.ink2),
                        ),
                        const SizedBox(height: 20),
                        // Coaching steps
                        if (steps.isNotEmpty)
                          for (final (index, step) in steps.indexed) ...[
                            _StepRow(index: index + 1, step: step, palette: p),
                            const SizedBox(height: 10),
                          ],
                        const SizedBox(height: 10),
                        // Actions
                        Row(
                          children: [
                            Expanded(
                              child: SecondaryButton(
                                label: 'Skip',
                                onPressed: () =>
                                    context.push('/vision?ex=${data.exerciseId}'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: PrimaryButton(
                                label: 'Next — open camera',
                                icon: Icons.photo_camera,
                                onPressed: () =>
                                    context.push('/vision?ex=${data.exerciseId}'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton(AppPalette p) {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildNotFound(AppPalette p) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 40),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.video_library_outlined, size: 48, color: p.ink2),
              const SizedBox(height: 12),
              Text(
                'Exercise not found',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: p.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'The requested exercise could not be loaded.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: p.ink2),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'Back to workouts',
                icon: Icons.arrow_back,
                onPressed: () => context.go('/workout'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The clip when it is really playing (GIF or video), otherwise the static
  /// form-guide panel driven by the FSM step list.
  Widget _buildMediaPanel(
    Exercise exercise,
    List<(String, String)> steps,
    AppPalette p,
  ) {
    final bool mediaPlaying = _videoInitialized || _gifPath != null;
    if (mediaPlaying && _gifPath != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.asset(
                _gifPath!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => _buildFormGuidePanel(steps, p),
              ),
            ),
          ),
          Positioned(
            left: 10,
            bottom: 10,
            child: _VideoCaption(title: exercise.name, duration: null),
          ),
        ],
      );
    }
    if (mediaPlaying && _videoController != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),
          Positioned(
            left: 10,
            bottom: 10,
            child: _VideoCaption(
              title: exercise.name,
              duration: _videoController!.value.duration.inSeconds,
            ),
          ),
        ],
      );
    }

    // Static form-guide panel: the coaching steps below carry the detail.
    return _buildFormGuidePanel(steps, p);
  }

  /// Static form-guide panel — the coaching steps below carry the detail.
  Widget _buildFormGuidePanel(List<(String, String)> steps, AppPalette p) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.lightInk2, AppColors.lightInk],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.fitness_center,
                  size: 56,
                  color: p.ink.withAlpha(80),
                ),
                const SizedBox(height: 12),
                Text(
                  'Form guide',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: p.ink.withAlpha(180),
                  ),
                ),
                if (steps.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${steps.length} key '
                    '${steps.length == 1 ? 'position' : 'positions'} — '
                    'follow along below',
                    style: TextStyle(fontSize: 11.5, color: p.ink3),
                  ),
                ],
              ],
            ),
          ),
          // Left accent bar
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: AppColors.accentBright,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Coaching steps, all sourced: 1) FSM state descriptions of this
  /// exercise's definition in `stateOrder` (up to 5), 2) the entity's form
  /// cues, 3) the entity's one-line description.
  List<(String, String)> _deriveCoachingSteps(
    ExerciseDefinition? definition,
    Exercise exercise,
  ) {
    if (definition != null && definition.states.isNotEmpty) {
      final orderedStates = <ExerciseState>[];
      for (final name in definition.stateOrder) {
        for (final state in definition.states) {
          if (state.name == name && state.description.isNotEmpty) {
            orderedStates.add(state);
            break;
          }
        }
      }
      // Include states outside stateOrder that still describe something.
      for (final state in definition.states) {
        if (!definition.stateOrder.contains(state.name) && state.description.isNotEmpty) {
          orderedStates.add(state);
        }
      }
      if (orderedStates.isNotEmpty) {
        final steps = <(String, String)>[];
        for (var i = 0; i < orderedStates.length && steps.length < 5; i++) {
          final state = orderedStates[i];
          final title = state.name
              .replaceAll('_', ' ')
              .split(' ')
              .map((w) => w.capitalize())
              .join(' ');
          steps.add((title, state.description));
        }
        return steps;
      }
    }

    final cues = exercise.formCues;
    if (cues.isNotEmpty) {
      final steps = <(String, String)>[];
      for (var i = 0; i < cues.length && i < 5; i++) {
        steps.add(('Cue ${i + 1}', cues[i]));
      }
      return steps;
    }

    if (exercise.description.isNotEmpty) {
      return [('How to', exercise.description)];
    }
    return const [];
  }

  /// Sets/reps (or hold time) + muscles + level, all from the exercise repo
  /// (the FSM definition only refines the hold target).
  String _buildMetaLine(Exercise exercise, ExerciseDefinition? definition) {
    final parts = <String>[];

    if (exercise.isTimed) {
      final hold = definition?.targetDuration ?? exercise.defaultSeconds;
      final mins = hold ~/ 60;
      final secs = hold % 60;
      parts.add(
        mins > 0 ? '$mins:${secs.toString().padLeft(2, '0')} hold' : '${secs}s hold',
      );
      if (exercise.defaultSets > 1) parts.add('${exercise.defaultSets} sets');
    } else {
      if (exercise.defaultSets > 0) parts.add('${exercise.defaultSets} sets');
      if (exercise.defaultReps > 0) parts.add('${exercise.defaultReps} reps');
    }

    final muscles = [for (final m in exercise.primaryMuscles) m.label];
    if (muscles.isNotEmpty) {
      parts.add(muscles.take(2).join(' & '));
    }

    parts.add(exercise.difficulty.label);
    return parts.join(' · ');
  }
}

/// Numbered coaching step.
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.step,
    required this.palette,
  });

  final int index;
  final (String, String) step;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 18,
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.$1,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(step.$2, style: TextStyle(fontSize: 11.5, color: p.ink3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom-left title/length pill on a playing clip.
class _VideoCaption extends StatelessWidget {
  const _VideoCaption({
    required this.title,
    this.duration,
  });

  final String title;

  /// Clip length in seconds; null for looping GIFs (no meaningful length).
  final int? duration;

  @override
  Widget build(BuildContext context) {
    final String? durationStr;
    if (duration == null) {
      durationStr = null;
    } else if (duration! < 60) {
      durationStr = '${duration}s';
    } else {
      final mins = duration! ~/ 60;
      final secs = duration! % 60;
      durationStr = '$mins:${secs.toString().padLeft(2, '0')}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.darkPage.withAlpha(199),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.smart_display, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            durationStr == null ? title : '$title — $durationStr',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

extension _StringExt on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
