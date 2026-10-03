import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// "Follow along" posture card pinned to the top-right of the vision screen
/// (sample `.avatar-guide`): target-pose silhouette plus caption.
/// [phase] syncs the card to the live FSM state (P3 avatar phase-sync) —
/// the exerciser sees which phase to mirror, not a static picture.
class PostureAvatar extends StatelessWidget {
  const PostureAvatar({super.key, this.caption = 'FOLLOW ALONG', this.phase});

  /// Caption under the target pose.
  final String caption;

  /// Live exercise phase (e.g. `Bottom`), null while unknown.
  final String? phase;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.darkPage.withAlpha(140),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(46)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 96,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.lightInk2, AppColors.lightInk],
              ),
            ),
            child: const Icon(
              Icons.accessibility_new,
              size: 44,
              color: AppColors.lightInk3,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Colors.white.withAlpha(191),
                  ),
                ),
                if (phase != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    phase!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accentBright.withAlpha(242),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
