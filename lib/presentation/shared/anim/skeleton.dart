import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Shimmer skeleton placeholders for loading screens (no packages, pure
/// Flutter).
///
/// Usage: shape placeholders like the real content, then wrap the whole
/// placeholder group of a section in one [Shimmer] while the screen loads —
/// e.g. `Shimmer(child: Column(children: [SkeletonText(width: 140), ...]))`.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child, this.enabled = true});

  /// The placeholder group the highlight sweeps across.
  final Widget child;

  /// Runs the repeating sweep; false stops it and drops the highlight.
  final bool enabled;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.enabled) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant Shimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled == oldWidget.enabled) return;
    if (widget.enabled) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: Align(
              alignment: Alignment(-1.0 + 2.0 * _controller.value, 0),
              child: FractionallySizedBox(
                widthFactor: 0.55,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        p.glassHi.withAlpha(0),
                        p.glassHi.withAlpha(140),
                        p.glassHi.withAlpha(0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded placeholder block — one static piece of a loading layout; the
/// [Shimmer] wrapper supplies the moving highlight.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 10,
  });

  /// Fixed width, or null to fill the incoming (stretching) width.
  final double? width;

  final double height;

  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: p.track,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Single text-line placeholder.
class SkeletonText extends StatelessWidget {
  const SkeletonText({super.key, required this.width, this.height = 12});

  /// Line width — text lines have an explicit width.
  final double width;

  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: p.track,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

/// N stacked [SkeletonBox] rows with [gap] spacing — a stand-in list shaped
/// like the real rows (e.g. history or workout entries).
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.count = 3,
    this.height = 64,
    this.gap = 10,
  });

  final int count;

  final double height;

  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) SizedBox(height: gap),
          SkeletonBox(height: height, radius: 18),
        ],
      ],
    );
  }
}
