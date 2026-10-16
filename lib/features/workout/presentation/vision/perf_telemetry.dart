import 'package:flutter/foundation.dart';

/// One aggregated sample of pipeline + UI health (published ~1 Hz while a
/// vision session runs). Feeds the performance charts screen (graphify).
@immutable
class PerfSample {
  const PerfSample({
    required this.tSec,
    required this.fps,
    required this.inferMs,
    required this.uiBuildMs,
    required this.uiRasterMs,
    required this.joints,
    required this.poses,
    required this.throttled,
  });

  /// Seconds since the first sample of this run (monotonic within a run).
  final double tSec;

  /// Rolling pipeline throughput (analyzed frames/s).
  final double fps;

  /// Last ML Kit inference time (ms).
  final double inferMs;

  /// Rolling mean UI-thread frame build time (ms) — Flutter engine timings.
  final double uiBuildMs;

  /// Rolling mean raster-thread frame time (ms).
  final double uiRasterMs;

  /// Confident joints on the last pose (0-33).
  final int joints;

  /// Poses found on the last analyzed frame (0 = nobody).
  final int poses;

  /// Total frames skipped by the analysis rate cap since the run started.
  final int throttled;
}

/// Process-wide ring buffer of [PerfSample]s (session screen writes, perf
/// screen reads). Deliberately dependency-free — never touches the DB.
class PerfTelemetry {
  PerfTelemetry._();

  static final PerfTelemetry instance = PerfTelemetry._();

  /// ~4 minutes at 1 Hz.
  static const int capacity = 240;

  final List<PerfSample> _samples = [];
  List<PerfSample> get samples => List.unmodifiable(_samples);

  /// Bumped on every [add]/[clear] — the perf screen listens to this.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  void add(PerfSample sample) {
    _samples.add(sample);
    if (_samples.length > capacity) {
      _samples.removeRange(0, _samples.length - capacity);
    }
    revision.value++;
  }

  void clear() {
    if (_samples.isEmpty) return;
    _samples.clear();
    revision.value++;
  }
}
