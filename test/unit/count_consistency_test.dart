/// WS9.4 count-consistency sequences (user-reported: squat / push-up
/// "counts are not consistent and not proper").
///
/// Pins the WS9.1 + WS9.2 engine tunes against synthetic frames:
///  1. soft-lockout tops (156–160° squat / 153–155° push-up) count — the
///     old 160° / 155° bars silently dropped them;
///  2. a depth hold wobbling across the 90° line keeps its ROM visit
///     (boundary hysteresis) instead of rejecting a real rep;
///  3. hammer curl counts once per curl cycle (per-arm max replaces the
///     left + right sum that double-counted every simultaneous rep);
///  4. a session starting in standing reports nothing — no phantom
///     "not counted" before the first real rep.
library;

import 'package:fixpose/core/pose/brain_engine.dart';
import 'package:fixpose/core/pose/exercise_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

BrainResult feed(BrainEngine e, Map<String, double> angles, double t) =>
    e.processFrame(angles: angles, landmarkCoords: const {}, timestamp: t);

void main() {
  group('WS9.1 boundary hysteresis (soft lockout + depth wobble)', () {
    test('squat topping out at 158° (below the old 160° bar) counts', () {
      final engine = BrainEngine(squatDefinition);
      var t = 0.0;
      BrainResult r = feed(engine, {'primary': 170.0, 'secondary': 100.0}, t);
      t += 0.04;
      // Descent into depth.
      for (final a in [140.0, 110.0, 95.0, 85.0, 80.0, 80.0, 80.0]) {
        r = feed(engine, {'primary': a, 'secondary': 100.0}, t);
        t += 0.04;
      }
      // Rise to a soft top — never crosses 160°.
      for (final a in [95.0, 120.0, 145.0, 158.0, 158.0]) {
        r = feed(engine, {'primary': a, 'secondary': 100.0}, t);
        t += 0.04;
      }
      expect(r.repCount, 1, reason: '158° top must commit the trigger');
      expect(r.repJustCompleted, isTrue);
      expect(r.repRejectedReason, isNull);
    });

    test('squat depth hold wobbling across the 90° line keeps the visit',
        () {
      final engine = BrainEngine(squatDefinition);
      var t = 0.0;
      BrainResult r = feed(engine, {'primary': 170.0, 'secondary': 100.0}, t);
      t += 0.04;
      r = feed(engine, {'primary': 170.0, 'secondary': 100.0}, t);
      t += 0.04;
      // Descent to depth, then wobble across the 90° boundary — the ROM
      // visit must survive the frames that read 91–96°.
      for (final a in <double>[
        140.0, 110.0, 95.0, 85.0, 85.0, 93.0, 91.0, 95.0, 96.0, 88.0, 89.0,
      ]) {
        r = feed(engine, {'primary': a, 'secondary': 100.0}, t);
        t += 0.04;
      }
      // Full rise to lockout.
      for (final a in [110.0, 130.0, 150.0, 170.0, 170.0]) {
        r = feed(engine, {'primary': a, 'secondary': 100.0}, t);
        t += 0.04;
      }
      expect(r.repCount, 1, reason: 'a real depth rep survives the wobble');
      expect(r.repRejectedReason, isNull);
    });

    test('push-up locking out at 154° (below the old 155° bar) counts',
        () {
      final engine = BrainEngine(pushUpDefinition);
      var t = 0.0;
      const double posture = 175.0;
      BrainResult r =
          feed(engine, {'primary': 170.0, 'posture_angle': posture}, t);
      t += 0.04;
      r = feed(engine, {'primary': 170.0, 'posture_angle': posture}, t);
      t += 0.04;
      // Descent to depth with a boundary wobble in the hold (covers the
      // push-up bottom hysteresis too).
      for (final a in [140.0, 110.0, 95.0, 85.0, 85.0, 93.0, 91.0, 95.0, 88.0]) {
        r = feed(engine, {'primary': a, 'posture_angle': posture}, t);
        t += 0.04;
      }
      for (final a in [95.0, 120.0, 145.0, 154.0, 154.0]) {
        r = feed(engine, {'primary': a, 'posture_angle': posture}, t);
        t += 0.04;
      }
      expect(r.repCount, 1, reason: '154° lockout must commit plank_up');
      expect(r.repRejectedReason, isNull);
    });
  });

  group('WS9.2 hammer curl — one count per curl cycle', () {
    test('three simultaneous curls count three, not six', () {
      final engine = BrainEngine(hammerCurlDefinition);
      Map<String, double> both(double elbow) => <String, double>{
            'left': elbow,
            'right': elbow,
            'left_alignment': 90.0,
            'right_alignment': 90.0,
          };
      var t = 0.0;
      BrainResult r = feed(engine, both(170), t);
      t += 0.05;
      r = feed(engine, both(170), t);
      // Extended start long enough to clear minRepDuration (0.8 s).
      for (var i = 0; i < 18; i++) {
        r = feed(engine, both(170), t);
        t += 0.05;
      }
      for (var cycle = 0; cycle < 3; cycle++) {
        // Curl into the lifting band, then past the trigger (≤47°).
        for (final a in [140.0, 110.0, 80.0, 60.0, 50.0]) {
          r = feed(engine, both(a), t);
          t += 0.05;
        }
        for (final a in [40.0, 40.0, 40.0]) {
          r = feed(engine, both(a), t);
          t += 0.05;
        }
        // Release to full extension before the next curl — keeps the
        // cycle gap ≥ 0.8 s minRepDuration.
        for (final a in [70.0, 110.0, 140.0, 170.0]) {
          r = feed(engine, both(a), t);
          t += 0.05;
        }
        for (var i = 0; i < 10; i++) {
          r = feed(engine, both(170), t);
          t += 0.05;
        }
      }
      expect(r.repCount, 3, reason: 'three curls = three counts, not six');
      expect(r.bilateral, isNotNull);
      expect(r.bilateral!.leftCount, 3);
      expect(r.bilateral!.rightCount, 3);
      expect(r.repRejectedReason, isNull);
    });
  });

  group('WS9.3 startup honesty', () {
    test('starting in standing never reports a phantom rejection', () {
      final engine = BrainEngine(squatDefinition);
      final reasons = <RepRejectedReason?>[];
      BrainResult? last;
      for (var i = 0; i < 6; i++) {
        last = feed(engine, {'primary': 170.0, 'secondary': 100.0}, i * 0.04);
        reasons.add(last.repRejectedReason);
      }
      expect(reasons.where((x) => x != null), isEmpty,
          reason: 'session start is not a rejected rep');
      expect(last!.repCount, 0);
      // …and the first real rep still counts afterwards.
      var t = 0.3;
      for (final a in [140.0, 110.0, 95.0, 85.0, 80.0, 80.0, 80.0]) {
        last = feed(engine, {'primary': a, 'secondary': 100.0}, t);
        t += 0.04;
      }
      for (final a in [95.0, 120.0, 145.0, 165.0, 170.0, 170.0]) {
        last = feed(engine, {'primary': a, 'secondary': 100.0}, t);
        t += 0.04;
      }
      expect(last!.repCount, 1);
      expect(last.repRejectedReason, isNull);
    });
  });
}
