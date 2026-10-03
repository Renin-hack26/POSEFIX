/// WS4 4.1 — the strike bypass must never come back.
///
/// The vision screen used to finalize sessions with a direct
/// `repository.completeSession(...)` call, which skipped the EndSession
/// usecase and its post-workout chain (strike credit, plan credit, report)
/// — so the strike never moved after a workout. The screen now routes
/// through `endSessionProvider`; these assertions pin that wiring at the
/// source level (the screen itself needs camera/ML Kit, so it cannot be
/// driven from a widget test).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _screenPath =
    'lib/presentation/vision/vision_session_screen.dart';

void main() {
  final source = File(_screenPath).readAsStringSync();

  test('vision session ends through the EndSession usecase', () {
    expect(
      source,
      contains('endSessionProvider'),
      reason: '_endSession() must route through endSessionProvider so '
          'strike + plan credit run (WS4 4.1)',
    );
  });

  test('vision session never finalizes via the repository directly', () {
    expect(
      source,
      isNot(contains('.completeSession(')),
      reason: 'a direct repository.completeSession() bypasses the '
          'EndSession usecase — strike credit would be lost again',
    );
  });

  test('summary navigation uses the report returned by the usecase', () {
    expect(
      source,
      contains('report.sessionId'),
      reason: 'EndSession returns the Report; the summary route must take '
          'its sessionId',
    );
  });
}
