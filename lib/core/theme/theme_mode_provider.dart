import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/hive_service.dart';

/// Selected theme mode. Default = follow the device (PLANNING §9).
///
/// Persisted in Hive (device-local) so the choice survives restarts; the
/// Settings picker (screen 14) calls [ThemeModeNotifier.set].
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final stored = HiveService.getString(HiveService.kThemeMode);
    return ThemeMode.values.asNameMap()[stored] ?? ThemeMode.system;
  }

  void set(ThemeMode mode) {
    state = mode;
    HiveService.setString(HiveService.kThemeMode, mode.name);
  }
}
