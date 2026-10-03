/// MoveNet Thunder second opinion (Batch 5: port of Open Vission
/// `MoveNetVerifier`).
///
/// The verifier runs on letterboxed RGB thumbnails produced natively
/// (Kotlin owns the YUV→RGB + pad math, which is memcpy-grade there and
/// slow in Dart). This file maps the 17 COCO keypoints back into the
/// 33-joint frame space for [crossModelAgreement].
///
/// The TFLite interpreter sits behind [MoveNetInterpreter] so unit tests
/// drive a fake and the real engine only ever runs on-device.
library;

import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

import 'trust_gate.dart';

/// Letterboxed RGB thumbnail + the pad math to map model outputs back into
/// original-frame normalised coordinates (port of `_prepare` inverses).
class MoveNetThumb {
  const MoveNetThumb({
    required this.rgb,
    required this.srcWidth,
    required this.srcHeight,
    required this.size,
    required this.padLeft,
    required this.padTop,
    required this.scaledW,
    required this.scaledH,
  });

  /// Raw `size*size*3` RGB bytes (row-major).
  final Uint8List rgb;
  final int srcWidth;
  final int srcHeight;

  /// Padded square edge (256 for Thunder).
  final int size;

  /// Letterbox offsets + scaled content size inside the square.
  final double padLeft;
  final double padTop;
  final double scaledW;
  final double scaledH;

  /// Model-space (0..1 of the padded square) → frame normalised (0..1).
  /// May fall slightly outside [0, 1] near the edges — callers clamp.
  (double, double) toFrame(double mx, double my) => (
        (mx * size - padLeft) / scaledW,
        (my * size - padTop) / scaledH,
      );
}

/// Minimal interpreter surface the verifier needs (fakeable in tests).
abstract class MoveNetInterpreter {
  /// Model input edge (256 for Thunder, 192 for Lightning).
  int get size;

  /// True when the input tensor wants float32 (else uint8 bytes).
  bool get inputIsFloat;

  /// Runs one inference; returns 51 values (y, x, score × 17, row-major).
  List<double> run(Uint8List rgb, int size);

  void close();
}

/// Production interpreter over tflite_flutter.
class TfliteMoveNetInterpreter implements MoveNetInterpreter {
  TfliteMoveNetInterpreter._(this._interp, this._size, this._isFloat);

  static Future<TfliteMoveNetInterpreter> load(String asset) async {
    final interp = await tfl.Interpreter.fromAsset(asset);
    interp.allocateTensors();
    final input = interp.getInputTensor(0);
    final shape = input.shape;
    final size = shape.length >= 3 ? shape[shape.length - 2] : 256;
    final isFloat = input.type == tfl.TensorType.float32;
    return TfliteMoveNetInterpreter._(interp, size, isFloat);
  }

  final tfl.Interpreter _interp;
  final int _size;
  final bool _isFloat;

  @override
  int get size => _size;

  @override
  bool get inputIsFloat => _isFloat;

  @override
  List<double> run(Uint8List rgb, int size) {
    final Object input;
    if (_isFloat) {
      final floats = Float32List(rgb.length);
      for (var i = 0; i < rgb.length; i++) {
        floats[i] = rgb[i] / 255.0;
      }
      input = floats;
    } else {
      input = rgb;
    }
    final output = List<double>.filled(17 * 3, 0.0);
    _interp.run(input, output);
    return output;
  }

  @override
  void close() => _interp.close();
}

/// One verifier opinion in 33-joint frame space (NaN where unmapped —
/// never interpolated, so downstream sees exactly which joints MoveNet
/// had no opinion on).
class MoveNetResult {
  const MoveNetResult({
    required this.imageXY,
    required this.vis,
    required this.inferenceMs,
  });

  /// 33 (x, y) frame-normalised pairs (NaN pairs where unmapped).
  final List<List<double>> imageXY;

  /// 33 visibilities (0 where unmapped).
  final List<double> vis;
  final double inferenceMs;

  bool get hasOpinion => vis.any((v) => v > 0.15);
}

/// Independent TF-Lite second opinion on the joints that drive counting.
class MoveNetVerifier {
  MoveNetVerifier({MoveNetInterpreter? interpreter}) : _interp = interpreter;

  static const String thunderAsset =
      'assets/models/movenet_thunder_fp16.tflite';

  MoveNetInterpreter? _interp;
  bool _closed = false;

  bool get ready => _interp != null && !_closed;

  /// Loads the bundled Thunder model (no-op when a fake was injected).
  /// Never throws — a missing/unusable model means single-source mode.
  Future<void> load() async {
    if (_interp != null || _closed) return;
    try {
      _interp = await TfliteMoveNetInterpreter.load(thunderAsset);
    } catch (_) {
      _interp = null;
    }
  }

  /// Runs one verification pass. Null when the verifier is unavailable;
  /// never throws (a failed pass is single-source, not a crash).
  Future<MoveNetResult?> verify(MoveNetThumb thumb) async {
    final interp = _interp;
    if (interp == null || _closed) return null;
    try {
      final sw = Stopwatch()..start();
      final kp = interp.run(thumb.rgb, thumb.size);
      sw.stop();
      final xy = List<List<double>>.generate(
          33, (_) => [double.nan, double.nan]);
      final vis = List<double>.filled(33, 0.0);
      for (var mv = 0; mv < 17; mv++) {
        final blaze = movenetToBlazepose[mv];
        if (blaze == null) continue;
        final y = kp[mv * 3], x = kp[mv * 3 + 1], s = kp[mv * 3 + 2];
        if (y.isNaN || x.isNaN || s.isNaN) continue;
        final (fx, fy) = thumb.toFrame(x, y);
        xy[blaze] = [fx, fy];
        vis[blaze] = s.clamp(0.0, 1.0);
      }
      return MoveNetResult(
        imageXY: xy,
        vis: vis,
        inferenceMs: sw.elapsedMicroseconds / 1000.0,
      );
    } catch (_) {
      return null;
    }
  }

  void close() {
    _closed = true;
    _interp?.close();
    _interp = null;
  }
}
