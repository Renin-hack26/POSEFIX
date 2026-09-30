import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// FixPose logo tile — chartreuse gradient rounded square with the
/// accessibility glyph (sample `.logo` on splash + sign-in).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 54, this.radius = 18, this.iconSize = 27});

  final double size;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.accentBright, AppColors.accentMid],
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentMid.withAlpha(128),
            blurRadius: size * 0.45,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: Icon(
        Icons.accessibility_new,
        size: iconSize,
        color: AppColors.accentInk,
      ),
    );
  }
}
