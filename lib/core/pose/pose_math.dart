/// FixPose pose math — pure-Dart geometry for the vision pipeline.
///
/// Kept dependency-free (no Flutter/ML Kit imports) so every function is
/// unit-testable with synthetic data. Operates on normalized image coords
/// (0..1); angle math itself is scale-invariant so pixel coords work too.
library;

import 'dart:math' as math;

/// Normalized 2D point shared by the pose pipeline.
typedef LmPoint = ({double x, double y});

/// Interior angle ABC in degrees, B = vertex. Returns 0 when degenerate
/// (coincident points — caller must gate on landmark visibility first).
double angleBetween(LmPoint a, LmPoint b, LmPoint c) {
  final bax = a.x - b.x;
  final bay = a.y - b.y;
  final bcx = c.x - b.x;
  final bcy = c.y - b.y;
  final dot = bax * bcx + bay * bcy;
  final n1 = math.sqrt(bax * bax + bay * bay);
  final n2 = math.sqrt(bcx * bcx + bcy * bcy);
  if (n1 < 1e-9 || n2 < 1e-9) return 0.0;
  final cos = (dot / (n1 * n2)).clamp(-1.0, 1.0);
  return math.acos(cos) * 180.0 / math.pi;
}

/// Exponential moving average filter — one instance per tracked scalar.
/// Alpha 0.3 (FormRules.emaSmoothingAlpha): responsive yet stable on noisy
/// low-light frames.
class EmaFilter {
  EmaFilter(this.alpha);

  final double alpha;
  double? _value;

  double? get value => _value;

  /// Pushes [x], returns the filtered value.
  double push(double x) {
    final prev = _value;
    _value = prev == null ? x : prev * (1 - alpha) + x * alpha;
    return _value!;
  }

  void reset() => _value = null;
}

/// Axis-aligned bounding box of [points] in normalized coords.
({double minX, double minY, double maxX, double maxY}) boundingBox(
  Iterable<LmPoint> points,
) {
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = double.negativeInfinity;
  var maxY = double.negativeInfinity;
  for (final p in points) {
    if (p.x < minX) minX = p.x;
    if (p.y < minY) minY = p.y;
    if (p.x > maxX) maxX = p.x;
    if (p.y > maxY) maxY = p.y;
  }
  return (minX: minX, minY: minY, maxX: maxX, maxY: maxY);
}

/// Centroid of [points]; used for person-lock continuity tracking.
LmPoint centroid(Iterable<LmPoint> points) {
  var sx = 0.0;
  var sy = 0.0;
  var n = 0;
  for (final p in points) {
    sx += p.x;
    sy += p.y;
    n++;
  }
  if (n == 0) return (x: 0.5, y: 0.5);
  return (x: sx / n, y: sy / n);
}

/// Normalized Euclidean distance between two points.
double normalizedDistance(LmPoint a, LmPoint b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  return math.sqrt(dx * dx + dy * dy);
}
