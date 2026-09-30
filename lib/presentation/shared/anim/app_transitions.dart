import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shared GoRouter page transitions for the reserved full-screen routes.
///
/// ```dart
/// pageBuilder: (context, state) =>
///     AppTransitions.fadeRise(state: state, child: const XScreen()),
/// ```
abstract final class AppTransitions {
  /// Soft fade with a small rise: the incoming screen starts slightly below
  /// its final position and settles into place; reversing eases back down.
  static Page<void> fadeRise({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          _FadeRise(animation: animation, child: child),
    );
  }
}

/// Fade + rise driven by the route animation; owns the [CurvedAnimation] so
/// its status listener is registered once per route and disposed with it.
class _FadeRise extends StatefulWidget {
  const _FadeRise({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  State<_FadeRise> createState() => _FadeRiseState();
}

class _FadeRiseState extends State<_FadeRise> {
  late final CurvedAnimation _animation;

  @override
  void initState() {
    super.initState();
    _animation = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(_animation),
        child: widget.child,
      ),
    );
  }
}
