import 'package:fixpose/main.dart';
import 'package:fixpose/presentation/splash/splash_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots and routes to splash', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: FixPoseApp()),
    );
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);
  });
}
