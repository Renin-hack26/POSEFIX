/// MoveNet verifier mapping: pad-undo math, COCO→BlazePose placement,
/// NaN discipline, and never-throw behavior.
library;

import 'dart:typed_data';

import 'package:fixpose/core/pose/movenet_verifier.dart';
import 'package:fixpose/core/pose/trust_gate.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake interpreter replaying one canned 17-keypoint output.
class _FakeInterpreter implements MoveNetInterpreter {
  _FakeInterpreter(this.kp);

  final List<double> kp;
  var runs = 0;
  var closed = false;

  @override
  int get size => 256;

  @override
  bool get inputIsFloat => true;

  @override
  List<double> run(Uint8List rgb, int size) {
    runs++;
    return List<double>.of(kp);
  }

  @override
  void close() => closed = true;
}

/// Canned keypoints: everyone at (y=0.5, x=0.5 + i*0.01), score 0.9.
List<double> _canned() => [
      for (var i = 0; i < 17; i++) ...[0.5, 0.5 + i * 0.01, 0.9],
    ];

const _nan = double.nan;

void main() {
  group('MoveNetThumb.toFrame', () {
    test('identity (no padding) passes coordinates through', () {
      final thumb = MoveNetThumb(
        rgb: Uint8List(0),
        srcWidth: 256,
        srcHeight: 256,
        size: 256,
        padLeft: 0,
        padTop: 0,
        scaledW: 256,
        scaledH: 256,
      );
      final (fx, fy) = thumb.toFrame(0.25, 0.75);
      expect(fx, closeTo(0.25, 1e-9));
      expect(fy, closeTo(0.75, 1e-9));
    });

    test('letterbox padding is undone', () {
      // 1280x720 frame into a 256 square: scale = 0.2, content 256x144,
      // vertical bars of 56 px top/bottom.
      final thumb = MoveNetThumb(
        rgb: Uint8List(0),
        srcWidth: 1280,
        srcHeight: 720,
        size: 256,
        padLeft: 0,
        padTop: 56,
        scaledW: 256,
        scaledH: 144,
      );
      // Canvas centre (0.5, 0.5) must map to frame centre (0.5, 0.5).
      final (fx, fy) = thumb.toFrame(0.5, 0.5);
      expect(fx, closeTo(0.5, 1e-9));
      expect(fy, closeTo(0.5, 1e-9));
      // Canvas top-left maps above the frame (clamped by callers).
      final (ex, ey) = thumb.toFrame(0.0, 0.0);
      expect(ex, closeTo(0.0, 1e-9));
      expect(ey, lessThan(0.0));
    });
  });

  group('MoveNetVerifier.verify', () {
    test('maps COCO keypoints into 33-joint space', () async {
      final verifier =
          MoveNetVerifier(interpreter: _FakeInterpreter(_canned()));
      final thumb = MoveNetThumb(
        rgb: Uint8List(256 * 256 * 3),
        srcWidth: 256,
        srcHeight: 256,
        size: 256,
        padLeft: 0,
        padTop: 0,
        scaledW: 256,
        scaledH: 256,
      );
      final result = (await verifier.verify(thumb))!;
      expect(result.imageXY.length, 33);
      expect(result.vis.length, 33);
      // Spot-check the COCO map: mv 5 (left_shoulder, x=0.55) → blaze 11.
      expect(result.imageXY[11][0], closeTo(0.55, 1e-9));
      expect(result.imageXY[11][1], closeTo(0.5, 1e-9));
      expect(result.vis[11], closeTo(0.9, 1e-9));
      // mv 0 (nose, x=0.5) → blaze 0.
      expect(result.imageXY[0][0], closeTo(0.5, 1e-9));
      // Unmapped joints stay NaN with zero visibility — never interpolated.
      expect(result.imageXY[1][0].isNaN, isTrue);
      expect(result.vis[1], 0.0);
      expect(result.hasOpinion, isTrue);
      expect(result.inferenceMs, greaterThanOrEqualTo(0.0));
    });

    test('NaN keypoints and clipped scores are disciplined', () async {
      final kp = _canned();
      kp[5 * 3] = _nan; // left_shoulder y = NaN
      kp[6 * 3 + 2] = 7.0; // right_shoulder score way over range
      final verifier = MoveNetVerifier(interpreter: _FakeInterpreter(kp));
      final thumb = MoveNetThumb(
        rgb: Uint8List(256 * 256 * 3),
        srcWidth: 256,
        srcHeight: 256,
        size: 256,
        padLeft: 0,
        padTop: 0,
        scaledW: 256,
        scaledH: 256,
      );
      final result = (await verifier.verify(thumb))!;
      expect(result.imageXY[11][0].isNaN, isTrue,
          reason: 'NaN input stays NaN');
      expect(result.vis[11], 0.0);
      expect(result.vis[12], 1.0, reason: 'scores clip to [0, 1]');
    });

    test('unavailable verifier verifies nothing, never throws', () async {
      final verifier = MoveNetVerifier();
      expect(verifier.ready, isFalse);
      final thumb = MoveNetThumb(
        rgb: Uint8List(0),
        srcWidth: 1,
        srcHeight: 1,
        size: 256,
        padLeft: 0,
        padTop: 0,
        scaledW: 1,
        scaledH: 1,
      );
      expect(await verifier.verify(thumb), isNull);
      verifier.close();
    });

    test('verifier output feeds agreement end to end', () async {
      final verifier =
          MoveNetVerifier(interpreter: _FakeInterpreter(_canned()));
      final thumb = MoveNetThumb(
        rgb: Uint8List(256 * 256 * 3),
        srcWidth: 256,
        srcHeight: 256,
        size: 256,
        padLeft: 0,
        padTop: 0,
        scaledW: 256,
        scaledH: 256,
      );
      final mv = (await verifier.verify(thumb))!;
      // Landmarker agrees almost exactly: derive mp from the same canned
      // keypoints (plus a whisper of noise).
      final inv = {
        for (final e in movenetToBlazepose.entries) e.value: e.key
      };
      final mpXY = List<List<double>>.generate(33, (j) {
        final m = inv[j];
        if (m == null) return [0.5, 0.5];
        return [0.5 + m * 0.01 + 0.001, 0.5 + 0.001];
      });
      final mpVis = List<double>.filled(33, 0.9);
      final (:score, :perJoint) = crossModelAgreement(
          mpXY, mpVis, mv.imageXY, mv.vis);
      expect(perJoint.length, verifierJoints.length);
      expect(score, greaterThan(0.9));
    });
  });
}
