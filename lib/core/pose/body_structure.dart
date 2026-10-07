/// Complete-body pose structure — the canonical skeleton model (round 3).
///
/// One source of truth for every anatomical bone the pipeline knows about:
/// torso, both arms, wrist+palm hand parts, both legs, feet, head/face and
/// the neck links. The overlay painter draws exactly this graph, the trust
/// gate measures geometry with its complete-body lists, and per-frame
/// [BodyStructure] instances compute segment lengths, visibility, joint
/// angles and posture metrics from all 33 BlazePose landmarks.
///
/// Pure Dart (no Flutter/ML Kit imports) so every part is unit-testable
/// with synthetic frames — test/unit/body_structure_test.dart.
library;

import 'dart:math' as math;

import 'exercise_definition.dart';
import 'pose_math.dart' as pm;
/// Anatomical group of a bone — coverage and symmetry are scored per group.
enum BodyGroup {
  head,
  torso,
  armL,
  armR,
  handL,
  handR,
  legL,
  legR,
  footL,
  footR,
}

/// Drawing/structure tier — also the overlay stroke tier.
enum BoneTier {
  /// Structural bones (thick): torso box, upper arms, thighs, shanks.
  major,

  /// Appendage bones (medium): hands and feet.
  appendage,

  /// Face detail (thin white): jaw, eyes, nose spokes.
  face,

  /// Neck links (ear → shoulder).
  neck,
}

/// One anatomical bone: landmark pair [a]–[b] with its group and tier.
class BoneDef {
  const BoneDef(this.id, this.a, this.b, this.group, this.tier);

  /// Stable identifier (`upper_arm_l`, `thigh_r`, …).
  final String id;
  final int a;
  final int b;
  final BodyGroup group;
  final BoneTier tier;
}

/// One bone measured on a specific frame.
class BoneSegment {
  const BoneSegment(
    this.def,
    this.from,
    this.to,
    this.length,
    this.visibility,
  );

  final BoneDef def;
  final pm.LmPoint? from;
  final pm.LmPoint? to;

  /// Screen-space length in the frame's units (0 when unmeasurable).
  final double length;

  /// Lower endpoint visibility — a bone is only as visible as its worse
  /// end.
  final double visibility;

  /// Both endpoints present with usable confidence.
  bool get measurable => from != null && to != null;

  bool get reliable =>
      measurable && visibility >= BodyStructure.minBoneVisibility;
}

/// Posture metrics derived from the complete structure — the numbers a
/// posture judgment is made from (raw metrics, no UI copy here).
class PostureReport {
  const PostureReport({
    required this.torsoLeanDeg,
    required this.coverage,
    required this.torsoCoverage,
    required this.armSymmetry,
    required this.legSymmetry,
  });

  /// Signed torso lean from image-vertical, degrees (+ = leaning right in
  /// upright-frame space). Null when shoulders and hips aren't both solid.
  final double? torsoLeanDeg;

  /// Fraction of all bones measurable with solid confidence (0..1).
  final double coverage;

  /// Fraction of the torso box solid (0..1).
  final double torsoCoverage;

  /// Left/right mean arm-bone length ratio (1.0 = symmetric), null when
  /// either side has no solid bone.
  final double? armSymmetry;

  /// Left/right mean leg-bone length ratio (1.0 = symmetric).
  final double? legSymmetry;

  /// Torso fully measurable and legs judgeable — enough structure to make
  /// a posture call at all.
  bool get coreUsable => torsoCoverage >= 1.0 && legSymmetry != null;
}

class BodyStructure {
  BodyStructure._(this.xy, this.vis, this.segments);

  /// BlazePose joint count.
  static const int jointCount = 33;

  /// Minimum endpoint confidence for a bone/landmark to count as solid.
  static const double minBoneVisibility = 0.5;

  /// Minimum confidence for a landmark to join a derived midpoint
  /// (midpoints average two landmarks — both must be reasonably clean).
  static const double minMidpointVisibility = 0.3;

  /// The complete body — every anatomical bone, in overlay draw order:
  /// body first (major + appendage, exactly as the reference topology
  /// drew them), then face detail, then neck links.
  static const List<BoneDef> bones = [
    // Torso box (major).
    BoneDef('shoulder_line', MpLandmark.leftShoulder, MpLandmark.rightShoulder,
        BodyGroup.torso, BoneTier.major),
    BoneDef('torso_l', MpLandmark.leftShoulder, MpLandmark.leftHip,
        BodyGroup.torso, BoneTier.major),
    BoneDef('torso_r', MpLandmark.rightShoulder, MpLandmark.rightHip,
        BodyGroup.torso, BoneTier.major),
    BoneDef('hip_line', MpLandmark.leftHip, MpLandmark.rightHip,
        BodyGroup.torso, BoneTier.major),
    // Left arm + wrist/palm hand parts.
    BoneDef('upper_arm_l', MpLandmark.leftShoulder, MpLandmark.leftElbow,
        BodyGroup.armL, BoneTier.major),
    BoneDef('forearm_l', MpLandmark.leftElbow, MpLandmark.leftWrist,
        BodyGroup.armL, BoneTier.major),
    BoneDef('palm_edge_l', MpLandmark.leftWrist, MpLandmark.leftPinky,
        BodyGroup.handL, BoneTier.appendage),
    BoneDef('knuckle_l', MpLandmark.leftPinky, MpLandmark.leftIndex,
        BodyGroup.handL, BoneTier.appendage),
    BoneDef('thumb_line_l', MpLandmark.leftIndex, MpLandmark.leftThumb,
        BodyGroup.handL, BoneTier.appendage),
    BoneDef('thumb_side_l', MpLandmark.leftWrist, MpLandmark.leftThumb,
        BodyGroup.handL, BoneTier.appendage),
    // Right arm + wrist/palm hand parts.
    BoneDef('upper_arm_r', MpLandmark.rightShoulder, MpLandmark.rightElbow,
        BodyGroup.armR, BoneTier.major),
    BoneDef('forearm_r', MpLandmark.rightElbow, MpLandmark.rightWrist,
        BodyGroup.armR, BoneTier.major),
    BoneDef('palm_edge_r', MpLandmark.rightWrist, MpLandmark.rightPinky,
        BodyGroup.handR, BoneTier.appendage),
    BoneDef('knuckle_r', MpLandmark.rightPinky, MpLandmark.rightIndex,
        BodyGroup.handR, BoneTier.appendage),
    BoneDef('thumb_line_r', MpLandmark.rightIndex, MpLandmark.rightThumb,
        BodyGroup.handR, BoneTier.appendage),
    BoneDef('thumb_side_r', MpLandmark.rightWrist, MpLandmark.rightThumb,
        BodyGroup.handR, BoneTier.appendage),
    // Left leg + foot.
    BoneDef('thigh_l', MpLandmark.leftHip, MpLandmark.leftKnee,
        BodyGroup.legL, BoneTier.major),
    BoneDef('shank_l', MpLandmark.leftKnee, MpLandmark.leftAnkle,
        BodyGroup.legL, BoneTier.major),
    BoneDef('heel_l', MpLandmark.leftAnkle, MpLandmark.leftHeel,
        BodyGroup.footL, BoneTier.appendage),
    BoneDef('toe_l', MpLandmark.leftAnkle, MpLandmark.leftFootIndex,
        BodyGroup.footL, BoneTier.appendage),
    BoneDef('sole_l', MpLandmark.leftHeel, MpLandmark.leftFootIndex,
        BodyGroup.footL, BoneTier.appendage),
    // Right leg + foot.
    BoneDef('thigh_r', MpLandmark.rightHip, MpLandmark.rightKnee,
        BodyGroup.legR, BoneTier.major),
    BoneDef('shank_r', MpLandmark.rightKnee, MpLandmark.rightAnkle,
        BodyGroup.legR, BoneTier.major),
    BoneDef('heel_r', MpLandmark.rightAnkle, MpLandmark.rightHeel,
        BodyGroup.footR, BoneTier.appendage),
    BoneDef('toe_r', MpLandmark.rightAnkle, MpLandmark.rightFootIndex,
        BodyGroup.footR, BoneTier.appendage),
    BoneDef('sole_r', MpLandmark.rightHeel, MpLandmark.rightFootIndex,
        BodyGroup.footR, BoneTier.appendage),
    // Face detail (head group).
    BoneDef('jaw_l', MpLandmark.leftEar, MpLandmark.mouthLeft,
        BodyGroup.head, BoneTier.face),
    BoneDef('mouth_line', MpLandmark.mouthLeft, MpLandmark.mouthRight,
        BodyGroup.head, BoneTier.face),
    BoneDef('jaw_r', MpLandmark.mouthRight, MpLandmark.rightEar,
        BodyGroup.head, BoneTier.face),
    BoneDef('nose_mouth_l', MpLandmark.nose, MpLandmark.mouthLeft,
        BodyGroup.head, BoneTier.face),
    BoneDef('nose_mouth_r', MpLandmark.nose, MpLandmark.mouthRight,
        BodyGroup.head, BoneTier.face),
    BoneDef('eye_l_a', MpLandmark.leftEyeInner, MpLandmark.leftEye,
        BodyGroup.head, BoneTier.face),
    BoneDef('eye_l_b', MpLandmark.leftEye, MpLandmark.leftEyeOuter,
        BodyGroup.head, BoneTier.face),
    BoneDef('eye_r_a', MpLandmark.rightEyeInner, MpLandmark.rightEye,
        BodyGroup.head, BoneTier.face),
    BoneDef('eye_r_b', MpLandmark.rightEye, MpLandmark.rightEyeOuter,
        BodyGroup.head, BoneTier.face),
    BoneDef('nose_eye_l', MpLandmark.nose, MpLandmark.leftEye,
        BodyGroup.head, BoneTier.face),
    BoneDef('nose_eye_r', MpLandmark.nose, MpLandmark.rightEye,
        BodyGroup.head, BoneTier.face),
    BoneDef('ear_eye_l', MpLandmark.leftEyeOuter, MpLandmark.leftEar,
        BodyGroup.head, BoneTier.face),
    BoneDef('ear_eye_r', MpLandmark.rightEyeOuter, MpLandmark.rightEar,
        BodyGroup.head, BoneTier.face),
    // Neck links (ear → shoulder).
    BoneDef('neck_l', MpLandmark.leftEar, MpLandmark.leftShoulder,
        BodyGroup.head, BoneTier.neck),
    BoneDef('neck_r', MpLandmark.rightEar, MpLandmark.rightShoulder,
        BodyGroup.head, BoneTier.neck),
  ];

  static final Map<String, int> _indexById = {
    for (var i = 0; i < bones.length; i++) bones[i].id: i,
  };

  /// Bone-length consistency pairs for [geometryScore] — complete-body
  /// long bones (the reference six plus forearms and torso sides; tiny
  /// hand/foot bones are too noisy in world space to judge consistency).
  static const List<List<int>> worldBonePairs = [
    [23, 25], [25, 27], [24, 26], [26, 28], // thighs + shanks
    [11, 13], [12, 14], // upper arms
    [13, 15], [14, 16], // forearms
    [11, 23], [12, 24], // torso sides
  ];

  /// Joint-angle sanity triples for [geometryScore] — complete-body
  /// major joints (the reference knees/elbows plus shoulders, palms and
  /// feet). Vertices that legitimately read ~0°/~180° when standing
  /// straight (hips, shoulders-line) are deliberately excluded.
  static const List<List<int>> jointTriples = [
    [23, 25, 27], [24, 26, 28], // knees
    [11, 13, 15], [12, 14, 16], // elbows
    [23, 11, 13], [24, 12, 14], // shoulders (hip–shoulder–elbow)
    [17, 15, 19], [18, 16, 20], // palms (pinky–wrist–index)
    [29, 27, 31], [30, 28, 32], // feet (heel–ankle–toe)
  ];

  /// Landmark coordinates in upright-frame space (null = not measurable).
  final List<pm.LmPoint?> xy;

  /// Per-landmark confidence, clamped 0..1.
  final List<double> vis;

  /// One segment per bone in [bones] order.
  final List<BoneSegment> segments;

  /// Builds the complete structure for one frame. [xy] and [vis] must
  /// carry all 33 joints.
  factory BodyStructure.fromFrame({
    required List<pm.LmPoint?> xy,
    required List<double> vis,
  }) {
    if (xy.length != jointCount || vis.length != jointCount) {
      throw ArgumentError(
          'BodyStructure needs $jointCount joints '
          '(got xy=${xy.length}, vis=${vis.length})');
    }
    final segments = <BoneSegment>[
      for (final def in bones)
        BoneSegment(
          def,
          xy[def.a],
          xy[def.b],
          _distance(xy[def.a], xy[def.b]),
          _min(vis[def.a], vis[def.b]),
        ),
    ];
    return BodyStructure._(List.of(xy), List.of(vis), segments);
  }

  static double _distance(pm.LmPoint? a, pm.LmPoint? b) {
    if (a == null || b == null) return 0.0;
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    if (!dx.isFinite || !dy.isFinite) return 0.0;
    return math.sqrt(dx * dx + dy * dy);
  }

  static double _min(double a, double b) => a.isNaN || b.isNaN ? 0.0 : math.min(a, b);

  /// Segment for a bone id, or null when unknown.
  BoneSegment? segmentOrNull(String id) {
    final i = _indexById[id];
    return i == null ? null : segments[i];
  }

  /// Segment for a bone id (throws on unknown id — ids are compile-time
  /// constants, a miss is a programming error).
  BoneSegment segment(String id) => segments[_indexById[id]!];

  /// All bones of one group.
  List<BoneSegment> bonesOf(BodyGroup group) =>
      [for (final s in segments) if (s.def.group == group) s];

  /// Fraction of [group] bones measurable with solid confidence.
  double coverage(BodyGroup group) {
    var have = 0;
    var n = 0;
    for (final s in segments) {
      if (s.def.group != group) continue;
      n++;
      if (s.reliable) have++;
    }
    return n == 0 ? 0.0 : have / n;
  }

  /// Fraction of all bones solid.
  double get overallCoverage {
    var have = 0;
    for (final s in segments) {
      if (s.reliable) have++;
    }
    return have / segments.length;
  }

  /// Landmark [i] when present and solid, else null.
  pm.LmPoint? point(int i) {
    if (i < 0 || i >= jointCount) return null;
    final p = xy[i];
    if (p == null || vis[i] < minBoneVisibility) return null;
    if (!p.x.isFinite || !p.y.isFinite) return null;
    return p;
  }

  /// Midpoint of two landmarks — null when either end is unmeasurable
  /// (derived bones like the spine read from these).
  pm.LmPoint? midpoint(int a, int b) {
    final pa = point(a);
    final pb = point(b);
    if (pa == null || pb == null) return null;
    return (x: (pa.x + pb.x) / 2.0, y: (pa.y + pb.y) / 2.0);
  }

  /// Interior angle at [b] in degrees — identical math to
  /// [pm.angleBetween], null when any vertex is unmeasurable.
  double? angleAt(int a, int b, int c) {
    final pa = xy[a];
    final pb = xy[b];
    final pc = xy[c];
    if (pa == null || pb == null || pc == null) return null;
    if (!_finite(pa) || !_finite(pb) || !_finite(pc)) return null;
    return pm.angleBetween(pa, pb, pc);
  }

  static bool _finite(pm.LmPoint p) => p.x.isFinite && p.y.isFinite;

  /// Angle at [b], additionally gated on all three vertex confidences.
  double? jointAngle(int a, int b, int c, {double minVis = minBoneVisibility}) {
    if (a < 0 || b < 0 || c < 0 || a >= jointCount || b >= jointCount || c >= jointCount) {
      return null;
    }
    if (vis[a] < minVis || vis[b] < minVis || vis[c] < minVis) return null;
    return angleAt(a, b, c);
  }

  /// Signed torso lean (spine from mid-shoulder to mid-hip) from the
  /// image-vertical, degrees. Positive = leaning right in upright-frame
  /// space; null when the torso box isn't measurable.
  double? get torsoLeanDeg {
    final ms = midpoint(MpLandmark.leftShoulder, MpLandmark.rightShoulder);
    final mh = midpoint(MpLandmark.leftHip, MpLandmark.rightHip);
    if (ms == null || mh == null) return null;
    final dx = mh.x - ms.x;
    final dy = mh.y - ms.y;
    if (dx * dx + dy * dy < 1e-12) return null;
    return math.atan2(dx, dy) * 180.0 / math.pi;
  }

  /// Hand axis (wrist → index base) from the image-vertical, degrees —
  /// the palm's orientation, useful for grip/press posture.
  double? handAxisDeg({required bool left}) {
    final w = point(left ? MpLandmark.leftWrist : MpLandmark.rightWrist);
    final i = point(left ? MpLandmark.leftIndex : MpLandmark.rightIndex);
    if (w == null || i == null) return null;
    final dx = i.x - w.x;
    final dy = i.y - w.y;
    if (dx * dx + dy * dy < 1e-12) return null;
    return math.atan2(dx, dy) * 180.0 / math.pi;
  }

  /// Mean solid length over [ids] (null when nothing solid).
  double? _meanLen(List<String> ids) {
    var sum = 0.0;
    var n = 0;
    for (final id in ids) {
      final i = _indexById[id];
      if (i == null) continue;
      final s = segments[i];
      if (!s.reliable) continue;
      sum += s.length;
      n++;
    }
    return n == 0 ? null : sum / n;
  }

  /// Left/right mean bone-length ratio (1.0 = symmetric).
  double? lengthRatio(List<String> leftIds, List<String> rightIds) {
    final l = _meanLen(leftIds);
    final r = _meanLen(rightIds);
    if (l == null || r == null || r < 1e-9) return null;
    return l / r;
  }

  static const List<String> _armBonesL = ['upper_arm_l', 'forearm_l'];
  static const List<String> _armBonesR = ['upper_arm_r', 'forearm_r'];
  static const List<String> _legBonesL = ['thigh_l', 'shank_l'];
  static const List<String> _legBonesR = ['thigh_r', 'shank_r'];

  /// Posture determination inputs from the complete structure.
  PostureReport posture() => PostureReport(
        torsoLeanDeg: torsoLeanDeg,
        coverage: overallCoverage,
        torsoCoverage: coverage(BodyGroup.torso),
        armSymmetry: lengthRatio(_armBonesL, _armBonesR),
        legSymmetry: lengthRatio(_legBonesL, _legBonesR),
      );
}
