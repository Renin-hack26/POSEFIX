/// Batch 5 — trust gate port: weights, scorers, redistribution,
/// accumulator verdicts, agreement mapping, side selection. Mirrors the
/// Open Vission `trust.py` contract point for point.
library;

import 'package:fixpose/core/pose/trust_gate.dart';
import 'package:flutter_test/flutter_test.dart';

List<double> _vis(double v) => List<double>.filled(33, v);

List<List<double>> _grid(double Function(int i) f, {int n = 3}) =>
    List<List<double>>.generate(33, (i) => List<double>.generate(n, (k) {
          final v = f(i);
          return k == 0 ? v : (k == 1 ? v * 0.5 : 0.0);
        }));

void main() {
  group('weights + threshold', () {
    test('four signals blend to exactly 1.0; threshold is 0.85', () {
      expect(wVisibility + wAgreement + wTemporal + wGeometry,
          closeTo(1.0, 1e-9));
      expect(trustThreshold, 0.85);
    });

    test('perfect frame clears the bar', () {
      final b = TrustBreakdown(
        visibility: 1,
        agreement: 1,
        temporal: 1,
        geometry: 1,
        agreementAvailable: true,
      );
      expect(b.score, closeTo(1.0, 1e-9));
      expect(b.held, isFalse);
      expect(b.reason, HoldReason.none);
    });
  });

  group('single-source redistribution', () {
    test('missing verifier redistributes, never scores as agreement', () {
      final single = TrustBreakdown(
        visibility: 1,
        temporal: 1,
        geometry: 1,
      );
      // (0.35 + 0.20 + 0.15) / 0.70 == 1.0 — honest, not inflated.
      expect(single.score, closeTo(1.0, 1e-9));
      final weak = TrustBreakdown(
        visibility: 0.5,
        temporal: 0.5,
        geometry: 0.5,
      );
      // Same inputs dual-source with agreement 0 would score lower —
      // single-source must not look *more* trustworthy.
      final dual = TrustBreakdown(
        visibility: 0.5,
        agreement: 0.0,
        temporal: 0.5,
        geometry: 0.5,
        agreementAvailable: true,
      );
      expect(weak.score, greaterThanOrEqualTo(dual.score));
    });

    test('hard gates hold regardless of score', () {
      final b = TrustBreakdown(
        visibility: 1,
        agreement: 1,
        temporal: 1,
        geometry: 1,
        agreementAvailable: true,
        blocking: [HoldReason.multiplePeople],
      );
      expect(b.score, closeTo(1.0, 1e-9),
          reason: 'score stays visible for diagnostics');
      expect(b.held, isTrue);
      expect(b.reason, HoldReason.multiplePeople);
    });

    test('reason priority: visibility, then agreement, then stability', () {
      TrustBreakdown lowVis() => TrustBreakdown(
          visibility: 0.5,
          agreement: 0.5,
          temporal: 0.5,
          geometry: 0.5,
          agreementAvailable: true);
      expect(lowVis().reason, HoldReason.lowVisibility);
      final disagree = TrustBreakdown(
          visibility: 0.9,
          agreement: 0.5,
          temporal: 0.9,
          geometry: 0.9,
          agreementAvailable: true);
      expect(disagree.score, lessThan(trustThreshold));
      expect(disagree.reason, HoldReason.modelDisagreement);
    });
  });

  group('visibilityScore', () {
    test('core joints dominate; faces cannot sink a squat', () {
      final v = _vis(1.0);
      // Zero out every facial landmark (0..10).
      for (var i = 0; i <= 10; i++) {
        v[i] = 0.0;
      }
      expect(visibilityScore(v), closeTo(1.0, 1e-9));
      expect(visibilityScore(_vis(0.0)), 0.0);
      expect(visibilityScore([0.5, 0.5]), 0.0,
          reason: 'wrong length is unusable, not half');
    });
  });

  group('temporalScore', () {
    test('smooth sweeps pass, jitter fails, short history is neutral', () {
      expect(temporalScore([150.0, 140.0, 130.0, 120.0]), closeTo(1.0, 0.05));
      expect(temporalScore([150.0]), 0.5);
      expect(temporalScore([150.0, 120.0, 150.0, 120.0, 150.0, 120.0]),
          lessThan(0.5));
    });
  });

  group('geometryScore', () {
    test('sane standing pose passes; garbage fails', () {
      // Upright figure with slightly soft joints (perfectly straight
      // limbs are collinear — correctly penalised as degenerate).
      List<List<double>> pose() => _grid((i) {
            const xs = {
              11: 0.4, 12: 0.6, 13: 0.36, 14: 0.64, 15: 0.30, 16: 0.70,
              23: 0.42, 24: 0.58, 25: 0.45, 26: 0.55, 27: 0.42, 28: 0.58,
            };
            return (xs[i] ?? 0.5);
          });
      List<List<double>> ys() {
        final g = pose();
        const yy = {
          11: 0.2, 12: 0.2, 13: 0.35, 14: 0.35, 15: 0.5, 16: 0.5,
          23: 0.5, 24: 0.5, 25: 0.75, 26: 0.75, 27: 0.95, 28: 0.95,
        };
        for (var i = 0; i < 33; i++) {
          g[i][1] = yy[i] ?? 0.1;
        }
        return g;
      }

      final good = geometryScore(ys(), null);
      expect(good, greaterThan(0.85));
      final nan = geometryScore(
          _grid((_) => double.nan), null);
      expect(nan, lessThan(0.5));
      // Half the joints out of frame drags the score down.
      final out = ys();
      for (var i = 0; i < 17; i++) {
        out[i][0] = 2.5;
      }
      expect(geometryScore(out, null), lessThan(good));
    });
  });

  group('frameCompleteness', () {
    test('fraction above 0.5', () {
      expect(frameCompleteness([]), 0.0);
      expect(frameCompleteness(_vis(0.9)), 1.0);
      final half = _vis(0.9);
      for (var i = 0; i < 17; i++) {
        half[i] = 0.1;
      }
      expect(frameCompleteness(half), closeTo(16 / 33, 1e-9));
    });
  });

  group('crossModelAgreement', () {
    test('identical predictions agree; shifted ones do not', () {
      final mp = _grid((i) => 0.2 + (i % 8) * 0.05);
      final vis = _vis(0.9);
      final same = crossModelAgreement(mp, vis, mp, vis);
      expect(same.score, closeTo(1.0, 1e-9));
      expect(same.perJoint.length, verifierJoints.length);
      final shifted = [for (final p in mp) [p[0] + 0.5, p[1]]];
      final bad = crossModelAgreement(mp, vis, shifted, vis);
      expect(bad.score, lessThan(0.5));
    });

    test('MoveNet silence is excluded, not punished', () {
      final mp = _grid((i) => 0.3);
      final vis = _vis(0.9);
      final mv = _grid((_) => double.nan);
      final silent = crossModelAgreement(mp, vis, mv, _vis(0.0));
      expect(silent.score, 0.0);
      expect(silent.perJoint, isEmpty,
          reason: 'no opinion anywhere ⇒ unavailable upstream');
    });

    test('coco map covers the 12 verifier joints', () {
      final blaze = movenetToBlazepose.values.toSet();
      for (final j in verifierJoints) {
        expect(blaze, contains(j));
      }
      expect(movenetToBlazepose.length, 17);
    });
  });

  group('side selection', () {
    test('sideValue combines only when both sides are solid', () {
      expect(
          sideValue(left: 100, right: 110, leftVis: 0.9, rightVis: 0.9), 105.0);
      expect(
          sideValue(left: 100, right: 30, leftVis: 0.9, rightVis: 0.1), 100.0,
          reason: 'occluded right must not drag the average');
      expect(
          sideValue(left: 30, right: 110, leftVis: 0.1, rightVis: 0.9), 110.0);
      expect(
          sideValue(left: double.nan, right: double.nan,
              leftVis: 0.0, rightVis: 0.0),
          isNaN,
          reason: 'never a guess');
    });

    test('minSide takes the most-flexed visible side', () {
      expect(minSide(left: 90, right: 120, leftVis: 0.9, rightVis: 0.9), 90.0);
      expect(minSide(left: 90, right: 120, leftVis: 0.1, rightVis: 0.9), 120.0);
      expect(
          minSide(left: 90, right: 120, leftVis: 0.1, rightVis: 0.1), isNaN);
    });
  });

  group('TrustAccumulator', () {
    TrustBreakdown good() => TrustBreakdown(
        visibility: 0.95,
        agreement: 0.95,
        temporal: 0.95,
        geometry: 0.95,
        agreementAvailable: true);

    test('clean rep commits; thin history does not', () {
      final acc = TrustAccumulator();
      acc.push(good());
      acc.push(good());
      var v = acc.verdict();
      expect(v.$1, isFalse, reason: 'fewer than 4 frames');
      acc.push(good());
      acc.push(good());
      v = acc.verdict();
      expect(v.$1, isTrue);
      expect(v.$2, greaterThanOrEqualTo(0.85));
      expect(v.$3, HoldReason.none);
    });

    test('weakest frames decide (30th percentile, not the mean)', () {
      // One bad frame of eight does NOT veto (matches the reference:
      // linear interpolation lands on a good frame).
      final lucky = TrustAccumulator();
      for (var i = 0; i < 7; i++) {
        lucky.push(good());
      }
      lucky.push(TrustBreakdown(
          visibility: 0.4,
          agreement: 0.4,
          temporal: 0.4,
          geometry: 0.4,
          agreementAvailable: true));
      expect(lucky.verdict().$1, isTrue,
          reason: 'a single dropped frame does not veto the whole rep');
      // Three bad frames of eight DO veto.
      final acc = TrustAccumulator();
      for (var i = 0; i < 5; i++) {
        acc.push(good());
      }
      for (var i = 0; i < 3; i++) {
        acc.push(TrustBreakdown(
            visibility: 0.4,
            agreement: 0.4,
            temporal: 0.4,
            geometry: 0.4,
            agreementAvailable: true));
      }
      final v = acc.verdict();
      expect(v.$1, isFalse,
          reason: 'sustained weak frames matter at the 30th percentile');
      expect(v.$2, lessThan(0.85));
    });

    test('hard gates (beyond transient visibility) veto the rep', () {
      final acc = TrustAccumulator();
      for (var i = 0; i < 3; i++) {
        acc.push(good());
      }
      acc.push(TrustBreakdown(
          visibility: 0.9,
          agreement: 0.9,
          temporal: 0.9,
          geometry: 0.9,
          agreementAvailable: true,
          blocking: [HoldReason.multiplePeople]));
      final v = acc.verdict();
      expect(v.$1, isFalse);
      expect(v.$3, HoldReason.multiplePeople);
    });
  });
}
