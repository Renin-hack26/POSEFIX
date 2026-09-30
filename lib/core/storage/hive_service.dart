import 'package:hive_flutter/hive_flutter.dart';

/// Device-local key/value preferences (theme, sync watermark, flags).
///
/// Account data lives in Drift — this box only carries device-local settings
/// that must survive restarts (PLANNING §2 Hive scope).
class HiveService {
  HiveService._();

  static const String settingsBoxName = 'settings';

  // --- keys ---
  static const String kThemeMode = 'themeMode'; // system | light | dark
  static const String kLastSyncedAt = 'lastSyncedAtMs';
  static const String kOnboardingDone = 'onboardingDone';
  static const String kPermissionsAsked = 'permissionsAsked';
  static const String kCoachMarksSeen = 'coachMarksSeen';
  static const String kNotificationsEnabled = 'notificationsEnabled';

  static late Box _settings;

  /// Opens the settings box. [path] overrides the storage root (tests use a
  /// temp directory; production uses the app documents dir via initFlutter).
  /// Safe to call multiple times — subsequent calls no-op if already initialized.
  static Future<void> init({String? path}) async {
    if (_isInitialized) return;
    if (path == null) {
      await Hive.initFlutter();
    } else {
      Hive.init(path);
    }
    _settings = await Hive.openBox<dynamic>(settingsBoxName);
    _isInitialized = true;
  }

  static bool _isInitialized = false;

  static Box get settings => _settings;

  static int? getInt(String key) => _settings.get(key) as int?;

  static Future<void> setInt(String key, int value) =>
      _settings.put(key, value);

  static String? getString(String key) => _settings.get(key) as String?;

  static Future<void> setString(String key, String value) =>
      _settings.put(key, value);

  static bool getBool(String key, {bool fallback = false}) =>
      _settings.get(key, defaultValue: fallback) as bool;

  static Future<void> setBool(String key, bool value) =>
      _settings.put(key, value);

  static Future<void> remove(String key) => _settings.delete(key);
}
