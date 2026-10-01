/// False-count guardrail tests (user-reported: "many time it takes false
/// counts").
///
/// Reproduces phantom-count vectors against the real squat FSM:
///  1. resting camera jitter — must never count;
///  2. two-frame noise dips below the ROM threshold (≤90°) at rest — the
///     phantom cycle: dip commit → stand commit → count. This is the
///     over-count vector the guards must kill;
///  3. single-frame deep spikes — must never count;
///  4. real reps with noise overlay — the guards must not cost true counts.
///
/// A sustained (≥3 raw frames ≈ 100 ms) deep dip is deliberately NOT
/// rejected: at that evidence level it is indistinguishable from a real
/// fast rep's ROM visit (the 3-rep/sec contract's own bottom dwell is
/// exactly 3 frames).
library;

import 'package:fixpose/core/pose/brain_engine.dart';
import 'package:fixpose/core/pose/exercise_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

BrainResult feed(BrainEngine engine, double angle, double t) =>
    engine.processFrame(
      angles: {'primary': angle, 'secondary': 100},
      landmarkCoords: const {},
      timestamp: t,
    );

/// Deterministic pseudo-noise in [-1, 1] (LCG) so every run reproduces.
class _Noise {
  int _s = 42;
  double next() {
    _s = (_s * 1664525 + 1013904223) & 0x7fffffff;
    return _s / 0x7fffffff * 2 - 1;
  }
}

void main() {
  group('false-count guardrails (squat)', () {
    late BrainEngine engine;
    setUp(() => engine = BrainEngine(squatDefinition));

    test('resting jitter ±4° for 15 s never counts', () {
      final n = _Noise();
      var r = feed(engine, 165, 0);
      for (var i = 1; i <= 450; i++) {
        r = feed(engine, 165 + n.next() * 4, i / 30);
      }
      expect(r.repCount, 0, reason: 'rest noise is not a squat');
    });

    test('two-frame noise dips at rest never count (phantom cycle)', () {
      // Landmark noise briefly (2 frames ≈ 66 ms) drops the primary angle
      // under the ROM threshold and springs back, 20 times at rest. Every
      // dip used to commit `bottom` (2-frame cap) and the return to
      // `standing` (2-frame cap) completed a phantom rep cycle.
      var t = 0.0;
      var r = feed(engine, 165, t);
      var dips = 0;
      for (var cycle = 0; cycle < 20; cycle++) {
        for (var i = 0; i < 14; i++) {
          t += 1 / 30;
          r = feed(engine, 165, t);
        }
        t += 1 / 30;
        r = feed(engine, 87, t);
        dips++;
        t += 1 / 30;
        r = feed(engine, 87, t);
        for (var i = 0; i < 5; i++) {
          t += 1 / 30;
          r = feed(engine, 165, t);
        }
      }
      expect(dips, 20);
      expect(r.repCount, 0,
          reason: 'a 2-frame dip is not a full ROM visit (phantom guard)');
    });

    test('single-frame deep spikes at rest never count', () {
      var t = 0.0;
      var r = feed(engine, 165, t);
      for (var cycle = 0; cycle < 30; cycle++) {
        for (var i = 0; i < 11; i++) {
          t += 1 / 30;
          r = feed(engine, 165, t);
        }
        t += 1 / 30;
        r = feed(engine, 60, t); // one wild frame
        for (var i = 0; i < 4; i++) {
          t += 1 / 30;
          r = feed(engine, 165, t);
        }
      }
      expect(r.repCount, 0, reason: 'one frame is never a state');
    });

    test('real slow reps still count exactly with ±3° jitter', () {
      // Ten full squats at ~1 s/cycle with sensor noise — the guardrails
      // must not cost true counts.
      final n = _Noise();
      var t = 0.0;
      var r = feed(engine, 165, t);
      for (var rep = 0; rep < 10; rep++) {
        const down = [150.0, 120.0, 95.0];
        const bottom = [85.0, 80.0, 78.0];
        const up = [100.0, 130.0, 155.0, 165.0];
        for (final a in [...down, ...bottom, ...up]) {
          t += 1 / 30;
          r = feed(engine, a + n.next() * 3, t);
        }
        // Brief stand between reps.
        for (var i = 0; i < 20; i++) {
          t += 1 / 30;
          r = feed(engine, 165 + n.next() * 3, t);
        }
      }
      expect(r.repCount, 10,
          reason: 'guardrails keep every genuine rep');
      expect(t, greaterThan(9), reason: 'test sanity');
    });
  });
}
