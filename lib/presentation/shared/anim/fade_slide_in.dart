import 'package:flutter/material.dart';

/// Entrance wrapper — DISABLED (animation kit removed per user request).
/// Renders child immediately without animation.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 400),
    this.offset = const Offset(0, 0.05),
    this.enabled = true,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final bool enabled;

  @override
  Widget build(BuildContext context) => child;
}