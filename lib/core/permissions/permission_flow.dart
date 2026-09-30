import 'package:permission_handler/permission_handler.dart';

import '../storage/hive_service.dart';

/// First-launch permission flow (PLANNING §6): rationale screen → request
/// camera + notifications + storage once; the answered flag persists
/// device-locally so the flow never repeats on this install.
class PermissionFlow {
  PermissionFlow._();

  /// True once the rationale screen has been shown (first install only).
  static bool get askedBefore =>
      HiveService.getBool(HiveService.kPermissionsAsked);

  static Future<void> markAsked() =>
      HiveService.setBool(HiveService.kPermissionsAsked, true);

  /// Requests the three first-launch permissions. Denials are accepted here —
  /// the camera is re-requested at point of use in the workout flow; a missing
  /// plugin channel (test harness) must never block navigation.
  static Future<void> requestAll() async {
    try {
      await Permission.camera.request();
      await Permission.notification.request();
      await Permission.storage.request();
    } catch (_) {
      return;
    } finally {
      await markAsked();
    }
  }
}
