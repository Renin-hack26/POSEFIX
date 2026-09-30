import 'package:flutter/material.dart';

/// Entrance wrapper: fades the child in (opacity 0 → 1) while it rises from
/// [offset] to zero on an ease-out curve.
///
/// [delay] staggers the start (splash: logo first, copy after); set
/// [enabled] to false to skip the animation and render the child straight at
/// its settled state.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 400),
    this.offset = const Offset(0, 0.05),
    this.enabled = true,
  });

  /// Content being animated in.
  final Widget child;

  /// Wait before the entrance starts.
  final Duration delay;

  /// Length of the entrance once started.
  final Duration duration;

  /// Starting offset relative to the child size — [Offset.zero] is settled.
  final Offset offset;

  /// When false, the child paints immediately at its settled state.
  final bool enabled;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: widget.enabled ? 0.0 : 1.0,
    );
    if (widget.enabled) _start();
  }

  @override
  void didUpdateWidget(covariant FadeSlideIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _controller.value = 0.0;
        _start();
      } else {
        _controller.value = 1.0;
      }
    }
  }

  /// Runs the entrance after [FadeSlideIn.delay], unless unmounted meanwhile.
  void _start() {
    if (widget.delay == Duration.zero) {
      _controller.forward();
      return;
    }
    Future<void>.delayed(widget.delay, () {
      if (!mounted) return;
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = _controller.drive(CurveTween(curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: widget.offset,
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}
