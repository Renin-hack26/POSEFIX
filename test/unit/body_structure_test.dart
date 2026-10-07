/// Round 3 — complete-body structure: canonical bone graph integrity,
/// per-frame segment math, posture metrics, and the complete-body
/// geometry lists fed to the trust gate. Pure Dart (synthetic frames).
library;

import 'dart:math' as math;

import 'package:fixpose/core/pose/body_structure.dart';
import 'package:fixpose/core/pose/exercise_definition.dart';
import 'package:fixpose/core/pose/pose_math.dart' as pm;
import 'package:fixpose/core/pose/trust_gate.dart';
import 'package:flutter_test/flutter_test.dart';

/// Standing person in upright normalised coords — mirrors the reference
/// frame from pose_landmarker_path_test (all 33 joints, slightly soft
/// joints so nothing is collinear-degenerate).
Map<int, List<double>> _standingPts() => const {
      0: [0.50, 0.08], // nose
      1: [0.47, 0.07], 2: [0.46, 0.07], 3: [0.44, 0.07], // left eye trio
      4: [0.53, 0.07], 5: [0.54, 0.07], 6: [0.56, 0.07], // right eye trio
      7: [0.42, 0.08], 8: [0.58, 0.08], // ears
      9: [0.48, 0.11], 10: [0.52, 0.11], // mouth
      11: [0.40, 0.20], 12: [0.60, 0.20], // shoulders
      13: [0.36, 0.35], 14: [0.64, 0.35], // elbows
      15: [0.30, 0.50], 16: [0.70, 0.50], // wrists
      17: [0.28, 0.54], 18: [0.72, 0.54], // pinkies
      19: [0.29, 0.55], 20: [0.71, 0.55], // indices
      21: [0.28, 0.52], 22: [0.72, 0.52], // thumbs
      23: [0.42, 0.50], 24: [0.58, 0.50], // hips
      25: [0.45, 0.75], 26: [0.55, 0.75], // knees
      27: [0.42, 0.95], 28: [0.58, 0.95], // ankles
      29: [0.40, 0.97], 30: [0.60, 0.97], // heels
      31: [0.43, 0.99], 32: [0.57, 0.99], // foot indices
    };

List<pm.LmPoint?> _xy(Map<int, List<double>> pts) => [
      for (var i = 0; i < 33; i++)
        pts[i] == null ? null : (x: pts[i]![0], y: pts[i]![1]),
    ];

BodyStructure _structure({double vis = 0.9, Map<int, double>? visOverride}) =>
    BodyStructure.fromFrame(
      xy: _xy(_standingPts()),
      vis: [
        for (var i = 0; i < 33; i++) visOverride?[i] ?? vis,
      ],
    );

void main() {
  group('bone graph', () {
    test('complete body — 41 bones, all indices valid, unique ids', () {
      expect(BodyStructure.bones.length, 41);
      final ids = <String>{};
      for (final b in BodyStructure.bones) {
        expect(b.a, inInclusiveRange(0, 32), reason: b.id);
        expect(b.b, inInclusiveRange(0, 32), reason: b.id);
        expect(b.a, isNot(b.b), reason: b.id);
        expect(ids.add(b.id), isTrue, reason: 'duplicate id ${b.id}');
      }
    });

    test('every side bone has a mirrored twin', () {
      final byId = {for (final b in BodyStructure.bones) b.id: b};
      const mirror = {
        'torso_l': ('torso_r', 12, 24),
        'upper_arm_l': ('upper_arm_r', 12, 14),
        'forearm_l': ('forearm_r', 14, 16),
        'palm_edge_l': ('palm_edge_r', 16, 18),
        'knuckle_l': ('knuckle_r', 18, 20),
        'thumb_line_l': ('thumb_line_r', 20, 22),
        'thumb_side_l': ('thumb_side_r', 16, 22),
        'thigh_l': ('thigh_r', 24, 26),
        'shank_l': ('shank_r', 26, 28),
        'heel_l': ('heel_r', 28, 30),
        'toe_l': ('toe_r', 28, 32),
        'sole_l': ('sole_r', 30, 32),
        'neck_l': ('neck_r', 8, 12),
        'jaw_l': ('jaw_r', 10, 8),
        'nose_mouth_l': ('nose_mouth_r', 0, 10),
        'nose_eye_l': ('nose_eye_r', 0, 5),
        'ear_eye_l': ('ear_eye_r', 6, 8),
        'eye_l_a': ('eye_r_a', 4, 5),
        'eye_l_b': ('eye_r_b', 5, 6),
      };
      for (final entry in mirror.entries) {
        final l = byId[entry.key];
        expect(l, isNotNull, reason: 'missing ${entry.key}');
        final (rightId, ra, rb) = entry.value;
        final r = byId[rightId];
        expect(r, isNotNull, reason: 'missing twin $rightId');
        expect((r!.a, r.b), (ra, rb), reason: rightId);
        // Side bones live in mirrored groups (armL↔armR); midline bones
        // (face, neck) share the head group on both sides.
        final String mirroredGroup = l!.group.name.endsWith('L')
            ? '${l.group.name.substring(0, l.group.name.length - 1)}R'
            : l.group.name;
        expect(r.group.name, mirroredGroup, reason: rightId);
        expect(r.tier, l.tier, reason: rightId);
      }
    });

    test('tiers cover the overlay stroke plan', () {
      int count(BoneTier t) =>
          BodyStructure.bones.where((b) => b.tier == t).length;
      expect(count(BoneTier.major), 12);
      expect(count(BoneTier.appendage), 14);
      expect(count(BoneTier.face), 13);
      expect(count(BoneTier.neck), 2);
      // Groups: complete body — no group left empty.
      for (final g in BodyGroup.values) {
        expect(
          BodyStructure.bones.where((b) => b.group == g).isNotEmpty,
          isTrue,
          reason: 'group $g has no bones',
        );
      }
    });

    test('geometry lists are a superset of the trust reference pairs', () {
      // Reference pairs from the original geometryScore.
      const refWorld = [
        [23, 25],
        [25, 27],
        [24, 26],
        [26, 28],
        [11, 13],
        [12, 14],
      ];
      const refTriples = [
        [23, 25, 27],
        [24, 26, 28],
        [11, 13, 15],
        [12, 14, 16],
      ];
      for (final p in refWorld) {
        expect(BodyStructure.worldBonePairs, contains(p));
      }
      for (final t in refTriples) {
        expect(BodyStructure.jointTriples, contains(t));
      }
      expect(BodyStructure.worldBonePairs.length, greaterThan(6));
      expect(BodyStructure.jointTriples.length, greaterThan(4));
      for (final p in [...BodyStructure.worldBonePairs, ...BodyStructure.jointTriples]) {
        for (final i in p) {
          expect(i, inInclusiveRange(0, 32));
        }
      }
    });
  });

  group('per-frame segments', () {
    test('solid frame measures every bone', () {
      final s = _structure();
      expect(s.segments.length, BodyStructure.bones.length);
      expect(s.overallCoverage, 1.0);
      expect(s.coverage(BodyGroup.torso), 1.0);
      expect(s.coverage(BodyGroup.handL), 1.0);

      // Upper-arm length matches the synthetic geometry exactly.
      final arm = s.segment('upper_arm_l');
      expect(arm.reliable, isTrue);
      const dx = 0.40 - 0.36, dy = 0.20 - 0.35;
      expect(arm.length, closeTo(math.sqrt(dx * dx + dy * dy), 1e-9));
    });

    test('low-confidence landmark takes its bones out of judgment', () {
      final s = _structure(visOverride: const {11: 0.2});
      // Shoulder 11 weak ⇒ shoulder_line, torso_l, upper_arm_l unmeasurable
      // for posture — hip_line (23–24) unaffected.
      expect(s.segment('shoulder_line').reliable, isFalse);
      expect(s.segment('torso_l').reliable, isFalse);
      expect(s.segment('upper_arm_l').reliable, isFalse);
      expect(s.segment('hip_line').reliable, isTrue);
      // Right side stays judgeable: torso_r (12–24) + hip_line (23–24)
      // solid ⇒ 2 of 4 torso bones.
      expect(s.coverage(BodyGroup.torso), closeTo(0.5, 1e-9));
      expect(s.overallCoverage, lessThan(1.0));
    });

    test('missing landmark ⇒ segment not measurable, no throw', () {
      final xy = _xy(_standingPts());
      xy[13] = null; // left elbow gone
      final s = BodyStructure.fromFrame(
        xy: xy,
        vis: List<double>.filled(33, 0.9),
      );
      expect(s.segment('upper_arm_l').measurable, isFalse);
      expect(s.segment('forearm_l').measurable, isFalse);
      expect(s.angleAt(11, 13, 15), isNull);
      expect(s.posture().torsoLeanDeg, isNotNull); // torso unaffected
    });

    test('wrong joint count is rejected loudly', () {
      expect(
        () => BodyStructure.fromFrame(
          xy: [for (var i = 0; i < 5; i++) null],
          vis: List<double>.filled(5, 0.9),
        ),
        throwsArgumentError,
      );
    });
  });

  group('angles and posture metrics', () {
    test('angleAt matches the shared angle math', () {
      final s = _structure();
      final a = s.angleAt(
        MpLandmark.leftHip,
        MpLandmark.leftKnee,
        MpLandmark.leftAnkle,
      );
      final expected = pm.angleBetween(
        (x: 0.42, y: 0.50),
        (x: 0.45, y: 0.75),
        (x: 0.42, y: 0.95),
      );
      expect(a, closeTo(expected, 1e-9));
    });

    test('jointAngle gates on vertex confidence', () {
      final s = _structure(visOverride: const {25: 0.3});
      expect(s.jointAngle(23, 25, 27), isNull); // knee confidence too low
      expect(s.angleAt(23, 25, 27), isNotNull); // raw angle still available
    });

    test('torso lean: upright ≈ 0°, shifted hips report the tilt', () {
      final upright = _structure();
      expect(upright.torsoLeanDeg, closeTo(0.0, 1e-9));

      final xy = _xy(_standingPts());
      xy[23] = (x: 0.52, y: 0.50);
      xy[24] = (x: 0.68, y: 0.50);
      final leaning = BodyStructure.fromFrame(
        xy: xy,
        vis: List<double>.filled(33, 0.9),
      );
      // Spine mid-shoulder (0.5, 0.2) → mid-hip (0.6, 0.5): atan2(0.1, 0.3).
      expect(leaning.torsoLeanDeg, closeTo(18.434948822922017, 1e-6));
    });

    test('posture report: solid symmetric body is usable and symmetric', () {
      final r = _structure().posture();
      expect(r.coverage, 1.0);
      expect(r.torsoCoverage, 1.0);
      expect(r.torsoLeanDeg, isNotNull);
      expect(r.armSymmetry, closeTo(1.0, 1e-9));
      expect(r.legSymmetry, closeTo(1.0, 1e-9));
      expect(r.coreUsable, isTrue);

      // Lost shoulders ⇒ torso not fully measurable ⇒ not core-usable.
      final broken = _structure(visOverride: const {11: 0.1, 12: 0.1});
      expect(broken.posture().coreUsable, isFalse);
    });

    test('hand axis tracks palm orientation', () {
      final s = _structure();
      // Left wrist (0.30, 0.50) → index (0.29, 0.55): dx −0.01, dy +0.05.
      expect(s.handAxisDeg(left: true), isNotNull);
      expect(s.handAxisDeg(left: true)!,
          closeTo(-11.309932474020213, 1e-6));
    });
  });

  group('trust gate integration', () {
    test('geometryScore accepts the complete-body lists', () {
      final pts = _standingPts();
      final imageXY = [
        for (var i = 0; i < 33; i++) pts[i]!,
      ];
      final world = [
        for (var i = 0; i < 33; i++) [pts[i]![0], pts[i]![1], 0.0],
      ];
      final withStructure = geometryScore(
        imageXY,
        world,
        worldBones: BodyStructure.worldBonePairs,
        jointTriples: BodyStructure.jointTriples,
      );
      expect(withStructure, greaterThan(0.85),
          reason: 'sane full-body frame must stay plausible');
      // Defaults untouched: no named args ⇒ reference behavior.
      expect(geometryScore(imageXY, world), greaterThan(0.85));
    });
  });
}
