import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

/// Glass square back arrow (sample `.icon-btn`) used across pushed auth screens.
/// Falls back to [fallback] when the screen was reached via `go` (empty stack).
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.fallback = '/signin'});

  final String fallback;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 8),
      child: Material(
        color: p.glass,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.canPop() ? context.pop() : context.go(fallback),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(Icons.arrow_back, size: 21, color: p.ink),
          ),
        ),
      ),
    );
  }
}
