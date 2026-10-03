/// Batch 5 — `PoseLandmarkerSource` contract: init/parse/dropped/error
/// paths against a mocked `fixpose/pose_landmarker` channel. The Kotlin
/// side is verified on-device; here both sides agree on the shapes.
library;

import 'package:fixpose/core/pose/pose_landmarker_source.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('fixpose/pose_landmarker');

/// 33 joints × (x, y, z, vis, presence), all usable.
List<List<double>> _joints() => [
      for (var i = 0; i < 33; i++) [0.5, 0.4 + i * 0.001, 0.0, 0.9, 0.9],
    ];

Map<String, dynamic> _detectOk() => {
      'ok': true,
      'found': true,
      'image': _joints(),
      'world': [
        for (var i = 0; i < 33; i++) [0.1 * i, 0.2, 0.0],
      ],
      'thumb': Uint8List(256 * 256 * 3),
      'frameW': 720.0,
      'frameH': 1280.0,
      'srcW': 720,
      'srcH': 1280,
      'size': 256,
      'padLeft': 56.0,
      'padTop': 0.0,
      'scaledW': 144.0,
      'scaledH': 256.0,
      'inferenceMs': 31.5,
    };

Future<LandmarkerFrame33?> _detect(PoseLandmarkerSource source) =>
    source.detectRaw(
      y: Uint8List(720 * 1280),
      u: Uint8List(360 * 640),
      v: Uint8List(360 * 640),
      width: 720,
      height: 1280,
      yRowStride: 720,
      uvRowStride: 360,
      uvPixelStride: 1,
      rotationDeg: 270,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> Function(MethodCall call) handler;
  late List<String> methodsSeen;

  setUp(() {
    methodsSeen = [];
    handler = (_) => {'ok': false};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      methodsSeen.add(call.method);
      return handler(call);
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('init success arms the source', () async {
    handler = (_) => {'ok': true};
    final source = PoseLandmarkerSource();
    expect(await source.init(), isTrue);
    expect(source.ready, isTrue);
    expect(methodsSeen, ['init']);
  });

  test('init failure disarms (ML Kit fallback upstream)', () async {
    handler = (_) => {'ok': false, 'error': 'no model'};
    final source = PoseLandmarkerSource();
    expect(await source.init(), isFalse);
    expect(source.ready, isFalse);
  });

  test('detect parses the full frame incl. presence-folded vis', () async {
    handler = (call) => call.method == 'init' ? {'ok': true} : _detectOk();
    final source = PoseLandmarkerSource();
    expect(await source.init(), isTrue);
    final frame = (await _detect(source))!;
    expect(frame.imageXY.length, 33);
    expect(frame.imageXY[5][0], closeTo(0.5, 1e-9));
    // vis = visibility × presence = 0.81.
    expect(frame.vis[5], closeTo(0.81, 1e-9));
    expect(frame.world!.length, 33);
    expect(frame.frameW, 720.0);
    expect(frame.frameH, 1280.0);
    expect(frame.thumb.scaledW, 144.0);
    expect(frame.inferenceMs, closeTo(31.5, 1e-9));
  });

  test('dropped / not-found / malformed all degrade to null', () async {
    handler = (call) {
      if (call.method == 'init') return {'ok': true};
      return {'ok': true, 'dropped': true};
    };
    final source = PoseLandmarkerSource();
    await source.init();
    expect(await _detect(source), isNull);

    handler = (call) {
      if (call.method == 'init') return {'ok': true};
      return {'ok': true, 'found': false};
    };
    expect(await _detect(source), isNull);

    handler = (call) {
      if (call.method == 'init') return {'ok': true};
      final bad = _detectOk();
      bad['image'] = [
        [0.5, 0.5]
      ];
      return bad;
    };
    expect(await _detect(source), isNull);
  });
}
