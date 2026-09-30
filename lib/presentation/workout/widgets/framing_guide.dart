import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// "Stand inside the frame" positioning guide (sample `.frame-guide`): dims
/// everything outside the dashed frame, adds an inner chartreuse glow and the
/// hint label above it.
class FramingGuide extends StatelessWidget {
  const FramingGuide({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => CustomPaint(
        size: constraints.biggest,
        painter: _FramingGuidePainter(),
      ),
    );
  }
}

class _FramingGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const frameWidth = 190.0;
    const frameHeight = 350.0;
    const label = 'STAND INSIDE THE FRAME';

    final frame = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.24 + frameHeight / 2),
        width: frameWidth,
        height: frameHeight,
      ),
      const Radius.circular(26),
    );

    // Dim everything outside the frame (sample `box-shadow: 0 0 0 100vmax …`).
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(frame);
    canvas.drawPath(outside, Paint()..color = AppColors.darkPage.withAlpha(97));

    // Soft glow bleeding inwards (sample `inset 0 0 40px …`).
    canvas.save();
    canvas.clipPath(Path()..addRRect(frame));
    canvas.drawRRect(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 44
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20)
        ..color = AppColors.accentBright.withAlpha(38),
    );
    canvas.restore();

    // Dashed outline.
    final outline = Paint()
      ..color = AppColors.accentBright.withAlpha(242)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final path = Path()..addRRect(frame);
    for (final metric in path.computeMetrics()) {
      const dash = 10.0;
      const gap = 8.0;
      var distance = 0.0;
      while (distance < metric.length) {
        final end = distance + dash;
        canvas.drawPath(
          metric.extractPath(
            distance,
            end < metric.length ? end : metric.length,
          ),
          outline,
        );
        distance = end + gap;
      }
    }

    // Hint label above the frame.
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.85,
          color: AppColors.accentBright.withAlpha(235),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(size.width / 2 - textPainter.width / 2, frame.top - 26),
    );
  }

  @override
  bool shouldRepaint(covariant _FramingGuidePainter oldDelegate) => false;
}
