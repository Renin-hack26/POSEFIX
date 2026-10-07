/// PoseAnalyzer pipeline — frame intake, person-lock state machine,
/// visibility gate, framing cues, EMA overlay smoothing and the
/// video-playback rhythm guard.
///
/// The ML Kit detector is replaced by a mocked `google_mlkit_pose_detector`
/// method channel, so synthetic poses flow through the REAL pipeline
/// (frame conversion → detection → lock → visibility → smoothing → brain)
/// without camera hardware or plugin binaries.
library;

import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart'
    show CameraImageData, CameraImageFormat, CameraImagePlane;
import 'package:fixpose/core/pose/exercise_catalog.dart';
import 'package:fixpose/core/pose/exercise_definition.dart';
import 'package:fixpose/core/pose/pose_analyzer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

const MethodChannel _mlkit = MethodChannel('google_mlkit_pose_detector');

const int _w = 480;
const int _h = 640;

/// Poses the mocked detector returns for the next frame: one entry per
/// detected person.
List<List<Map<String, Object>>> _detected = const [];

Future<Object?> _mockHandler(MethodCall call) async {
  if (call.method == 'vision#startPoseDetector') return _detected;
  return null; // e.g. vision#closePoseDetector
}

Map<String, Object> _lm(
  PoseLandmarkType type,
  double x,
  double y, {
  double likelihood = 0.95,
}) =>
    {'type': type.index, 'x': x, 'y': y, 'z': 0.0, 'likelihood': likelihood};

/// Standing squat: knees/hips/shoulders/ankles aligned → primary = 180°,
/// bbox comfortably inside the framing zones.
List<Map<String, Object>> _standing() => [
      _lm(PoseLandmarkType.leftShoulder, 216, 96),
      _lm(PoseLandmarkType.rightShoulder, 264, 96),
      _lm(PoseLandmarkType.leftHip, 216, 320),
      _lm(PoseLandmarkType.rightHip, 264, 320),
      _lm(PoseLandmarkType.leftKnee, 216, 416),
      _lm(PoseLandmarkType.rightKnee, 264, 416),
      _lm(PoseLandmarkType.leftAnkle, 216, 512),
      _lm(PoseLandmarkType.rightAnkle, 264, 512),
    ];

/// Squat bottom: knees travel forward → primary ≈ 84° (≤ 90 = real depth).
List<Map<String, Object>> _bottom() => [
      _lm(PoseLandmarkType.leftShoulder, 216, 96),
      _lm(PoseLandmarkType.rightShoulder, 264, 96),
      _lm(PoseLandmarkType.leftHip, 216, 282),
      _lm(PoseLandmarkType.rightHip, 264, 282),
      _lm(PoseLandmarkType.leftKnee, 360, 422),
      _lm(PoseLandmarkType.rightKnee, 408, 422),
      _lm(PoseLandmarkType.leftAnkle, 216, 544),
      _lm(PoseLandmarkType.rightAnkle, 264, 544),
    ];

/// Push-up landmarks: [frontal] tall+narrow, [sideOn] wide+flat.
List<Map<String, Object>> _pushUpFrontal() => [
      _lm(PoseLandmarkType.leftShoulder, 216, 96),
      _lm(PoseLandmarkType.rightShoulder, 264, 96),
      _lm(PoseLandmarkType.leftElbow, 216, 240),
      _lm(PoseLandmarkType.rightElbow, 264, 240),
      _lm(PoseLandmarkType.leftWrist, 216, 384),
      _lm(PoseLandmarkType.rightWrist, 264, 384),
      _lm(PoseLandmarkType.leftHip, 216, 352),
      _lm(PoseLandmarkType.rightHip, 264, 352),
      _lm(PoseLandmarkType.leftAnkle, 216, 544),
      _lm(PoseLandmarkType.rightAnkle, 264, 544),
    ];

List<Map<String, Object>> _pushUpSideOn() => [
      _lm(PoseLandmarkType.leftShoulder, 72, 288),
      _lm(PoseLandmarkType.rightShoulder, 120, 288),
      _lm(PoseLandmarkType.leftElbow, 192, 320),
      _lm(PoseLandmarkType.rightElbow, 240, 320),
      _lm(PoseLandmarkType.leftWrist, 288, 336),
      _lm(PoseLandmarkType.rightWrist, 336, 336),
      _lm(PoseLandmarkType.leftHip, 336, 320),
      _lm(PoseLandmarkType.rightHip, 384, 320),
      _lm(PoseLandmarkType.leftAnkle, 384, 320),
      _lm(PoseLandmarkType.rightAnkle, 408, 336),
    ];

List<Map<String, Object>> _shifted(
  List<Map<String, Object>> pose, {
  double dx = 0,
  double dy = 0,
}) =>
    [
      for (final lm in pose)
        _lm(
          PoseLandmarkType.values[lm['type'] as int],
          (lm['x'] as double) + dx,
          (lm['y'] as double) + dy,
          likelihood: lm['likelihood'] as double,
        ),
    ];

// ---------------------------------------------------------------------------
// Camera frame fixtures
// ---------------------------------------------------------------------------

CameraImage _image(
  ImageFormatGroup group, {
  required List<CameraImagePlane> planes,
}) =>
    CameraImage.fromPlatformInterface(
      CameraImageData(
        width: _w,
        height: _h,
        format: CameraImageFormat(group, raw: 0),
        planes: planes,
      ),
    );

CameraImagePlane _plane(Uint8List bytes, int bytesPerRow, [int? bytesPerPixel]) =>
    CameraImagePlane(
      bytes: bytes,
      bytesPerRow: bytesPerRow,
      bytesPerPixel: bytesPerPixel,
      height: _h,
      width: _w,
    );

/// Single-plane frames (BGRA8888 is the controller's preferred format).
CameraImage _singlePlane(ImageFormatGroup group) => _image(
      group,
      planes: [
        _plane(
          Uint8List(
            group == ImageFormatGroup.nv21 ? _w * _h * 3 ~/ 2 : _w * _h,
          ),
          _w,
          1,
        ),
      ],
    );

/// Proper YUV_420_888 (Y + U + V planes), optionally with a broken Y plane.
CameraImage _yuv420({bool brokenY = false}) => _image(
      ImageFormatGroup.yuv420,
      planes: [
        _plane(Uint8List(brokenY ? 8 : _w * _h), _w, 1),
        _plane(Uint8List((_w ~/ 2) * (_h ~/ 2)), _w ~/ 2, 1),
        _plane(Uint8List((_w ~/ 2) * (_h ~/ 2)), _w ~/ 2, 1),
      ],
    );

Future<PoseAnalyzer> _started({
  double minIntervalMs = 0,
  ExerciseDefinition definition = squatDefinition,
}) async {
  final analyzer = PoseAnalyzer(definition, minIntervalMs: minIntervalMs);
  await analyzer.start();
  return analyzer;
}

Future<PoseFrameResult?> _frame(
  PoseAnalyzer analyzer, {
  CameraImage? image,
  InputImageRotation rotation = InputImageRotation.rotation0deg,
  Duration? delay,
}) async {
  if (delay != null) await Future<void>.delayed(delay);
  return analyzer.processCameraImage(
    image ?? _singlePlane(ImageFormatGroup.bgra8888),
    imageWidth: _w.toDouble(),
    imageHeight: _h.toDouble(),
    rotation: rotation,
  );
}

/// Feeds one frame containing a single [pose].
Future<PoseFrameResult?> _feed(
  PoseAnalyzer analyzer,
  List<Map<String, Object>> pose, {
  Duration? delay,
}) async {
  _detected = [pose];
  return _frame(analyzer, delay: delay);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _detected = const [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_mlkit, _mockHandler);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_mlkit, null);
  });

  group('frame intake', () {
    test('frames before start() are dropped, never analyzed', () async {
      final analyzer = PoseAnalyzer(squatDefinition, minIntervalMs: 0);
      _detected = [_standing()];
      final r = await _frame(analyzer);
      expect(r, isNull);
      expect(analyzer.framesSeen, 0);
      expect(analyzer.lastError, isNull);
    });

    test('an unsupported format group is reported, not fed as garbage',
        () async {
      final analyzer = await _started();
      final r = await _frame(
        analyzer,
        image: _singlePlane(ImageFormatGroup.jpeg),
      );
      expect(r, isNull);
      expect(analyzer.lastError, contains('unsupported format group=jpeg'));
      expect(analyzer.framesSeen, 1, reason: 'the frame was seen, then rejected');
    });

    test('a wrong plane count for the declared group degrades to an error',
        () async {
      final analyzer = await _started();
      // NV21 is single-plane by contract — two planes must be refused.
      final nv21 = _image(
        ImageFormatGroup.nv21,
        planes: [
          _plane(Uint8List(_w * _h), _w, 1),
          _plane(Uint8List(_w * _h ~/ 2), _w, 1),
        ],
      );
      var r = await _frame(analyzer, image: nv21);
      expect(r, isNull);
      expect(analyzer.lastError, contains('unsupported format group=nv21'));

      // YUV420_888 needs exactly three planes.
      r = await _frame(
        analyzer,
        image: _image(
          ImageFormatGroup.yuv420,
          planes: [_plane(Uint8List(_w * _h), _w, 1)],
        ),
      );
      expect(r, isNull);
      expect(analyzer.lastError, contains('unsupported format group=yuv420'));
    });

    test('malformed YUV420 bytes surface an error instead of crashing',
        () async {
      final analyzer = await _started();
      for (var attempt = 1; attempt <= 3; attempt++) {
        final r = await _frame(analyzer, image: _yuv420(brokenY: true));
        expect(r, isNull, reason: 'attempt $attempt must not crash');
        expect(analyzer.lastError, contains('unsupported format group=yuv420'));
        expect(analyzer.framesSeen, attempt,
            reason: 'each attempt was counted');
      }
    });

    test('a well-formed YUV420 frame runs the converted path end to end',
        () async {
      final analyzer = await _started();
      _detected = [_standing()];
      final r = await _frame(analyzer, image: _yuv420());
      expect(r, isNotNull, reason: 'converted NV21 must reach the detector');
      expect(r!.lockReason, LockReason.ok);
      expect(r.posesFound, 1);
      expect(analyzer.lastError, isNull);
    });

    test('the throttle drops frames arriving inside minIntervalMs', () async {
      final analyzer = await _started(minIntervalMs: 30);
      _detected = [_standing()];
      final first = await _frame(analyzer);
      expect(first, isNotNull);
      expect(analyzer.framesSeen, 1);

      // Immediate second frame — inside the 30 ms window: dropped whole.
      final second = await _frame(analyzer);
      expect(second, isNull);
      expect(analyzer.framesSeen, 1, reason: 'throttled frame never analyzed');

      final third = await _frame(
        analyzer,
        delay: const Duration(milliseconds: 40),
      );
      expect(third, isNotNull);
      expect(analyzer.framesSeen, 2, reason: 'window reopened after 40 ms');
    });
  });

  group('person lock', () {
    test('no person pauses counting and clears the overlay', () async {
      final analyzer = await _started();
      _detected = [];
      final r = await _frame(analyzer);
      expect(r!.lockReason, LockReason.noPerson);
      expect(r.personLocked, isFalse);
      expect(r.posesFound, 0);
      expect(r.brain, isNull);
      expect(analyzer.latestPose, isNull);
      expect(analyzer.smoothedPose, isNull);
    });

    test('lock needs two stable frames; the brain only runs once locked',
        () async {
      final analyzer = await _started();
      final first = await _feed(analyzer, _standing());
      expect(first!.lockReason, LockReason.ok,
          reason: 'a person is visible immediately');
      expect(first.personLocked, isFalse,
          reason: 'first frame only primes the lock');
      expect(first.brain, isNull, reason: 'no analysis while unlocked');

      final second = await _feed(analyzer, _standing());
      expect(second!.personLocked, isTrue);
      expect(second.brain, isNotNull, reason: 'locked frames reach the FSM');
      expect(second.visibleCount, 8);
      expect(second.requiredCount, 8);
    });

    test('losing the subject resets the lock — re-lock takes two frames',
        () async {
      final analyzer = await _started();
      await _feed(analyzer, _standing());
      expect((await _feed(analyzer, _standing()))!.personLocked, isTrue);

      _detected = [];
      final gone = await _frame(analyzer);
      expect(gone!.lockReason, LockReason.noPerson);

      // One frame back is not enough — the lock must re-arm first.
      expect((await _feed(analyzer, _standing()))!.personLocked, isFalse);
      expect((await _feed(analyzer, _standing()))!.personLocked, isTrue);
    });

    test('a second person pauses counting until they leave', () async {
      final analyzer = await _started();
      await _feed(analyzer, _standing());
      expect((await _feed(analyzer, _standing()))!.personLocked, isTrue);

      _detected = [_standing(), _shifted(_standing(), dx: 120)];
      final two = await _frame(analyzer);
      expect(two!.lockReason, LockReason.multiPerson);
      expect(two.posesFound, 2);
      expect(two.personLocked, isFalse);
      expect(two.brain, isNull);
      expect(analyzer.smoothedPose, isNull,
          reason: 'the overlay never ghosts the wrong subject');

      expect((await _feed(analyzer, _standing()))!.personLocked, isFalse,
          reason: 'lock re-arms from scratch after a subject change');
      expect((await _feed(analyzer, _standing()))!.personLocked, isTrue);
    });

    test('an abrupt torso jump reports lostTracking, then re-locks', () async {
      final analyzer = await _started();
      await _feed(analyzer, _standing());
      expect((await _feed(analyzer, _standing()))!.personLocked, isTrue);

      // Torso centroid jumps 200 px ≈ 0.42 normalized (> 0.35 continuity bar).
      final jumped = await _feed(analyzer, _shifted(_standing(), dx: 200));
      expect(jumped!.lockReason, LockReason.lostTracking);
      expect(jumped.personLocked, isFalse);
      expect(jumped.brain, isNull);

      expect(
          (await _feed(analyzer, _shifted(_standing(), dx: 200)))!
              .personLocked,
          isFalse);
      expect(
          (await _feed(analyzer, _shifted(_standing(), dx: 200)))!
              .personLocked,
          isTrue,
          reason: 'two stable frames at the new position re-lock');
    });

    test('visibility gate: squat needs all 8 landmarks at ≥ 0.5 confidence',
        () async {
      final analyzer = await _started();
      final pose = _standing();

      // One landmark missing → occluded, counts reported honestly.
      _detected = [pose.sublist(0, 7)];
      var r = await _frame(analyzer);
      expect(r!.lockReason, LockReason.occluded);
      expect(r.visibleCount, 7);
      expect(r.requiredCount, 8);
      expect(r.brain, isNull, reason: 'no FSM frames below the visibility bar');
      expect(analyzer.smoothedPose, isNotNull,
          reason: 'the overlay still tracks what it can see');

      // 8th landmark just below the confidence bar → still occluded.
      final low = [...pose];
      low[7] = _lm(PoseLandmarkType.rightAnkle, 264, 512, likelihood: 0.49);
      _detected = [low];
      r = await _frame(analyzer);
      expect(r!.lockReason, LockReason.occluded);
      expect(r.visibleCount, 7);

      // Exactly at the bar → clears (the gate is inclusive).
      final edge = [...pose];
      edge[7] = _lm(PoseLandmarkType.rightAnkle, 264, 512, likelihood: 0.5);
      _detected = [edge];
      r = await _frame(analyzer);
      expect(r!.lockReason, LockReason.ok);
      expect(r.visibleCount, 8);
      expect(r.requiredCount, 8);
    });
  });

  group('framing cues', () {
    test('a subject clipped at the side asks them to move back in', () async {
      final analyzer = await _started();
      final left = await _feed(analyzer, _shifted(_standing(), dx: -200));
      expect(left!.framing, FramingCue.moveRight,
          reason: 'left edge clipped → move right');

      final other = await _started();
      final right = await _feed(other, _shifted(_standing(), dx: 216));
      expect(right!.framing, FramingCue.moveLeft,
          reason: 'right edge clipped → move left');
    });

    test('the 0.05 / 0.98 edge thresholds are exact', () async {
      // minY = 96-64 = 32 px → 32/640 == 0.05 exactly: still inside.
      final inside = await _started();
      final ok = await _feed(inside, _shifted(_standing(), dy: -64));
      expect(ok!.framing, FramingCue.ok);

      // One notch further out crosses the threshold.
      final outside = await _started();
      final back = await _feed(outside, _shifted(_standing(), dy: -80));
      expect(back!.framing, FramingCue.stepBack);
    });

    test('a tiny subject is told to step back', () async {
      final analyzer = await _started();
      // Whole body inside a 0.25 × 0.25 box → height bar failed.
      final tiny = _shifted(_standing(), dy: 160)
          .map((lm) => _lm(
                PoseLandmarkType.values[lm['type'] as int],
                ((lm['x'] as double) - 216) * 0.6 + 168,
                ((lm['y'] as double) - 96) * 0.4 + 256,
                likelihood: lm['likelihood'] as double,
              ))
          .toList();
      final r = await _feed(analyzer, tiny);
      expect(r!.framing, FramingCue.stepBack);
    });

    test('push-ups demand a side-on view; the wide view passes untouched',
        () async {
      final frontal = await _started(definition: pushUpDefinition);
      final front = await _frame(frontal); // no poses configured yet
      expect(front, isNotNull);
      expect(front!.lockReason, LockReason.noPerson,
          reason: 'first frame had no poses configured');

      _detected = [_pushUpFrontal()];
      final frontR = await _frame(frontal);
      expect(frontR, isNotNull, reason: frontal.lastError);
      expect(frontR!.framing, FramingCue.turnSideways,
          reason: 'tall-narrow blob reads as a frontal view');
      expect(frontR.lockReason, LockReason.ok);
      expect(frontR.visibleCount, 10, reason: 'all push-up landmarks seen');

      final side = await _started(definition: pushUpDefinition);
      _detected = [_pushUpSideOn()];
      final sideR = await _frame(side);
      expect(sideR, isNotNull, reason: side.lastError);
      expect(sideR!.framing, FramingCue.ok,
          reason: 'push-up check runs before the generic height bar');
      expect(sideR.lockReason, LockReason.ok);
    });

    test('normalisation uses upright display dims, not sensor dims', () async {
      // Same sensor buffer, shifted hard right: 480 px sensor x is 1.0 in
      // the upright frame for rotation 0 but only 0.75 after a 90° swap.
      final pose = _shifted(_standing(), dx: 216);

      final portrait = await _started();
      _detected = [pose];
      final r0 = await _frame(portrait);
      expect(r0!.framing, FramingCue.moveLeft);

      final rotated = await _started();
      _detected = [pose];
      final r90 = await _frame(
        rotated,
        rotation: InputImageRotation.rotation90deg,
      );
      expect(r90!.framing, FramingCue.stepBack,
          reason: 'swapped upright dims put the subject below the height bar');
      expect(r90.framing, isNot(FramingCue.moveLeft));
    });

    test('every framing cue has its own spoken line (ok stays silent)', () {
      final lines = {
        for (final cue in FramingCue.values) framingCueLine(cue),
      };
      expect(lines.length, FramingCue.values.length,
          reason: 'distinct copy per cue');
      expect(framingCueLine(FramingCue.ok), isEmpty);
      for (final cue in FramingCue.values.where((c) => c != FramingCue.ok)) {
        expect(framingCueLine(cue).trim(), isNotEmpty, reason: cue.name);
      }
    });
  });

  group('overlay EMA smoothing', () {
    test('first frame passes through raw, big jumps use the adaptive cap',
        () async {
      final analyzer = await _started();
      _detected = [_standing()..add(_lm(PoseLandmarkType.nose, 100, 40))];

      final first = await _frame(analyzer);
      expect(first, isNotNull, reason: analyzer.lastError);
      final nose = analyzer.smoothedPose!.landmarks[PoseLandmarkType.nose]!;
      expect(nose.x, 100, reason: 'the first push passes through raw');
      expect(nose.y, 40);

      // The nose jumps 200 px: alpha = 0.5 + 200 * 0.006 → capped at 0.85,
      // so the overlay lands on 100 * 0.15 + 300 * 0.85 = 270. It trails a
      // hard jump instead of snapping; landmarks that did not move stay put.
      _detected = [_standing()..add(_lm(PoseLandmarkType.nose, 300, 40))];
      final second = await _frame(analyzer);
      expect(second, isNotNull, reason: analyzer.lastError);

      final moved = analyzer.smoothedPose!.landmarks[PoseLandmarkType.nose]!;
      expect(moved.x, closeTo(270, 1e-6));
      expect(moved.y, closeTo(40, 1e-6));
      expect(
        analyzer.smoothedPose!.landmarks[PoseLandmarkType.leftShoulder]!.x,
        closeTo(216, 1e-6),
      );
      // The raw debug copy keeps the un-smoothed coordinates.
      expect(analyzer.latestPose!.landmarks[PoseLandmarkType.nose]!.x, 300);
    });

    test('landmarks under the 0.3 overlay floor are dropped, then rejoin',
        () async {
      final analyzer = await _started();
      _detected = [
        _standing()..add(_lm(PoseLandmarkType.nose, 100, 40, likelihood: 0.29)),
      ];
      final r = await _frame(analyzer);
      expect(r, isNotNull, reason: analyzer.lastError);
      expect(
        analyzer.smoothedPose!.landmarks.containsKey(PoseLandmarkType.nose),
        isFalse,
        reason: '0.29 sits under the overlay floor of 0.3',
      );
      expect(analyzer.smoothedPose!.landmarks[PoseLandmarkType.leftHip],
          isNotNull);

      // Confidence recovers → the landmark joins on its next sighting.
      _detected = [
        _standing()..add(_lm(PoseLandmarkType.nose, 140, 40, likelihood: 0.95)),
      ];
      final r2 = await _frame(analyzer);
      expect(r2, isNotNull, reason: analyzer.lastError);
      expect(analyzer.smoothedPose!.landmarks[PoseLandmarkType.nose]!.x,
          closeTo(140, 1e-6),
          reason: 'first sighting passes through raw');
      expect(analyzer.lastError, isNull);
    });

    test('the overlay keeps tracking while the visibility gate holds the FSM',
        () async {
      final analyzer = await _started();
      _detected = [_standing()];
      final warm = await _frame(analyzer);
      expect(warm, isNotNull, reason: analyzer.lastError);

      // 7 of 8 squat landmarks → occluded, so no frame reaches the brain,
      // but the overlay still follows everything it can see.
      _detected = [
        _standing().sublist(0, 7)..add(_lm(PoseLandmarkType.nose, 100, 40)),
      ];
      final r = await _frame(analyzer);
      expect(r, isNotNull, reason: analyzer.lastError);
      expect(r!.lockReason, LockReason.occluded);
      expect(r.brain, isNull);
      expect(r.visibleCount, 7);
      expect(r.requiredCount, 8);
      expect(analyzer.smoothedPose!.landmarks[PoseLandmarkType.nose]!.x,
          closeTo(100, 1e-6),
          reason: 'overlay moves even while the FSM is paused');
    });

    test('reset() drops the overlay filters and restarts the person lock',
        () async {
      final analyzer = await _started();
      _detected = [_standing()..add(_lm(PoseLandmarkType.nose, 100, 40))];
      final one = await _frame(analyzer);
      expect(one, isNotNull, reason: analyzer.lastError);
      _detected = [_standing()..add(_lm(PoseLandmarkType.nose, 300, 40))];
      final two = await _frame(analyzer);
      expect(two, isNotNull, reason: analyzer.lastError);
      expect(analyzer.smoothedPose!.landmarks[PoseLandmarkType.nose]!.x,
          closeTo(270, 1e-6),
          reason: 'filters are warm before the reset');

      analyzer.reset();
      expect(analyzer.smoothedPose, isNull);
      expect(analyzer.latestPose, isNull);

      // Same pose as before, but the EMA state is gone: raw passthrough.
      final after = await _frame(analyzer);
      expect(after, isNotNull, reason: analyzer.lastError);
      expect(after!.personLocked, isFalse,
          reason: 'the 2-frame lock starts over');
      expect(after.lockReason, LockReason.ok);
      expect(analyzer.smoothedPose!.landmarks[PoseLandmarkType.nose]!.x,
          closeTo(300, 1e-6),
          reason: 'EMA state was cleared — raw passthrough again');
    });
  });

  group('video-playback rhythm guard', () {
    test('machine-perfect cadence pauses counting; human jitter resumes it',
        () async {
      final analyzer = await _started(); // minIntervalMs 0 → no frame drops
      const warm = Duration(milliseconds: 30);
      const pace = Duration(milliseconds: 250);
      const twitch = Duration(milliseconds: 40);

      /// Feeds frame [n] — odd frames stand, even frames squat down.
      Future<PoseFrameResult> step(int n, Duration d) async {
        final r =
            await _feed(analyzer, n.isOdd ? _standing() : _bottom(), delay: d);
        expect(r, isNotNull,
            reason: 'frame $n dropped: ${analyzer.lastError ?? 'throttled'}');
        return r!;
      }

      // Fast warm-up: the guard is blind until the rolling window holds six
      // samples, and only locked frames are sampled (frame 1 just arms the
      // lock), so frames 1-6 cannot be judged.
      for (var n = 1; n <= 6; n++) {
        final r = await step(n, warm);
        expect(r.lockReason, LockReason.ok, reason: 'frame $n');
        if (n > 1) {
          expect(r.brain, isNotNull,
              reason: 'frame $n: regular timing never pauses counting');
        }
      }

      // Machine-perfect metronome: one full below→above cycle every 500 ms.
      // The fourth judged cycle (frame 15) puts CV under 3% → video suspected.
      final cycle = <PoseFrameResult>[];
      for (var n = 7; n <= 16; n++) {
        cycle.add(await step(n, pace));
      }

      // Nothing can be judged before frame 15 (lock armed at 1, first
      // crossing after the sixth sample, then four 2-frame cycles).
      for (var i = 0; i < 8; i++) {
        final n = 7 + i;
        expect(cycle[i].lockReason, LockReason.ok, reason: 'frame $n');
        expect(cycle[i].brain, isNotNull, reason: 'frame $n');
      }

      // Suspicion lands: counting pauses without losing the person or the
      // framing, while the body stays fully visible (the banner explains).
      for (final n in [15, 16]) {
        final r = cycle[n - 7];
        expect(r.lockReason, LockReason.videoPlayback, reason: 'frame $n');
        expect(r.brain, isNull, reason: 'frame $n: no FSM while paused');
        expect(r.personLocked, isFalse,
            reason: 'frame $n: the pause reads as unlocked');
        expect(r.visibleCount, 8, reason: 'frame $n: body fully in frame');
        expect(r.framing, FramingCue.ok, reason: 'frame $n');
      }

      // Rhythm keeps flowing while paused: one wildly uneven cycle (a human
      // stumble) clears the guard, and the very same frame reaches the FSM.
      final resumed = await step(17, twitch);
      expect(resumed.lockReason, LockReason.ok,
          reason: 'CV > 8% means a person, not a played video');
      expect(resumed.brain, isNotNull,
          reason: 'counting resumes on the same frame that cleared the guard');
      expect(resumed.personLocked, isTrue);

      final stayed = await step(18, twitch);
      expect(stayed.lockReason, LockReason.ok);
      expect(stayed.brain, isNotNull,
          reason: 'the guard does not relapse once cleared');
    });
  });
}