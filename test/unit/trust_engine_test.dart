/// Batch 5 — trust gating inside the BrainEngine: held frames never
/// advance the FSM, rep commits go through the accumulator verdict, and
/// trust-blind mode (legacy/tests) behaves exactly as before.
library;

import 'package:fixpose/core/pose/brain_engine.dart';
import 'package:fixpose/core/pose/exercise_catalog.dart';
import 'package:fixpose/core/pose/trust_gate.dart';
import 'package:flutter_test/flutter_test.dart';

TrustBreakdown _good() => TrustBreakdown(
      visibility: 0.95,
      agreement: 0.95,
      temporal: 0.95,
      geometry: 0.95,
      agreementAvailable: true,
    );

TrustBreakdown _bad() => TrustBreakdown(
      visibility: 0.3,
      agreement: 0.3,
      temporal: 0.3,
      geometry: 0.3,
      agreementAvailable: true,
    );

BrainResult _feed(BrainEngine e, Map<String, double> angles, double t,
        {TrustBreakdown? trust}) =>
    e.processFrame(
        angles: angles,
        landmarkCoords: const {},
        timestamp: t,
        frameTrust: trust);

/// One full squat cycle; returns the final result.
BrainResult _squatCycle(
    BrainEngine engine, TrustBreakdown Function() trust,
    {double step = 0.1}) {
  var t = 0.0;
  BrainResult r = _feed(
      engine, {'primary': 170.0, 'secondary': 100.0}, t,
      trust: trust());
  for (final a in [140.0, 110.0, 90.0, 82.0, 80.0, 80.0]) {
    t += step;
    r = _feed(engine, {'primary': a, 'secondary': 100.0}, t, trust: trust());
  }
  for (final a in [95.0, 120.0, 150.0, 170.0, 170.0]) {
    t += step;
    r = _feed(engine, {'primary': a, 'secondary': 100.0}, t, trust: trust());
  }
  return r;
}

void main() {
  group('frame gate', () {
    test('held frames never advance the FSM', () {
      final engine = BrainEngine(squatDefinition);
      var t = 0.0;
      BrainResult? r;
      for (var i = 0; i < 6; i++) {
        r = _feed(engine, {'primary': 170.0, 'secondary': 100.0}, t, trust: _bad());
        t += 0.1;
      }
      // Standing would commit within 3 frames untrusted — held instead.
      expect(r!.currentState, 'unknown');
      expect(r.repCount, 0);
      expect(r.trust, isNotNull);
      expect(r.trust!.held, isTrue);
      expect(r.repJustCompleted, isFalse);
      expect(r.repRejectedReason, isNull);
    });

    test('trusted cycle attaches the breakdown and counts', () {
      // (Null-trust legacy mode is pinned by the WS9 suites, which never
      // pass a breakdown.)
      final engine = BrainEngine(squatDefinition);
      final r = _squatCycle(engine, () => _good());
      expect(r.trust, isNotNull);
      expect(r.repCount, 1);
      expect(r.repHoldReason, HoldReason.none);
    });
  });

  group('rep gate', () {
    test('trusted cycle commits', () {
      final engine = BrainEngine(squatDefinition);
      final r = _squatCycle(engine, _good);
      expect(r.repCount, 1, reason: 'trusted rep commits');
      expect(r.repJustCompleted, isTrue);
      expect(r.repHoldReason, HoldReason.none);
    });

    test('hard-blocked frame mid-rep vetoes the commit', () {
      final engine = BrainEngine(squatDefinition);
      var t = 0.0;
      BrainResult? r;
      TrustBreakdown tk() => _good();

      // Two good standing frames…
      r = _feed(engine, {'primary': 170.0, 'secondary': 100.0}, t, trust: tk());
      t += 0.1;
      r = _feed(engine, {'primary': 170.0, 'secondary': 100.0}, t, trust: tk());
      t += 0.1;
      // …one hard-blocked frame off the critical path (frozen, sampled)…
      r = _feed(
          engine, {'primary': 170.0, 'secondary': 100.0}, t,
          trust: TrustBreakdown(
              visibility: 0.9,
              agreement: 0.9,
              temporal: 0.9,
              geometry: 0.9,
              agreementAvailable: true,
              blocking: const [HoldReason.multiplePeople]));
      expect(r.repCount, 0);
      t += 0.1;
      // …then a clean full cycle around it.
      for (final a in [140.0, 110.0, 90.0, 82.0, 80.0, 80.0]) {
        t += 0.1;
        r = _feed(engine, {'primary': a, 'secondary': 100.0}, t, trust: tk());
      }
      for (final a in [95.0, 120.0, 150.0, 170.0, 170.0]) {
        t += 0.1;
        r = _feed(engine, {'primary': a, 'secondary': 100.0}, t, trust: tk());
      }
      expect(r!.repCount, 0,
          reason: 'the blocked frame vetoes an otherwise clean rep');
      expect(r.repJustCompleted, isFalse);
      expect(r.repHoldReason, HoldReason.multiplePeople);
      expect(r.repRejectedReason, isNull,
          reason: 'a hold is not a ROM rejection');
    });

    test('transient low visibility alone does not veto', () {
      final engine = BrainEngine(squatDefinition);
      var t = 0.0;
      BrainResult? r;
      var i = 0;
      TrustBreakdown tk() {
        // One transiently weak (but unheld) frame mid-rep.
        if (i++ == 4) {
          return TrustBreakdown(
              visibility: 0.55,
              agreement: 0.9,
              temporal: 0.9,
              geometry: 0.9,
              agreementAvailable: true,
              blocking: const [HoldReason.lowVisibility]);
        }
        return _good();
      }

      r = _feed(engine, {'primary': 170.0, 'secondary': 100.0}, t, trust: tk());
      for (final a in [140.0, 110.0, 90.0, 82.0, 80.0, 80.0]) {
        t += 0.1;
        r = _feed(engine, {'primary': a, 'secondary': 100.0}, t, trust: tk());
      }
      for (final a in [95.0, 120.0, 150.0, 170.0, 170.0]) {
        t += 0.1;
        r = _feed(engine, {'primary': a, 'secondary': 100.0}, t, trust: tk());
      }
      expect(r!.repCount, 1,
          reason: 'reference rule: LOW_VISIBILITY never vetoes alone');
      expect(r.repHoldReason, HoldReason.none);
    });
  });
}
