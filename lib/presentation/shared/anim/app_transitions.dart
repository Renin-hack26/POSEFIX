import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shared GoRouter page transitions — SIMPLIFIED (animation kit removed).
/// Uses a standard fade transition for all reserved full-screen routes.
abstract final class AppTransitions {
  /// Simple fade transition for all screens.
  static Page<void> fadeRise({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }
}