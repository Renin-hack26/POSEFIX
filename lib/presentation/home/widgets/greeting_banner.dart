import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Home greeting block — time-of-day line, user name and last-workout summary
/// (sample "Good morning / Alex Carter / Last workout …" section).
class GreetingBanner extends StatelessWidget {
  const GreetingBanner({
    super.key,
    required this.greeting,
    required this.name,
    required this.summary,
  });

  /// Time-of-day line, e.g. "Good morning".
  final String greeting;

  /// Display name of the signed-in user.
  final String name;

  /// One-line activity summary under the name.
  final String summary;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: p.ink2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          name,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.44,
            color: p.ink,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          summary,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: p.ink3,
          ),
        ),
      ],
    );
  }
}
