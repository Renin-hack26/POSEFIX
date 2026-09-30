import 'package:fixpose/main.dart';
import 'package:fixpose/presentation/auth/sign_in_screen.dart';
import 'package:fixpose/presentation/splash/splash_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots: splash first, then auto-enters sign in', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: FixPoseApp()),
    );
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);

    // Splash holds ~1.7s then routes to the auth stack (P1: session check).
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
  });
}
