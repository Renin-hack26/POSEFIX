/// Trust scoring — the 85% contract (Batch 5: port of Open Vission
/// `trust.py`).
///
/// Every *decision* (increment a rep, raise a form alert) must carry
/// `trust >= 0.85`. The number is a genuine, auditable blend of four
/// independent signals rather than a hard-coded green tick:
///
///   0.35  landmark visibility          — can the models see the joints?
///   0.30  cross-model agreement        — do two independent nets concur?
///   0.20  temporal consistency         — is the signal stable?
///   0.15  geometric plausibility       — does the pose obey body limits?
///
/// Two tiers: a frame with trust >= 0.85 may *inform* a decision; a
/// completed rep is *committed* only when its rep-level trust (30th
/// percentile of the rep's frames) clears 0.85. Below threshold the
/// decision is HELD (not silently guessed) and the reason is surfaced.
///
/// Pure Dart — no widgets, no channels. Unit-tested in
/// test/unit/trust_gate_test.dart.
library;

import 'dart:math' as math;

/// Frame trust threshold: below this a frame may not inform a decision.
const double trustThreshold = 0.85;

const double wVisibility = 0.35;
const double wAgreement = 0.30;
const double wTemporal = 0.20;
const double wGeometry = 0.15;

/// Why a decision was not committed. Surfaced verbatim in the UI.
enum HoldReason {
  none(''),
  noPose('no person detected'),
  lowVisibility('key joints not clearly visible'),
  modelDisagreement('the two models disagree'),
  unstable('signal unstable (motion blur or shake)'),
  implausibleGeometry('pose outside plausible body limits'),
  outOfFrame('subject partially outside the frame'),
  tooSmall('subject too small in frame'),
  multiplePeople('more than one person in frame'),
  lowLight('lighting too low'),
  blur('image too blurry'),
  wrongOrientation('body orientation not valid for this exercise'),
  incomplete('effort abandoned before reaching depth'),

  /// Identity changed under us — the pose may be flawless, but it is not
  /// necessarily *your* pose, so nothing about it may be trusted.
  subjectLost('the tracked person left or was replaced');

  const HoldReason(this.label);

  final String label;

  bool get ok => this == HoldReason.none;
}

/// Core joints (shoulders/hips/knees/ankles) dominate the visibility term;
/// facial landmarks dragging the mean down would be misleading.
const List<int> coreLandmarks = [11, 12, 23, 24, 25, 26, 27, 28];

/// Arm joints refine the visibility term.
const List<int> armLandmarks = [11, 12, 13, 14, 15, 16];

/// MoveNet COCO index → BlazePose index (port of `MOVENET_TO_BLAZEPOSE`).
const Map<int, int> movenetToBlazepose = {
  0: 0, // nose
  1: 2, // left eye
  2: 5, // right eye
  3: 7, // left ear
  4: 8, // right ear
  5: 11, // left shoulder
  6: 12, // right shoulder
  7: 13, // left elbow
  8: 14, // right elbow
  9: 15, // left wrist
  10: 16, // right wrist
  11: 23, // left hip
  12: 24, // right hip
  13: 25, // left knee
  14: 26, // right knee
  15: 27, // left ankle
  16: 28, // right ankle
};

/// Joints the MoveNet opinion is trusted on (the agreement term).
const List<int> verifierJoints = [11, 12, 23, 24, 25, 26, 27, 28, 13, 14, 15, 16];

/// Auditable components of one trust computation.
class TrustBreakdown {
  TrustBreakdown({
    this.visibility = 0.0,
    this.agreement = 0.0,
    this.temporal = 0.0,
    this.geometry = 0.0,
    this.agreementAvailable = false,
    this.temporalKnown = true,
    List<HoldReason>? blocking,
  }) : blocking = blocking ?? [];

  final double visibility;
  final double agreement;
  final double temporal;
  final double geometry;
  final bool agreementAvailable;

  /// False while the temporal history is still cold (< 4 samples): the
  /// signal is *unknown*, not mediocre — its weight redistributes instead
  /// of dragging good frames under the bar at session start.
  final bool temporalKnown;

  /// Hard gates — any of these forces the hold regardless of score.
  final List<HoldReason> blocking;

  /// Weighted score in [0, 1]. Unavailable signals redistribute
  /// proportionally over the remaining ones rather than scoring as full
  /// agreement — otherwise single-source runs would silently look more
  /// trustworthy than dual, and cold starts would freeze on a neutral
  /// temporal placeholder.
  double get score {
    var wSum =
        wVisibility + wAgreement + wTemporal + wGeometry;
    var raw = wVisibility * visibility +
        wAgreement * agreement +
        wTemporal * temporal +
        wGeometry * geometry;
    if (!agreementAvailable) {
      wSum -= wAgreement;
      raw -= wAgreement * agreement;
    }
    if (!temporalKnown) {
      wSum -= wTemporal;
      raw -= wTemporal * temporal;
    }
    if (wSum <= 0) return 0.0;
    return (raw / wSum).clamp(0.0, 1.0);
  }

  /// A hard gate does not erase the score (it stays visible for
  /// diagnostics) but the decision is held.
  bool get held => blocking.isNotEmpty || score < trustThreshold;

  HoldReason get reason {
    if (blocking.isNotEmpty) return blocking.first;
    if (score >= trustThreshold) return HoldReason.none;
    if (visibility < 0.6) return HoldReason.lowVisibility;
    if (agreementAvailable && agreement < 0.6) {
      return HoldReason.modelDisagreement;
    }
    // Unknown temporal history reads as unstable only when it was actually
    // measured weak — a cold start must not wear the blame for bad geometry.
    if (temporalKnown && temporal < 0.6) return HoldReason.unstable;
    return HoldReason.implausibleGeometry;
  }
}

/// Confidence in the joints that actually matter for the decision.
///
/// By default the core + arm blend from the reference (faces must not sink
/// a squat). Pass `relevant` (BlazePose indices) to score only the joints
/// an exercise measures — partial visibility elsewhere then stops vetoing
/// reps it cannot judge.
double visibilityScore(List<double> vis, {List<int>? relevant}) {
  if (vis.length != 33) return 0.0;
  double mean(Iterable<int> idx) =>
      idx.map((i) => vis[i]).reduce((a, b) => a + b) / idx.length;
  if (relevant != null) {
    final use = relevant.where((i) => i >= 0 && i < vis.length).toList();
    if (use.isEmpty) return 0.0;
    return mean(use).clamp(0.0, 1.0);
  }
  final core = mean(coreLandmarks);
  final arm = mean(armLandmarks);
  return (0.75 * core + 0.25 * arm).clamp(0.0, 1.0);
}

/// Stability of the measured metric over the recent window.
///
/// A real rep has a smooth sweep; jitter from blur/shake shows up as
/// high second-difference energy, which is exactly what is penalised.
/// Deliberately *not* penalising large motion, otherwise fast (legitimate)
/// reps would be rejected. Under 4 samples: neutral 0.5.
double temporalScore(List<double> series, {int window = 12}) {
  final a = series.length > window
      ? series.sublist(series.length - window)
      : List<double>.of(series);
  if (a.length < 4) return 0.5;
  final d1 = [for (var i = 1; i < a.length; i++) a[i] - a[i - 1]];
  final d2 = [for (var i = 1; i < d1.length; i++) d1[i] - d1[i - 1]];
  if (d2.isEmpty) return 0.5;
  final abs = d2.map((v) => v.abs()).toList()..sort();
  final median = abs.length.isOdd
      ? abs[abs.length ~/ 2]
      : (abs[abs.length ~/ 2 - 1] + abs[abs.length ~/ 2]) / 2;
  final jitter = (median + 1e-6) / 15.0;
  return (1.0 / (1.0 + jitter * jitter)).clamp(0.0, 1.0);
}

double _angleAt(
    double ax, double ay, double bx, double by, double cx, double cy) {
  final ux = ax - bx, uy = ay - by;
  final vx = cx - bx, vy = cy - by;
  final n = (ux * ux + uy * uy) * (vx * vx + vy * vy);
  if (n < 1e-12) return double.nan;
  final cos = ((ux * vx + uy * vy) / math.sqrt(n)).clamp(-1.0, 1.0);
  return math.acos(cos) * 180.0 / math.pi;
}

/// Is the pose anatomically possible? Soft penalties (never hard vetoes
/// here — hard gates live in [TrustBreakdown.blocking]):
/// coordinates finite + roughly in-frame, bone-length consistency in
/// world space, joint angles finite and in (1°, 179.5°).
///
/// [imageXY]: 33 (x, y) image-normalised pairs. [worldXYZ]: 33 (x, y, z)
/// world triples, or null when the source has no world space.
double geometryScore(List<List<double>> imageXY, List<List<double>>? worldXYZ) {
  if (imageXY.length != 33) return 0.0;
  var performed = 0;
  var penaltySum = 0.0;
  void add(double p) {
    performed++;
    penaltySum += p;
  }

  bool finitePair(List<double> p) =>
      p.length >= 2 && !p[0].isNaN && !p[1].isNaN;

  // In-frameness, over measurable joints only — unmeasured joints are
  // skipped, never punished (partial visibility is the visibility term's
  // job, not geometry's).
  var finite = 0;
  var outside = 0;
  for (final p in imageXY) {
    if (!finitePair(p)) continue;
    finite++;
    if (p[0] < -0.35 || p[0] > 1.35 || p[1] < -0.35 || p[1] > 1.35) {
      outside++;
    }
  }
  if (finite == 0) return 0.0;
  add(((outside / finite) * 2.0).clamp(0.0, 1.0));

  bool finiteTriple(List<double> p) =>
      p.length >= 3 && !p.any((v) => v.isNaN);

  if (worldXYZ != null && worldXYZ.length == 33) {
    bool ok(int i) => finiteTriple(worldXYZ[i]);
    const pairs = [
      [23, 25],
      [25, 27],
      [24, 26],
      [26, 28],
      [11, 13],
      [12, 14],
    ];
    final lens = <double>[];
    for (final pr in pairs) {
      if (!ok(pr[0]) || !ok(pr[1])) continue;
      final a = worldXYZ[pr[0]], b = worldXYZ[pr[1]];
      final dx = a[0] - b[0], dy = a[1] - b[1], dz = a[2] - b[2];
      final len = math.sqrt(dx * dx + dy * dy + dz * dz);
      if (len > 1e-4) lens.add(len);
    }
    if (lens.length >= 4) {
      final med = _median(lens);
      final mean =
          lens.reduce((x, y) => x + y) / lens.length;
      final variance = lens
              .map((l) => (l - mean) * (l - mean))
              .reduce((x, y) => x + y) /
          lens.length;
      final spread = math.sqrt(variance) / (med < 1e-6 ? 1e-6 : med);
      add(((spread - 0.9) / 0.9).clamp(0.0, 1.0));
    }
  }

  double at(int o, int v, int i) => _angleAt(
        imageXY[o][0],
        imageXY[o][1],
        imageXY[v][0],
        imageXY[v][1],
        imageXY[i][0],
        imageXY[i][1],
      );
  for (final t in const [
    [23, 25, 27],
    [24, 26, 28],
    [11, 13, 15],
    [12, 14, 16],
  ]) {
    // Unmeasurable triplets are skipped — a missing limb must not read
    // as a degenerate one.
    if (!finitePair(imageXY[t[0]]) ||
        !finitePair(imageXY[t[1]]) ||
        !finitePair(imageXY[t[2]])) {
      continue;
    }
    final a = at(t[0], t[1], t[2]);
    if (a.isNaN || a <= 1.0 || a >= 179.5) add(0.5);
  }

  if (performed == 0) return 0.0;
  return (1.0 - penaltySum / performed).clamp(0.0, 1.0);
}

double _median(List<double> v) {
  final s = List<double>.of(v)..sort();
  return s.length.isOdd
      ? s[s.length ~/ 2]
      : (s[s.length ~/ 2 - 1] + s[s.length ~/ 2]) / 2;
}

/// Fraction of joints above the usable visibility line.
double frameCompleteness(List<double> vis) {
  if (vis.isEmpty) return 0.0;
  return vis.where((v) => v >= 0.5).length / vis.length;
}

/// How much the two models agree, overall + per joint.
///
/// A joint scores 1.0 when the predictions are within a few percent of
/// the subject's torso size, falling to 0 as they diverge. Joints where
/// MoveNet has no opinion (NaN / score < 0.15) or either side is weak
/// (< 0.15) are *excluded* — absence of evidence is not agreement.
/// Empty verdict list ⇒ (0.0, []) — single-source mode upstream.
///
/// [mpXY]/[mvXY]: 33 (x, y) image-normalised pairs (NaN where unknown).
/// [mpVis]/[mvVis]: 33 visibilities.
({double score, List<(int, double)> perJoint}) crossModelAgreement(
  List<List<double>> mpXY,
  List<double> mpVis,
  List<List<double>> mvXY,
  List<double> mvVis,
) {
  const none = (score: 0.0, perJoint: <(int, double)>[]);
  if (mpXY.length != 33 || mvXY.length != 33) return none;
  double dist(int a, int b) {
    final dx = mpXY[a][0] - mpXY[b][0];
    final dy = mpXY[a][1] - mpXY[b][1];
    return math.sqrt(dx * dx + dy * dy);
  }

  final torso = (0.5 * (dist(11, 24) + dist(12, 23))).clamp(1e-4, 1e9);
  final perJoint = <(int, double)>[];
  for (final j in verifierJoints) {
    final m = mvXY[j];
    if (m.length < 2 || m[0].isNaN || m[1].isNaN) continue;
    if (mvVis[j] < 0.15 || mpVis[j] < 0.15) continue;
    final dx = mpXY[j][0] - m[0], dy = mpXY[j][1] - m[1];
    final d = math.sqrt(dx * dx + dy * dy);
    perJoint.add((j, (1.0 - d / torso).clamp(0.0, 1.0)));
  }
  if (perJoint.isEmpty) return none;
  final mean =
      perJoint.map((e) => e.$2).reduce((a, b) => a + b) / perJoint.length;
  return (score: mean, perJoint: perJoint);
}

/// Metric for a paired joint side, combining sides only when both are
/// solid (port of `side_value`).
///
/// Averaging two sides is smooth when both are visible; if one is
/// occluded, averaging would drag the value toward garbage, so the
/// visible side alone is used.
double sideValue({
  required double left,
  required double right,
  required double leftVis,
  required double rightVis,
  bool combine = true,
}) {
  bool finite(double v) => !v.isNaN;
  final lOk = finite(left) && leftVis >= 0.45;
  final rOk = finite(right) && rightVis >= 0.45;
  if (combine && lOk && rOk) return 0.5 * (left + right);
  if (lOk && !rOk) return left;
  if (rOk && !lOk) return right;
  // Neither solid: preferred visible side, else NaN (never a guess).
  if (lOk) return left;
  if (rOk) return right;
  if (finite(left) && leftVis >= rightVis) return left;
  if (finite(right)) return right;
  return double.nan;
}

/// Most-flexed visible side, e.g. which leg is forward in a lunge
/// (port of `min_side`).
double minSide({
  required double left,
  required double right,
  required double leftVis,
  required double rightVis,
}) {
  var l = left, r = right;
  if (leftVis < 0.4) l = double.nan;
  if (rightVis < 0.4) r = double.nan;
  final vals = [l, r].where((v) => !v.isNaN).toList();
  if (vals.isEmpty) return double.nan;
  return vals.reduce((a, b) => a < b ? a : b);
}

/// Rolls per-frame trust into a single rep-level verdict.
class TrustAccumulator {
  TrustAccumulator({this.minFrames = 4, this.threshold = trustThreshold});

  final int minFrames;
  final double threshold;
  final List<TrustBreakdown> _samples = [];

  void reset() => _samples.clear();

  int get n => _samples.length;

  void push(TrustBreakdown b) => _samples.add(b);

  double mean() {
    if (_samples.isEmpty) return 0.0;
    return _samples.map((s) => s.score).reduce((a, b) => a + b) /
        _samples.length;
  }

  /// (commit?, trust, reason) for everything pushed since reset().
  ///
  /// A rep is only as trustworthy as its weakest informative frames: the
  /// 30th percentile (linear interpolation, like the reference), not the
  /// mean — one bad instant matters, but a single dropped frame does not
  /// veto the whole rep. Any hard gate (other than transient low
  /// visibility) during the rep blocks it.
  (bool, double, HoldReason) verdict() {
    if (_samples.length < minFrames) {
      return (false, 0.0, HoldReason.unstable);
    }
    final scores = _samples.map((s) => s.score).toList()..sort();
    final pos = 0.3 * (scores.length - 1);
    final lo = pos.floor().clamp(0, scores.length - 1);
    final hi = pos.ceil().clamp(0, scores.length - 1);
    final trust = scores[lo] + (scores[hi] - scores[lo]) * (pos - lo);
    for (final s in _samples) {
      if (s.blocking.isNotEmpty &&
          s.blocking.first != HoldReason.lowVisibility) {
        return (false, trust, s.blocking.first);
      }
    }
    if (trust < threshold) {
      var worst = _samples.first;
      for (final s in _samples) {
        if (s.score < worst.score) worst = s;
      }
      return (false, trust, worst.reason);
    }
    return (true, trust, HoldReason.none);
  }
}
