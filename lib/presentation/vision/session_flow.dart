/// Pre-session auto-calibration — pure ROM capture + verdict (WS2 2.10).
///
/// The session screen feeds the primary joint angle from locked frames into
/// [RomCapture] during a short calibration phase, then derives the spoken
/// verdict from the learned range via [judgeCalibrationDepth] and
/// [calibrationCompleteLine].
///
/// Pure Dart: no ML Kit, no widgets. Unit-tested in
/// test/unit/calibration_rom_test.dart.
library;

/// Range of motion learned during calibration, in degrees.
class RomCapture {
  double? _minDeg;
  double? _maxDeg;

  /// Smallest angle seen, or null before the first sample.
  double? get minDeg => _minDeg;

  /// Largest angle seen, or null before the first sample.
  double? get maxDeg => _maxDeg;

  /// Learned span (`max - min`); null before the first sample, `0.0` for a
  /// single sample.
  double? get spanDeg =>
      _minDeg == null || _maxDeg == null ? null : _maxDeg! - _minDeg!;

  /// Learns one locked-frame angle sample.
  void add(num angleDeg) {
    final angle = angleDeg.toDouble();
    _minDeg = _minDeg == null ? angle : (_minDeg! < angle ? _minDeg : angle);
    _maxDeg = _maxDeg == null ? angle : (_maxDeg! > angle ? _maxDeg : angle);
  }

  /// Forgets the learned range so a new phase can start.
  void reset() {
    _minDeg = null;
    _maxDeg = null;
  }
}

/// Calibration verdict derived from the learned ROM span.
enum CalibrationDepth {
  /// No usable samples — the camera never saw a locked angle.
  unknown,

  /// The user barely moved — standing still or pulsing.
  shallow,

  /// A real rep cycle cleared the good-span bar.
  good,
}

/// Minimum learned ROM span (degrees) that counts as a real rep cycle: far
/// above standing-still noise, comfortably below a typical squat cycle
/// (~84°), so cheap depth pulses still fail.
const double calibrationGoodSpanDeg = 60.0;

/// Maps a learned ROM span to its verdict. Null/NaN spans (no samples) are
/// [CalibrationDepth.unknown].
CalibrationDepth judgeCalibrationDepth(double? spanDeg) {
  if (spanDeg == null || spanDeg.isNaN) return CalibrationDepth.unknown;
  return spanDeg >= calibrationGoodSpanDeg
      ? CalibrationDepth.good
      : CalibrationDepth.shallow;
}

/// Spoken line when the calibration phase ends. Every verdict announces
/// round one — calibration observes but never blocks the workout.
String calibrationCompleteLine(CalibrationDepth depth) => switch (depth) {
      CalibrationDepth.good =>
        'Calibration done — your range looks good. Round one, begin!',
      CalibrationDepth.shallow =>
        'Calibration done — try to use your full range. Round one, begin!',
      CalibrationDepth.unknown =>
        'Calibration skipped — no range measured. Round one, begin!',
    };
