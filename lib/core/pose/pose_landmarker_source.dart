/// MediaPipe PoseLandmarker (heavy) source — Batch 5 primary pose stack.
///
/// Runs on-device through the `fixpose/pose_landmarker` Kotlin bridge
/// (VIDEO mode, 1 pose, 0.5/0.5/0.5 confidences — mirroring the reference
/// `MediaPipePose`). Returns 33-joint frames with visibility, presence,
/// world landmarks and a MoveNet thumbnail.
///
/// Any failure (missing plugin on host/tests, model copy failure,
/// dropped frame) degrades to null — the caller falls back to ML Kit, so
/// the camera never dies because of this source.
library;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import 'movenet_verifier.dart';

/// One landmarker frame in 33-joint space.
class LandmarkerFrame33 {
  const LandmarkerFrame33({
    required this.imageXY,
    required this.z,
    required this.vis,
    required this.world,
    required this.thumb,
    required this.inferenceMs,
    required this.frameW,
    required this.frameH,
  });

  /// 33 image-normalised (x, y) pairs in upright-frame space.
  final List<List<double>> imageXY;

  /// 33 image-space z values.
  final List<double> z;

  /// 33 effective visibilities (visibility × presence).
  final List<double> vis;

  /// 33 world (x, y, z) triples, or null when the result has none.
  final List<List<double>>? world;

  /// Letterboxed thumbnail for the MoveNet second opinion.
  final MoveNetThumb thumb;
  final double inferenceMs;

  /// Upright-frame dimensions the normalised coords refer to.
  final double frameW;
  final double frameH;
}

class PoseLandmarkerSource {
  PoseLandmarkerSource({MethodChannel? channel})
      : _channel = channel ??
            const MethodChannel('fixpose/pose_landmarker');

  static const int thumbSize = 256;

  final MethodChannel _channel;
  bool _ready = false;
  bool _inFlight = false;
  bool _initStarted = false;

  bool get ready => _ready;

  /// Idempotent init — false when the bridge/model is unavailable.
  /// Never throws.
  Future<bool> init() async {
    if (_ready) return true;
    if (_initStarted) return false;
    _initStarted = true;
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('init');
      _ready = res?['ok'] == true;
    } on MissingPluginException catch (_) {
      _ready = false; // host/tests: no native bridge
    } catch (_) {
      _ready = false;
    }
    if (!_ready) _initStarted = false;
    return _ready;
  }

  /// Sends one camera frame; null when busy (dropped), unusable, or the
  /// source is down. Never throws. At most one frame is ever in flight.
  ///
  /// Accepts single-plane NV21 (what the app's camera controller delivers)
  /// as well as 3-plane YUV420 — the `format` travels with the planes so
  /// the native side converts correctly. (A previous revision required 3
  /// planes unconditionally, which silently discarded every NV21 frame and
  /// killed detection entirely on-device.)
  Future<LandmarkerFrame33?> detect(CameraImage image, int rotationDeg) async {
    if (!_ready || _inFlight) return null;
    final planes = image.planes;
    if (planes.isEmpty) return null;
    final nv21 = planes.length == 1;
    return detectRaw(
      y: planes[0].bytes,
      u: nv21 ? Uint8List(0) : planes[1].bytes,
      v: nv21 ? Uint8List(0) : planes[2].bytes,
      width: image.width,
      height: image.height,
      yRowStride: planes[0].bytesPerRow,
      uvRowStride: nv21 ? image.width : planes[1].bytesPerRow,
      uvPixelStride: nv21 ? 2 : (planes[1].bytesPerPixel ?? 1),
      rotationDeg: rotationDeg,
      format: nv21 ? 'nv21' : 'yuv420',
    );
  }

  /// Same contract over raw planes (testable without a camera frame).
  Future<LandmarkerFrame33?> detectRaw({
    required Uint8List y,
    required Uint8List u,
    required Uint8List v,
    required int width,
    required int height,
    required int yRowStride,
    required int uvRowStride,
    required int uvPixelStride,
    required int rotationDeg,
    String format = 'yuv420',
  }) async {
    if (!_ready || _inFlight) return null;
    _inFlight = true;
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'detect',
        {
          'y': y,
          'u': u,
          'v': v,
          'format': format,
          'width': width,
          'height': height,
          'yRowStride': yRowStride,
          'uvRowStride': uvRowStride,
          'uvPixelStride': uvPixelStride,
          'rotation': rotationDeg,
          'timestampMs': DateTime.now().millisecondsSinceEpoch,
        },
      );
      if (res == null || res['ok'] != true) return null;
      if (res['dropped'] == true || res['found'] != true) return null;
      return _parse(res);
    } on MissingPluginException catch (_) {
      _ready = false;
      return null;
    } catch (_) {
      return null;
    } finally {
      _inFlight = false;
    }
  }

  LandmarkerFrame33? _parse(Map<String, dynamic> res) {
    try {
      final rawImage = res['image'] as List;
      if (rawImage.length < 33) return null;
      final xy = <List<double>>[];
      final z = <double>[];
      final vis = <double>[];
      for (var i = 0; i < 33; i++) {
        final l = (rawImage[i] as List)
            .map((v) => (v as num).toDouble())
            .toList();
        if (l.length < 5) return null;
        if (l.any((v) => v.isNaN)) return null;
        xy.add([l[0], l[1]]);
        z.add(l[2]);
        vis.add((l[3] * l[4]).clamp(0.0, 1.0));
      }
      List<List<double>>? world;
      final rawWorld = res['world'];
      if (rawWorld is List && rawWorld.length >= 33) {
        final parsed = <List<double>>[];
        var valid = true;
        for (var i = 0; i < 33 && valid; i++) {
          final l = (rawWorld[i] as List)
              .map((v) => (v as num).toDouble())
              .toList();
          if (l.length < 3 || l.any((v) => v.isNaN)) {
            valid = false;
          } else {
            parsed.add([l[0], l[1], l[2]]);
          }
        }
        if (valid) world = parsed;
      }
      final thumbBytes = res['thumb'] as Uint8List?;
      if (thumbBytes == null || thumbBytes.length != thumbSize * thumbSize * 3) {
        return null;
      }
      double d(Object? v) => (v as num?)?.toDouble() ?? 0.0;
      int i(Object? v) => (v as num?)?.toInt() ?? 0;
      final thumb = MoveNetThumb(
        rgb: thumbBytes,
        srcWidth: i(res['srcW']),
        srcHeight: i(res['srcH']),
        size: i(res['size']) == 0 ? thumbSize : i(res['size']),
        padLeft: d(res['padLeft']),
        padTop: d(res['padTop']),
        scaledW: d(res['scaledW']),
        scaledH: d(res['scaledH']),
      );
      if (thumb.scaledW <= 0 || thumb.scaledH <= 0) return null;
      final frameW = d(res['frameW']);
      final frameH = d(res['frameH']);
      if (frameW <= 0 || frameH <= 0) return null;
      return LandmarkerFrame33(
        imageXY: xy,
        z: z,
        vis: vis,
        world: world,
        thumb: thumb,
        inferenceMs: d(res['inferenceMs']),
        frameW: frameW,
        frameH: frameH,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> close() async {
    _ready = false;
    try {
      await _channel.invokeMethod<void>('close');
    } catch (_) {}
  }
}
