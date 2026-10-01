import 'dart:io';

import 'package:fixpose/core/storage/hive_service.dart';
import 'package:fixpose/main.dart';
import 'package:fixpose/presentation/auth/sign_in_screen.dart';
import 'package:fixpose/presentation/permissions/permission_screen.dart';
import 'package:fixpose/presentation/splash/splash_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Boot smoke test: splash first → routes by first-launch flags.
///
/// The Hive flags are written in group `setUp` callbacks, NOT inside the
/// testWidgets body: `Box.put` is real file I/O and awaiting it inside the
/// body's FakeAsync zone never resumes (it hung the file for 10+ minutes
/// per test until moved here — setUp runs in the real zone, where the
/// identical call completes instantly).
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

  group('returning user (permissions already asked)', () {
    setUp(() async {
      await HiveService.setBool(HiveService.kPermissionsAsked, true);
    });

    testWidgets('app boots: splash first, then auto-enters sign in',
        (tester) async {
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
  });

  group('fresh install (permissions not yet asked)', () {
    setUp(() async {
      await HiveService.setBool(HiveService.kPermissionsAsked, false);
    });

    testWidgets('fresh install routes splash to the permission rationale',
        (tester) async {
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
  });
}
