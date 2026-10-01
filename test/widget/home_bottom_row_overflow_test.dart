import 'package:fixpose/presentation/shared/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression test for the home bottom action-row overflow.
/// Pumps the exact row at 360dp width and fails on any overflow error.
void main() {
  testWidgets('home bottom action row fits 360dp without overflow',
      (tester) async {
    final errors = <FlutterErrorDetails>[];
    FlutterError.onError = errors.add;
    tester.view.physicalSize = const Size(360 * 3, 740 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Progress report',
                    icon: Icons.description,
                    expand: true,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(
                    label: 'Chat with VEDA',
                    icon: Icons.smart_toy,
                    expand: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final overflow =
        errors.where((e) => '${e.exception}'.contains('overflowed'));
    expect(overflow, isEmpty,
        reason:
            'Bottom action row overflowed at 360dp: ${overflow.map((e) => e.exception).join('; ')}');
  });
}
