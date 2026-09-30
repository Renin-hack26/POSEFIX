import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Shimmer skeleton placeholders — DISABLED (animation kit removed per user request).
/// Renders child immediately without the moving highlight sweep.
class Shimmer extends StatelessWidget {
  const Shimmer({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) => child;
}

/// Rounded placeholder block — one static piece of a loading layout.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 10,
  });

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