/// Batch 5 — PoseLandmarker frame path through the analyzer on pure Dart:
/// adapter (normalised → upright pixels), smoothing, angles, trust gate,
/// brain feed. No camera, no platform channels, no TFLite.
library;

import 'dart:typed_data';

import 'package:fixpose/core/pose/exercise_catalog.dart';
import 'package:fixpose/core/pose/exercise_definition.dart';
import 'package:fixpose/core/pose/movenet_verifier.dart';
import 'package:fixpose/core/pose/pose_analyzer.dart';
import 'package:fixpose/core/pose/pose_landmarker_source.dart';
import 'package:fixpose/core/pose/trust_gate.dart';
import 'package:flutter_test/flutter_test.dart';

/// Standing person in upright-frame normalised coords (720 x 1280).
/// Joints slightly soft — perfectly straight limbs are collinear and the
/// geometry gate correctly penalises them as degenerate.
LandmarkerFrame33 _standingFrame({double vis = 0.9}) {
  const pts = {
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
  return LandmarkerFrame33(
    imageXY: [for (var i = 0; i < 33; i++) pts[i]!],
    z: List<double>.filled(33, 0.0),
    vis: List<double>.filled(33, vis),
    world: [
      for (var i = 0; i < 33; i++) [pts[i]![0], pts[i]![1], 0.0]
    ],
    thumb: MoveNetThumb(
      rgb: Uint8List(256 * 256 * 3),
      srcWidth: 720,
      srcHeight: 1280,
      size: 256,
      padLeft: 56.0,
      padTop: 0.0,
      scaledW: 144.0,
      scaledH: 256.0,
    ),
    inferenceMs: 25.0,
    frameW: 720.0,
    frameH: 1280.0,
  );
}

void main() {
  late PoseAnalyzer analyzer;

  setUpAll(registerExerciseCatalog);

  setUp(() {
    final def = ExerciseRegistry.instance.resolve('squat')!;
    analyzer = PoseAnalyzer(def);
  });

  test('landmarker frames flow adapter → trust → brain', () async {
    PoseFrameResult? last;
    for (var i = 0; i < 8; i++) {
      last = await analyzer.processLandmarkerFrame(
        _standingFrame(),
        inferenceMs: 25,
        nowMs: 1000 + i * 100,
      );
    }
    expect(last, isNotNull);
    // Cold temporal history redistributes (unknown, not mediocre), so
    // settled high-vis frames feed the FSM from the start — no startup
    // freeze while the history warms up.
    expect(last!.brain, isNotNull,
        reason: 'smooth high-vis frames must feed the FSM');
    expect(last.brain!.currentState, 'standing');
    expect(last.brain!.trust, isNotNull);
    expect(last.trust, isNull, reason: 'unheld frames carry no banner');
    expect(analyzer.lastPosesFound, 1);
  });

  test('weak-but-visible frames hold with a surfaced reason', () async {
    for (var i = 0; i < 6; i++) {
      await analyzer.processLandmarkerFrame(
        _standingFrame(),
        inferenceMs: 25,
        nowMs: 1000 + i * 100,
      );
    }
    // 0.55 clears the 0.5 visibility gate (not occluded) but fails trust.
    final weak = await analyzer.processLandmarkerFrame(
      _standingFrame(vis: 0.55),
      inferenceMs: 25,
      nowMs: 1700,
    );
    expect(weak, isNotNull);
    expect(weak!.brain, isNull, reason: 'held frames never reach the FSM');
    expect(weak.trust, isNotNull);
    expect(weak.trust!.held, isTrue);
    expect(weak.trust!.reason, HoldReason.lowVisibility);
  });

  test('malformed frames never throw', () async {    final broken = LandmarkerFrame33(
      imageXY: const [
        [0.5, 0.5]
      ],
      z: const [0.0],
      vis: const [0.9],
      world: null,
      thumb: MoveNetThumb(
        rgb: Uint8List(256 * 256 * 3),
        srcWidth: 1,
        srcHeight: 1,
        size: 256,
        padLeft: 0,
        padTop: 0,
        scaledW: 1,
        scaledH: 1,
      ),
      inferenceMs: 1,
      frameW: 1,
      frameH: 1,
    );
    expect(
        await analyzer.processLandmarkerFrame(broken,
            inferenceMs: 1, nowMs: 2000),
        isNull);
  });

  test('partial visibility still counts while measuring joints are solid',
      () async {
    // Face, arms, hands and feet gone — squat only measures the legs.
    PoseFrameResult? last;
    for (var i = 0; i < 8; i++) {
      final frame = _standingFrame();
      for (var j = 0; j <= 22; j++) {
        frame.vis[j] = 0.0;
      }
      for (var j = 29; j <= 32; j++) {
        frame.vis[j] = 0.0;
      }
      last = await analyzer.processLandmarkerFrame(
        frame,
        inferenceMs: 25,
        nowMs: 1000 + i * 100,
      );
    }
    expect(last, isNotNull);
    expect(last!.brain, isNotNull,
        reason: 'legs solid ⇒ squat keeps counting without face/arms');
    expect(last.brain!.currentState, 'standing');
  });

  test('occluded measuring joint holds as occluded, never miscounts',
      () async {
    PoseFrameResult? last;
    for (var i = 0; i < 8; i++) {
      final frame = _standingFrame();
      if (i >= 4) frame.vis[25] = 0.1; // left knee (primary vertex) lost
      last = await analyzer.processLandmarkerFrame(
        frame,
        inferenceMs: 25,
        nowMs: 1000 + i * 100,
      );
    }
    expect(last, isNotNull);
    expect(last!.brain, isNull,
        reason: 'primary vertex gone ⇒ hold, never a guessed rep');
    expect(last.lockReason, LockReason.occluded);
  });
}
