/// WS2 (TODO 2.10) — pre-session auto-calibration: the pure ROM capture
/// the analyzer fills on locked frames, and the verdict/announcement the
/// session screen derives from the learned primary-angle range.
library;

import 'package:fixpose/presentation/vision/session_flow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // -------------------------------------------------------------------------
  // RomCapture — min/max tracker fed by PoseAnalyzer (pure, no ML Kit)
  // -------------------------------------------------------------------------

  group('RomCapture', () {
    test('knows nothing before the first sample', () {
      final RomCapture rom = RomCapture();
      expect(rom.minDeg, isNull);
      expect(rom.maxDeg, isNull);
      expect(rom.spanDeg, isNull);
    });

    test('tracks extrema across a squat-like cycle', () {
      final RomCapture rom = RomCapture();
      // Standing → descending → bottom → ascending (knee angle).
      for (final angle in [176.0, 150.0, 120.0, 92.0, 130.0, 174.0]) {
        rom.add(angle);
      }
      expect(rom.minDeg, 92.0);
      expect(rom.maxDeg, 176.0);
      expect(rom.spanDeg, closeTo(84.0, 1e-9));
    });

    test('order does not matter — extremes win', () {
      final RomCapture rom = RomCapture()
        ..add(100)
        ..add(170)
        ..add(60)
        ..add(140);
      expect(rom.minDeg, 60.0);
      expect(rom.maxDeg, 170.0);
      expect(rom.spanDeg, 110.0);
    });

    test('a single sample has zero span, not null', () {
      final RomCapture rom = RomCapture()..add(90);
      expect(rom.minDeg, 90.0);
      expect(rom.maxDeg, 90.0);
      expect(rom.spanDeg, 0.0);
    });

    test('reset clears the learned range', () {
      final RomCapture rom = RomCapture()
        ..add(170)
        ..add(80);
      expect(rom.spanDeg, isNotNull);
      rom.reset();
      expect(rom.minDeg, isNull);
      expect(rom.maxDeg, isNull);
      expect(rom.spanDeg, isNull);
      // ...and it can learn again afterwards.
      rom.add(160);
      rom.add(95);
      expect(rom.spanDeg, 65.0);
    });
  });

  // -------------------------------------------------------------------------
  // Calibration verdict (what the screen announces when the phase ends)
  // -------------------------------------------------------------------------

  group('judgeCalibrationDepth', () {
    test('no samples → unknown (camera never saw a locked angle)', () {
      expect(judgeCalibrationDepth(null), CalibrationDepth.unknown);
      expect(judgeCalibrationDepth(double.nan), CalibrationDepth.unknown);
    });

    test('a real rep cycle clears the good-span bar', () {
      // Typical squat cycle: 176° standing → 92° bottom = 84° span.
      expect(judgeCalibrationDepth(84), CalibrationDepth.good);
      expect(judgeCalibrationDepth(calibrationGoodSpanDeg),
          CalibrationDepth.good);
      expect(judgeCalibrationDepth(120), CalibrationDepth.good);
    });

    test('standing still or pulsing is shallow', () {
      expect(judgeCalibrationDepth(0), CalibrationDepth.shallow);
      expect(judgeCalibrationDepth(12), CalibrationDepth.shallow);
      expect(
        judgeCalibrationDepth(calibrationGoodSpanDeg - 0.1),
        CalibrationDepth.shallow,
      );
    });
  });

  group('calibrationCompleteLine', () {
    test('every verdict announces round 1 — calibration never blocks', () {
      for (final depth in CalibrationDepth.values) {
        final String line = calibrationCompleteLine(depth);
        expect(line, contains('Round one, begin!'));
        expect(line, isNotEmpty);
      }
    });

    test('the three verdicts say distinctly different things', () {
      final String good = calibrationCompleteLine(CalibrationDepth.good);
      final String shallow =
          calibrationCompleteLine(CalibrationDepth.shallow);
      final String unknown =
          calibrationCompleteLine(CalibrationDepth.unknown);
      expect(good, contains('range looks good'));
      expect(shallow, contains('full range'));
      expect(good, isNot(equals(shallow)));
      expect(shallow, isNot(equals(unknown)));
      expect(good, isNot(equals(unknown)));
    });
  });
}
