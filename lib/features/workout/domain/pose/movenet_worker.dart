/// Background isolate hosting the MoveNet Thunder interpreter (camera
/// smoothness fix, round 2).
///
/// TFLite's `run` is a *synchronous FFI call*: awaiting it on the UI
/// isolate still freezes rendering for the whole inference (every 250 ms
/// → a visible stutter that read as "the camera is laggy"). The
/// interpreter therefore lives on this worker isolate; the main isolate
/// ships the 256×256 RGB thumb over a SendPort and gets the 51 raw
/// keypoint values back. The UI isolate only ever pays a ~196 KB copy.
///
/// Contract: at most one request in flight (the caller already guards
/// single-in-flight; the worker would serialise anyway). Any failure —
/// model load, inference, dead isolate — surfaces as `null`, which the
/// verifier turns into "no second opinion" (the trust gate already
/// redistributes the agreement weight, so a dead worker degrades to
/// single-source mode instead of breaking counting).
library;

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

/// Moves onto the worker as soon as the interpreter is ready; `null` (or
/// a stalled port) means spawn failed and the caller stays single-source.
class MoveNetWorker {
  MoveNetWorker._(this._isolate, this._requests);

  /// Result of [run]: the 51 raw values + wall-clock inference ms.
  /// Kept as a record so the mapping (COCO → BlazePose, frame coords)
  /// stays on the main isolate next to the thumb's pad math.
  static Future<MoveNetWorker?> spawn(Uint8List modelBuffer) async {
    try {
      final ready = ReceivePort();
      final isolate = await Isolate.spawn(
        _entry,
        (ready.sendPort, modelBuffer),
        debugName: 'fixpose-movenet',
        errorsAreFatal: false,
      );
      // Worker replies with its request inbox once the interpreter exists.
      final dynamic first = await ready.first.timeout(
        const Duration(seconds: 10),
        onTimeout: () => null,
      );
      ready.close();
      if (first is! SendPort) {
        isolate.kill(priority: Isolate.immediate);
        return null;
      }
      return MoveNetWorker._(isolate, first);
    } catch (_) {
      return null;
    }
  }

  final Isolate _isolate;

  /// The worker's request inbox — every [_RunRequest] carries its own
  /// reply port, so no standing receive port is needed on this side.
  final SendPort _requests;
  bool _closed = false;

  bool get closed => _closed;

  /// One pass. Null when closed or a pass is already in flight — callers
  /// treat that exactly like a failed pass (no opinion this tick).
  Future<(List<double>, double)?> run(Uint8List rgb, int size) async {
    if (_closed) return null;
    final reply = ReceivePort();
    try {
      // Plain list payload: [replyPort, rgbBytes, inputSize] — every
      // element is trivially copyable between isolates.
      _requests.send([reply, rgb, size]);
      final dynamic msg = await reply.first.timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
      if (msg is List && msg.length == 2 && msg[0] is List) {
        final kp = (msg[0] as List).cast<num>();
        return (
          [for (final v in kp) v.toDouble()],
          (msg[1] as num).toDouble(),
        );
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      reply.close();
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    try {
      _requests.send(null); // graceful shutdown: close interpreter, exit
    } catch (_) {}
    _isolate.kill(priority: Isolate.beforeNextEvent);
  }
}

/// Worker entry: build the interpreter once, then serve requests until
/// a `null` shutdown message arrives. Never throws across the isolate.
void _entry((SendPort, Uint8List) start) {
  final (readyPort, model) = start;
  tfl.Interpreter? interp;
  var isFloat = false;
  try {
    interp = tfl.Interpreter.fromBuffer(model);
    interp.allocateTensors();
    final input = interp.getInputTensor(0);
    isFloat = input.type == tfl.TensorType.float32;
  } catch (_) {
    readyPort.send(null); // spawn failed upstream — do not linger
    return;
  }

  final requests = ReceivePort();
  readyPort.send(requests.sendPort);

  requests.listen((dynamic msg) {
    if (msg == null) {
      try {
        interp?.close();
      } catch (_) {}
      requests.close();
      return;
    }
    if (msg is! List || msg.length != 3) return;
    final reply = msg[0] as SendPort;
    final rgb = msg[1] as Uint8List;
    try {
      final ip = interp!;
      final sw = Stopwatch()..start();
      final Object input;
      if (isFloat) {
        final floats = Float32List(rgb.length);
        for (var i = 0; i < rgb.length; i++) {
          floats[i] = rgb[i] / 255.0;
        }
        input = floats;
      } else {
        input = rgb;
      }
      final output = List<double>.filled(17 * 3, 0.0);
      ip.run(input, output);
      sw.stop();
      reply.send([
        Float64List.fromList(output),
        sw.elapsedMicroseconds / 1000.0,
      ]);
    } catch (_) {
      try {
        reply.send(null);
      } catch (_) {}
    }
  });
}
