import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Selected theme mode. Default = follow the device (PLANNING §9).
///
/// UI-first: in-memory only. P1 persists the choice in Hive so it survives
/// restarts; the Settings picker (screen 14) calls [ThemeModeNotifier.set].
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system; // Auto (device) by default

  void set(ThemeMode mode) => state = mode;
}
