import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/app_dependencies.dart';
import '../../core/storage/hive_service.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/exercise.dart';
import '../shared/app_logo.dart';
import '../shared/glass_card.dart';
import '../shared/grid_background.dart';
import '../shared/primary_button.dart';
import '../shared/section_header.dart';

/// Onboarding (PLANNING §5.4): pick level + goal once → the weekly plan is
/// generated locally and the app enters HOME.
///
/// Entered after every auth success; if a plan already exists (local or
/// synced from another device) it forwards straight to HOME.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  Difficulty? _level;
  String? _goal;
  bool _busy = false;
  String? _error;

  static const _levels = <(Difficulty, String, String)>[
    (Difficulty.beginner, 'Beginner', 'New to training or getting back into it'),
    (Difficulty.intermediate, 'Intermediate', 'Training a few times a week'),
    (Difficulty.advanced, 'Advanced', 'Consistent, structured training'),
  ];

  static const _goals = <(String, String, IconData)>[
    ('fat_loss', 'Fat loss', Icons.monitor_weight_outlined),
    ('muscle_gain', 'Muscle gain', Icons.fitness_center),
    ('general_fitness', 'General fitness', Icons.favorite_outline),
  ];

  @override
  void initState() {
    super.initState();
    _checkExistingPlan();
    // New device: the account's plan may still be downloading — forward the
    // moment it lands instead of letting the user generate a duplicate.
    ref.read(syncEngineProvider).lastSyncedAt.addListener(_onSynced);
  }

  @override
  void dispose() {
    ref.read(syncEngineProvider).lastSyncedAt.removeListener(_onSynced);
    super.dispose();
  }

  Future<void> _checkExistingPlan() async {
    final plan = await ref.read(planRepositoryProvider).currentPlan();
    if (plan != null && mounted) context.go('/home');
  }

  Future<void> _onSynced() => _checkExistingPlan();

  Future<void> _generate() async {
    final level = _level;
    final goal = _goal;
    if (level == null || goal == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(generateWeeklyPlanProvider)(
        level: level,
        goal: goal,
      );
      await HiveService.setBool(HiveService.kOnboardingDone, true);
      if (mounted) context.go('/home');
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not generate your plan. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ready = _level != null && _goal != null;
    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: AppLogo(size: 56, radius: 18, iconSize: 28)),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Set up your week',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                      color: p.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 330),
                    child: Text(
                      'FixPose builds a 7-day plan from your level and goal. '
                          'You can edit any day later in the Plan tab.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13.5, height: 1.45, color: p.ink2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const SectionHeader(title: 'Your level'),
                const SizedBox(height: 10),
                for (final (level, label, caption) in _levels) ...[
                  _OptionCard(
                    selected: _level == level,
                    icon: level == Difficulty.beginner
                        ? Icons.accessibility_new
                        : level == Difficulty.intermediate
                            ? Icons.directions_run
                            : Icons.local_fire_department,
                    title: label,
                    caption: caption,
                    onTap: _busy ? null : () => setState(() => _level = level),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 12),
                const SectionHeader(title: 'Your goal'),
                const SizedBox(height: 10),
                for (final (goal, label, icon) in _goals) ...[
                  _OptionCard(
                    selected: _goal == goal,
                    icon: icon,
                    title: label,
                    caption: null,
                    onTap: _busy ? null : () => setState(() => _goal = goal),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 8),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                PrimaryButton(
                  label: 'Generate my week',
                  icon: Icons.auto_awesome,
                  loading: _busy,
                  onPressed: ready && !_busy ? _generate : null,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.caption,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? p.accentSoft : p.glassHi,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 19,
              color: selected ? p.accentDeep : p.ink2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    caption!,
                    style: TextStyle(fontSize: 12, color: p.ink2),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            selected ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 21,
            color: selected ? p.accentDeep : p.line,
          ),
        ],
      ),
    );
  }
}
