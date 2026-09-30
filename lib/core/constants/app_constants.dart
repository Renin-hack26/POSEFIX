/// FixPose app-wide constants.
class AppConstants {
  const AppConstants._();

  static const String appName = 'FixPose';

  // --- Camera / performance (FR-1, NFR) ---
  static const int targetCameraFps = 30;
  static const int minAcceptableFps = 25; // NFR: smooth 25+ FPS mid-range

  // --- TTS ---
  static const Duration ttsCueCooldown = Duration(seconds: 2);
  static const Duration ttsRepCountCooldown = Duration(milliseconds: 400);

  // --- Rest / rounds ---
  static const Duration defaultRestDuration = Duration(seconds: 60);

  // --- Strike / badges (Home) ---
  static const List<int> badgeTierDays = [3, 7, 14, 30, 100];

  // --- Tips carousel (Home) ---
  static const Duration tipDwell = Duration(seconds: 6); // enough time to read

  // --- OTP ---
  static const Duration otpResendCooldown = Duration(seconds: 60);
  static const Duration otpCodeExpiry = Duration(minutes: 10);

  // --- Notifications ---
  static const Duration quietHoursStart = Duration(hours: 22);
  static const Duration quietHoursEnd = Duration(hours: 7);

  // --- Auth validation rules ---
  static const int minPasswordLength = 8;
  static const int minAgeYears = 13;
}
