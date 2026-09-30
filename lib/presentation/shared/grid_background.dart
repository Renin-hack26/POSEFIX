import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Full-screen "liquid glass" background — mirrors `sample/styles.css` body:
/// vertical cream/near-black gradient + 26px grid lines + chartreuse/blue blooms.
///
/// Colors come from the active theme's [AppPalette], so light/dark switch
/// automatically with the device (or the Settings picker).
class GridBackground extends StatelessWidget {
  const GridBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // StackFit.expand: the stack (and its painter) always fills the screen.
    // Without it the Stack shrink-wraps to the child's content height, so
    // short forms (sign-in, forgot-password) left the lower part blank.
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: _GridPainter(palette)),
          ),
        ),
        child,
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.palette);

  final AppPalette palette;

  /// Grid pitch in logical px (sample: 26px).
  static const double _pitch = 26;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1) Base vertical gradient
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.bgTop, palette.bgBottom],
        ).createShader(rect),
    );

    // 2) Blooms: chartreuse top-right, soft blue bottom-left
    void bloom(Offset center, double radius, Color color) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withAlpha(0)],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    bloom(
      Offset(size.width * 0.95, size.height * 0.04),
      size.width * 0.75,
      palette.blobA,
    );
    bloom(
      Offset(size.width * 0.04, size.height * 0.96),
      size.width * 0.70,
      palette.blobB,
    );

    // 3) Grid lines on top (crisp at half-pixel offsets)
    final line = Paint()
      ..color = palette.grid
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width + _pitch; x += _pitch) {
      canvas.drawLine(Offset(x + 0.5, 0), Offset(x + 0.5, size.height), line);
    }
    for (double y = 0; y <= size.height + _pitch; y += _pitch) {
      canvas.drawLine(Offset(0, y + 0.5), Offset(size.width, y + 0.5), line);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.palette != palette;
}
