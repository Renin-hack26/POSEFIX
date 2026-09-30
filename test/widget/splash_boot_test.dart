import 'dart:io';

import 'package:fixpose/core/storage/hive_service.dart';
import 'package:fixpose/main.dart';
import 'package:fixpose/presentation/auth/sign_in_screen.dart';
import 'package:fixpose/presentation/permissions/permission_screen.dart';
import 'package:fixpose/presentation/splash/splash_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  setUpAll(() async {
    // Test needs Hive for theme mode + first-launch flags.
    // Unique dir per run: Windows locks the box files per process.
    final testDir = Directory.systemTemp.createTempSync('fixpose_hive_test_');
    await HiveService.init(path: testDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
  });

  testWidgets('app boots: splash first, then auto-enters sign in',
      (tester) async {
    await HiveService.setBool(HiveService.kPermissionsAsked, true);
    await tester.pumpWidget(
      const ProviderScope(child: FixPoseApp()),
    );
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);

    // Splash holds ~1.7 s then routes to the auth stack. Fixed pumps only —
    // the splash spinner (and auth shimmer) animate forever, so
    // pumpAndSettle would never settle.
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SignInScreen), findsOneWidget);
  });

  testWidgets('fresh install routes splash to the permission rationale',
      (tester) async {
    // Simulate fresh install: permissions not yet asked.
    await HiveService.setBool(HiveService.kPermissionsAsked, false);

    await tester.pumpWidget(
      const ProviderScope(child: FixPoseApp()),
    );
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Rationale screen only — the Continue tap is covered on-device
    // (permission_handler needs real platform channels; in widget tests
    // the tap never settles).
    expect(find.byType(PermissionScreen), findsOneWidget);
  });
}
