/// RenderFlex overflow regression tests (the yellow/black "overflowed by N
/// pixels" indicator the user reported on Workout details + Plan day strip).
///
/// Each case pumps the exact widget markup at the app's 360dp width and
/// asserts NO layout exception is recorded. The plan day cells are tested at
/// an enlarged text scale (1.4) — the reported device has system font
/// scaling on, which is exactly when the fixed-height cells overflowed
/// (only session-day cells carry the dot row, hence the visible repeats).
library;

import 'package:fixpose/core/theme/app_theme.dart';
import 'package:fixpose/presentation/shared/glass_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpAt(WidgetTester tester, Widget child,
      {double textScale = 1.0}) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: [AppPalette.dark]),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          backgroundColor: const Color(0xFF0C1013),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
              child: SingleChildScrollView(child: child),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  // --- Workout details stats card (duration / level / burn / exercises) ---

  Widget stat(
    AppPalette p, {
    required IconData icon,
    required String value,
    required String label,
    Color? iconColor,
  }) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: iconColor ?? p.ink2),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: p.ink)),
              Text(label, style: TextStyle(fontSize: 11.5, color: p.ink3)),
            ],
          ),
        ],
      );

  Widget statsCard(BuildContext context) {
    final p = context.palette;
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 12,
        children: [
          stat(p, icon: Icons.schedule, value: '45 min', label: 'Duration'),
          stat(p,
              icon: Icons.trending_up,
              value: 'Intermediate',
              label: 'Level'),
          stat(p,
              icon: Icons.local_fire_department,
              value: '250 kcal',
              label: 'Est. burn'),
          stat(p,
              icon: Icons.fitness_center, value: '12', label: 'Exercises'),
        ],
      ),
    );
  }

  testWidgets('workout details stats card: no overflow (default scale)',
      (tester) async {
    await pumpAt(tester, Builder(builder: statsCard));
    expect(tester.takeException(), isNull);
  });

  testWidgets('workout details stats card: no overflow (1.4 scale)',
      (tester) async {
    await pumpAt(tester, Builder(builder: statsCard), textScale: 1.4);
    expect(tester.takeException(), isNull);
  });

  // --- Plan day strip cells (letter + date + session dot) ---

  Widget dayCell(String letter, String date, bool hasSession) => AspectRatio(
        aspectRatio: 1 / 1.25,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xB81B2118),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0x1FFFFFFF), width: 1.2),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(letter,
                      style: const TextStyle(
                          fontSize: 10.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(date,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w800)),
                  if (hasSession) ...[
                    const SizedBox(height: 3),
                    Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                            color: Color(0xFFC3F53C), shape: BoxShape.circle)),
                  ],
                ],
              ),
            ),
          ),
        ),
      );

  Widget weekStrip() => Row(
        children: [
          for (var i = 0; i < 7; i++) ...[
            if (i > 0) const SizedBox(width: 7),
            Flexible(
              fit: FlexFit.loose,
              child: dayCell('SMTWTFS'[i], '${20 + i}', i % 2 == 0),
            ),
          ],
        ],
      );

  testWidgets('plan week strip: no overflow (default scale)', (tester) async {
    await pumpAt(tester, weekStrip());
    expect(tester.takeException(), isNull);
  });

  testWidgets('plan week strip: no overflow (1.4 scale, enlarged system font)',
      (tester) async {
    await pumpAt(tester, weekStrip(), textScale: 1.4);
    expect(tester.takeException(), isNull);
  });
}
