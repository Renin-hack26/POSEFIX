/// FixPose Brain Engine — FSM runner for exercise analysis.
///
/// Ports the YAML-based FSM logic from Model samples to Dart.
/// Runs on-device, zero dependencies beyond the exercise definitions.
///
/// Features:
/// - Safe condition evaluation (hand-written parser, no eval; supports
///   string literals for `state == '...'` rules, and/or/not, comparisons,
///   arithmetic, abs/min/max).
/// - State machine with priority ordering + consecutive-frame stabilization
///   (kills single-frame jitter on bad-camera input).
/// - Rep counting with visit-memory: the trigger state counts only when the
///   required ROM state was *visited* since the last rep (stricter and more
///   correct than the reference Python engine, which only looked at the
///   immediate predecessor — a key-name mismatch meant its
///   `required_prior_state` never fired).
/// - Form score (angle accuracy, tempo, warning/error feedback only —
///   info lines like "Good form" never penalize).
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'exercise_definition.dart';
import 'pose_math.dart' show LmPoint;
import 'trust_gate.dart';

/// Why a trigger cycle was NOT counted (WS2 TODO 2.9 — "skip-count fix").
///
/// The engine always reports these on the frame where the counter trigger
/// committed but a gate failed, so the UI can show a "not counted" coach
/// message + haptic instead of dropping the rep silently.
enum RepRejectedReason {
  /// The required ROM state (`requiredPriorState`) wasn't visited since the
  /// last count — the rep didn't reach full range.
  rangeOfMotion,

  /// Trigger re-entered sooner than `CounterRule.minRepDuration` — the rep
  /// was too fast to be a real, controlled cycle.
  tooFast,
}

/// Result of one frame analysis.
@immutable
class BrainResult {
  const BrainResult({
    required this.exerciseId,
    required this.currentState,
    required this.previousState,
    required this.repCount,
    required this.angles,
    required this.feedback,
    required this.formScore,
    this.repJustCompleted = false,
    this.stateJustChanged = false,
    this.repRejectedReason,
    this.bilateral,
    this.holdSeconds = 0.0,
    this.trust,
    this.repHoldReason = HoldReason.none,
  });

  final String exerciseId;
  final String currentState;
  final String previousState;
  final int repCount;
  final Map<String, double> angles; // angleName -> degrees
  final List<FeedbackMessage> feedback;
  final int formScore; // 0-100
  final bool repJustCompleted;
  final bool stateJustChanged;

  /// Non-null exactly on the frame where the trigger committed but a
  /// ROM/timing gate refused the count (null = nothing was skipped).
  final RepRejectedReason? repRejectedReason;
  final BilateralStatus? bilateral;

  /// Cumulative seconds spent in the definition's hold state (duration
  /// exercises: plank, wall-sit…) — 0 for repetition work. Powers the
  /// session hold chip (`HOLD 12s / 30s`).
  final double holdSeconds;

  /// Frame trust (Batch 5): null in trust-blind mode (legacy/tests), where
  /// the engine behaves exactly as before.
  final TrustBreakdown? trust;

  /// Rep-level hold (Batch 5): non-none exactly on the frame where the FSM
  /// completed a rep but the trust accumulator vetoed the commit. The rep
  /// is HELD with its reason — never silently counted, never a phantom.
  final HoldReason repHoldReason;

  BrainResult copyWith({
    String? currentState,
    String? previousState,
    int? repCount,
    Map<String, double>? angles,
    List<FeedbackMessage>? feedback,
    int? formScore,
    bool? repJustCompleted,
    bool? stateJustChanged,
    RepRejectedReason? repRejectedReason,
    BilateralStatus? bilateral,
    double? holdSeconds,
    TrustBreakdown? trust,
    HoldReason? repHoldReason,
    bool clearRejection = false,
  }) =>
      BrainResult(
        exerciseId: exerciseId,
        currentState: currentState ?? this.currentState,
        previousState: previousState ?? this.previousState,
        repCount: repCount ?? this.repCount,
        angles: angles ?? this.angles,
        feedback: feedback ?? this.feedback,
        formScore: formScore ?? this.formScore,
        repJustCompleted: repJustCompleted ?? this.repJustCompleted,
        stateJustChanged: stateJustChanged ?? this.stateJustChanged,
        repRejectedReason:
            clearRejection ? null : (repRejectedReason ?? this.repRejectedReason),
        bilateral: bilateral ?? this.bilateral,
        holdSeconds: holdSeconds ?? this.holdSeconds,
        trust: trust ?? this.trust,
        repHoldReason: repHoldReason ?? this.repHoldReason,
      );
}

/// Feedback message with metadata.
@immutable
class FeedbackMessage {
  const FeedbackMessage({
    required this.name,
    required this.message,
    required this.audioCue,
    required this.severity, // 'warning' | 'info' | 'error'
  });

  final String name;
  final String message; // UI display
  final String audioCue; // TTS text (may be shorter/punchier)
  final String severity;

  factory FeedbackMessage.fromRule(FeedbackRule rule) => FeedbackMessage(
        name: rule.name,
        message: rule.message,
        audioCue: rule.audioCue ?? rule.message,
        severity: rule.type,
      );
}

/// Bilateral exercise status (left/right separate).
@immutable
class BilateralStatus {
  const BilateralStatus({
    required this.leftState,
    required this.rightState,
    required this.leftCount,
    required this.rightCount,
    required this.leftRepJustCompleted,
    required this.rightRepJustCompleted,
  });

  final String leftState;
  final String rightState;
  final int leftCount;
  final int rightCount;
  final bool leftRepJustCompleted;
  final bool rightRepJustCompleted;

  /// Reps completed on the stronger side — the same per-arm semantics as
  /// [BrainResult.repCount] (one curl set counts once, never twice).
  int get totalCount => math.max(leftCount, rightCount);
}

// ---------------------------------------------------------------------------
// Condition language
// ---------------------------------------------------------------------------
//
// Grammar:
//   expr         := or_expr
//   or_expr      := and_expr ('or' and_expr)*
//   and_expr     := not_expr ('and' not_expr)*
//   not_expr     := 'not' not_expr | comparison
//   comparison   := additive (('=='|'!='|'>'|'>='|'<'|'<=') additive)?
//   additive     := multiplicative (('+'|'-') multiplicative)*
//   multiplicative := unary (('*'|'/') unary)*
//   unary        := '-' unary | primary
//   primary      := number | string | bool | identifier | func_call | '(' expr ')'
//   func_call    := identifier '(' expr (',' expr)* ')'
//
// Values resolve to num | bool | String; comparisons use Dart equality for
// ==/!= and numeric ordering otherwise (non-numeric operands → false).

/// Safe expression evaluator for FSM conditions.
class ConditionEvaluator {
  /// Parsed-expression cache — the condition set is the static bundled
  /// catalog, so each rule is parsed ONCE instead of re-parsed on every
  /// state/rule × frame (25 fps × dozens of rules was pure waste).
  static final Map<String, _Expr> _parsed = {};

  /// Sentinel for unparseable conditions — always evaluates to false.
  static final _Expr _invalid = _Literal(false);

  /// Evaluate a condition string against a context. Never throws —
  /// unparseable rules evaluate to false and the rep simply doesn't count.
  static bool evaluate(String condition, Map<String, dynamic> context) {
    final _Expr expr = _parsed.putIfAbsent(condition, () {
      try {
        return _Parser(condition)._parseExpression();
      } catch (_) {
        return _invalid;
      }
    });
    try {
      return _truthy(expr.resolve(context));
    } catch (_) {
      return false;
    }
  }

  static bool _truthy(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v.isNotEmpty;
    return v != null;
  }

  static double _num(dynamic v) => v is num ? v.toDouble() : 0.0;
}

abstract class _Expr {
  dynamic resolve(Map<String, dynamic> ctx);
}

class _Literal extends _Expr {
  _Literal(this.value);
  final dynamic value;
  @override
  dynamic resolve(Map<String, dynamic> ctx) => value;
}

class _Variable extends _Expr {
  _Variable(this.name);
  final String name;
  @override
  dynamic resolve(Map<String, dynamic> ctx) =>
      ctx.containsKey(name) ? ctx[name] : 0.0;
}

class _Binary extends _Expr {
  _Binary(this.left, this.op, this.right);
  final _Expr left;
  final String op;
  final _Expr right;

  @override
  dynamic resolve(Map<String, dynamic> ctx) {
    final l = left.resolve(ctx);
    final r = right.resolve(ctx);
    switch (op) {
      case '==':
        return l == r;
      case '!=':
        return l != r;
      case '>':
        return l is num && r is num && l > r;
      case '>=':
        return l is num && r is num && l >= r;
      case '<':
        return l is num && r is num && l < r;
      case '<=':
        return l is num && r is num && l <= r;
      case 'and':
        return ConditionEvaluator._truthy(l) &&
            ConditionEvaluator._truthy(r);
      case 'or':
        return ConditionEvaluator._truthy(l) ||
            ConditionEvaluator._truthy(r);
      case '+':
        return ConditionEvaluator._num(l) + ConditionEvaluator._num(r);
      case '-':
        return ConditionEvaluator._num(l) - ConditionEvaluator._num(r);
      case '*':
        return ConditionEvaluator._num(l) * ConditionEvaluator._num(r);
      case '/':
        final d = ConditionEvaluator._num(r);
        return d == 0 ? 0.0 : ConditionEvaluator._num(l) / d;
      default:
        return false;
    }
  }
}

class _Not extends _Expr {
  _Not(this.inner);
  final _Expr inner;
  @override
  dynamic resolve(Map<String, dynamic> ctx) =>
      !ConditionEvaluator._truthy(inner.resolve(ctx));
}

class _Neg extends _Expr {
  _Neg(this.inner);
  final _Expr inner;
  @override
  dynamic resolve(Map<String, dynamic> ctx) =>
      -ConditionEvaluator._num(inner.resolve(ctx));
}

class _Call extends _Expr {
  _Call(this.name, this.args);
  final String name;
  final List<_Expr> args;

  @override
  dynamic resolve(Map<String, dynamic> ctx) {
    final vals = [for (final a in args) ConditionEvaluator._num(a.resolve(ctx))];
    switch (name) {
      case 'abs':
        return vals.isNotEmpty ? vals.first.abs() : 0.0;
      case 'min':
        return vals.isNotEmpty ? vals.reduce(math.min) : 0.0;
      case 'max':
        return vals.isNotEmpty ? vals.reduce(math.max) : 0.0;
      default:
        return 0.0; // unknown functions resolve to 0, never throw
    }
  }
}

class _Parser {
  _Parser(this.input);
  final String input;
  int _pos = 0;

  bool get _eof => _pos >= input.length;
  String get _ch => _eof ? '' : input[_pos];

  void _ws() {
    while (!_eof && input[_pos].trim().isEmpty) {
      _pos++;
    }
  }

  bool _lit(String s) {
    if (input.startsWith(s, _pos)) {
      _pos += s.length;
      return true;
    }
    return false;
  }

  bool _keyword(String kw) {
    final start = _pos;
    if (input.startsWith(kw, _pos)) {
      _pos += kw.length;
      if (!_eof) {
        final c = input[_pos];
        if (c.isLetterOrDigit || c == '_') {
          _pos = start;
          return false;
        }
      }
      return true;
    }
    return false;
  }

  Never _fail(String what) =>
      throw FormatException('Bad condition @$what: "$input"');

  _Expr _parseExpression() => _parseOr();

  _Expr _parseOr() {
    var left = _parseAnd();
    _ws();
    while (_keyword('or')) {
      _ws();
      left = _Binary(left, 'or', _parseAnd());
      _ws();
    }
    return left;
  }

  _Expr _parseAnd() {
    var left = _parseNot();
    _ws();
    while (_keyword('and')) {
      _ws();
      left = _Binary(left, 'and', _parseNot());
      _ws();
    }
    return left;
  }

  _Expr _parseNot() {
    _ws();
    if (_keyword('not')) {
      _ws();
      return _Not(_parseNot());
    }
    return _parseComparison();
  }

  _Expr _parseComparison() {
    final left = _parseAdditive();
    _ws();
    String? op;
    if (_lit('>=')) {
      op = '>=';
    } else if (_lit('<=')) {
      op = '<=';
    } else if (_lit('==')) {
      op = '==';
    } else if (_lit('!=')) {
      op = '!=';
    } else if (_lit('>')) {
      op = '>';
    } else if (_lit('<')) {
      op = '<';
    }
    if (op == null) return left;
    _ws();
    return _Binary(left, op, _parseAdditive());
  }

  _Expr _parseAdditive() {
    var left = _parseMultiplicative();
    _ws();
    while (true) {
      String? op;
      if (_lit('+')) {
        op = '+';
      } else if (_lit('-')) {
        op = '-';
      } else {
        break;
      }
      _ws();
      left = _Binary(left, op, _parseMultiplicative());
      _ws();
    }
    return left;
  }

  _Expr _parseMultiplicative() {
    var left = _parseUnary();
    _ws();
    while (true) {
      String? op;
      if (_lit('*')) {
        op = '*';
      } else if (_lit('/')) {
        op = '/';
      } else {
        break;
      }
      _ws();
      left = _Binary(left, op, _parseUnary());
      _ws();
    }
    return left;
  }

  _Expr _parseUnary() {
    _ws();
    if (_lit('-')) {
      _ws();
      return _Neg(_parseUnary());
    }
    return _parsePrimary();
  }

  _Expr _parsePrimary() {
    _ws();
    if (_eof) _fail('end');
    final c = _ch;
    if (c == "'") return _parseString();
    if (c.isDigit || c == '.') return _parseNumber();
    if (c.isLetter || c == '_') return _parseIdentOrCall();
    if (_lit('(')) {
      _ws();
      final e = _parseExpression();
      _ws();
      if (!_lit(')')) _fail(')');
      return e;
    }
    _fail('"$c"');
  }

  _Expr _parseString() {
    _pos++; // opening '
    final sb = StringBuffer();
    while (!_eof && _ch != "'") {
      sb.write(_ch);
      _pos++;
    }
    if (_eof) _fail('string');
    _pos++; // closing '
    return _Literal(sb.toString());
  }

  _Expr _parseNumber() {
    final start = _pos;
    var dot = false;
    while (!_eof && (_ch.isDigit || (_ch == '.' && !dot))) {
      if (_ch == '.') dot = true;
      _pos++;
    }
    final text = input.substring(start, _pos);
    final v = double.tryParse(text);
    if (v == null) _fail('number');
    return _Literal(v);
  }

  _Expr _parseIdentOrCall() {
    final start = _pos;
    while (!_eof && (_ch.isLetterOrDigit || _ch == '_')) {
      _pos++;
    }
    final name = input.substring(start, _pos);
    if (name == 'true') return _Literal(true);
    if (name == 'false') return _Literal(false);
    _ws();
    if (_lit('(')) {
      final args = <_Expr>[];
      _ws();
      if (!_lit(')')) {
        while (true) {
          args.add(_parseExpression());
          _ws();
          if (_lit(')')) break;
          if (!_lit(',')) _fail(',');
          _ws();
        }
      }
      return _Call(name, args);
    }
    return _Variable(name);
  }
}

extension on String {
  bool get isDigit {
    final c = codeUnitAt(0);
    return c >= 0x30 && c <= 0x39;
  }

  bool get isLetter {
    final c = codeUnitAt(0);
    return (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);
  }

  bool get isLetterOrDigit => isLetter || isDigit;
}

/// Consecutive-frame state stabilizer — a raw FSM state only commits after
/// [frames] identical evaluations in a row. Kills single-frame jitter from
/// noisy low-light detections without adding perceptible latency.
///
/// Confirmation is **wall-clock aware**: the evidence window targets ~80 ms
/// of consistency (never below 2 frames, never above [frames]). At 25-33
/// analyzed frames/s that is a 2-3 frame commit — phases of very fast reps
/// (up to ~3/s) confirm within the phase instead of the old fixed
/// 3-frame ≈ 240 ms window that dropped them.
class StateStabilizer {
  StateStabilizer(this.frames);

  final int frames;
  String state = 'unknown';
  String _pending = 'unknown';
  int _count = 0;

  /// Target wall-clock window for a commit (seconds) — sized so a
  /// 3-rep/sec cadence (≈110 ms per FSM phase) can still confirm.
  static const double confirmSeconds = 0.08;

  /// Frames required for the given inter-frame gap (seconds).
  int requiredFramesFor(double dtSec) {
    if (frames <= 1) return 1;
    if (dtSec <= 0) return frames;
    final int byTime = (confirmSeconds / dtSec).ceil();
    if (byTime < 2) return 2;
    return byTime > frames ? frames : byTime;
  }

  /// Pushes a raw state; returns true when the committed state changed.
  /// [dtSec] is the time since the previous push (0 when unknown).
  /// [frameCap] relaxes confirmation for count-critical states (the FSM
  /// trigger): the trigger commits after at most this many frames so a brief
  /// top-hold between fast reps can never lose an otherwise complete rep —
  /// phantom counts stay guarded by visit-memory + minRepDuration.
  bool push(String raw, [double dtSec = 0, int? frameCap]) {
    if (frames <= 1) {
      if (raw == state) return false;
      state = raw;
      return true;
    }
    if (raw == _pending) {
      _count++;
    } else {
      _pending = raw;
      _count = 1;
    }
    var need = requiredFramesFor(dtSec);
    if (frameCap != null && need > frameCap) need = frameCap;
    if (need < 2) need = 2; // a single frame is always noise
    if (_count >= need && _pending != state) {
      state = _pending;
      return true;
    }
    return false;
  }

  void reset() {
    state = 'unknown';
    _pending = 'unknown';
    _count = 0;
  }
}

// ---------------------------------------------------------------------------
// Brain engine
// ---------------------------------------------------------------------------

/// Main Brain Engine — runs one exercise FSM per frame.
class BrainEngine {
  BrainEngine(this.definition, {this.confirmFrames = 3});

  final ExerciseDefinition definition;

  /// Consecutive identical evaluations required before a state commits.
  final int confirmFrames;

  late final StateStabilizer _stab = StateStabilizer(confirmFrames);
  late final StateStabilizer _stabLeft = StateStabilizer(confirmFrames);
  late final StateStabilizer _stabRight = StateStabilizer(confirmFrames);

  String _previousState = 'unknown';
  int _repCount = 0;

  /// Cumulative seconds in the definition's hold state (8.1: duration
  /// exercises finally consume `holdState` — plank-style holds accumulate
  /// time credit instead of a meaningless rep tick).
  double _holdSeconds = 0;

  /// Rep-level trust accumulator (Batch 5): every fed frame's breakdown is
  /// pushed; a trigger commit goes through only on a passing verdict.
  final TrustAccumulator _trustAccum = TrustAccumulator();

  /// Latest frame breakdown (null in trust-blind mode).
  TrustBreakdown? _lastTrust;

  /// Last emitted result — held frames re-emit it frozen (no FSM advance).
  BrainResult? _lastResult;

  // Visit-memory: ROM states seen since the last counted rep.
  final Set<String> _visited = {};
  final Set<String> _visitedLeft = {};
  final Set<String> _visitedRight = {};

  /// Raw-frame evidence required before [CounterRule.requiredPriorState]
  /// counts as a visited ROM (user-reported: "many time it takes false
  /// counts" — reproduced: two-frame landmark-noise dips below the depth
  /// threshold committed the capped ROM state, and the return to the
  /// trigger completed a phantom cycle → 20/20 false counts at rest).
  ///
  /// Three consecutive raw frames (~100 ms at the 25-33 fps analysis rate)
  /// restores the pre-cap evidence bar for the *visit* while the trigger
  /// keeps its 2-frame commit — fast-rep latency (3-rep/sec contract) is
  /// untouched; only noise dips below the evidence bar lose their credit.
  static const int priorVisitMinFrames = 3;

  int _priorStreak = 0;
  int _priorStreakLeft = 0;
  int _priorStreakRight = 0;

  int _leftCount = 0;
  int _rightCount = 0;
  double _lastCountTime = 0;
  double _lastLeftCountTime = 0;
  double _lastRightCountTime = 0;

  final List<double> _repDurations = [];
  double? _repStartTime;
  final List<int> _repFormScores = [];
  int _currentFormScore = 100;
  int _avgFormScore = 100;

  /// Last completed rep durations (seconds, newest last) — powers the
  /// video-playback guard (a played demo video repeats near-perfectly; a
  /// real human does not). Read-only view.
  List<double> get recentRepDurations => List.unmodifiable(_repDurations);

  /// Rolling rep-window extrema per angle — powers `min_angle` /
  /// `max_angle` / `max_arm_angle` depth rules. Reset on trigger entry.
  final Map<String, double> _wMin = {};
  final Map<String, double> _wMax = {};

  /// Previous-frame angles/timestamp — powers `<angle>_vel` (deg/s) so
  /// direction-dependent states (jumping-jack closing) are reachable.
  final Map<String, double> _lastAngles = {};
  double? _lastT;

  /// Process one frame with computed angles.
  /// [angles]: angleName -> degrees (from PoseAnalyzer).
  /// [landmarkCoords]: landmarkName -> normalized 0..1 point.
  /// [timestamp]: seconds (monotonic within a session).
  /// [frameTrust]: Batch 5 trust breakdown, or null for trust-blind mode
  /// (legacy/tests — the engine behaves exactly as before). A held frame
  /// never advances the FSM: the previous result is re-emitted frozen.
  BrainResult processFrame({
    required Map<String, double> angles,
    required Map<String, LmPoint> landmarkCoords,
    required double timestamp,
    TrustBreakdown? frameTrust,
  }) {
    // Wall-clock gap since the previous analyzed frame — drives the
    // stabilizer's time-aware confirmation window.
    final double? lastT = _lastT;
    _frameDt = lastT == null ? 0.0 : timestamp - lastT;
    if (frameTrust != null) {
      _lastTrust = frameTrust;
      _trustAccum.push(frameTrust);
      if (frameTrust.held) {
        return _heldResult(frameTrust);
      }
    }
    _updateWindows(angles);
    final vels = _velocities(angles, timestamp);
    final context = _buildContext(angles, landmarkCoords, vels);
    final result = definition.bilateral
        ? _processBilateral(context, timestamp, angles)
        : _processUnilateral(context, timestamp, angles);
    _currentFormScore = _calculateFormScore(context, result.feedback);
    final out = result.copyWith(formScore: _currentFormScore, trust: frameTrust);
    _lastResult = out;
    return out;
  }

  /// Frozen re-emission for a held frame: same state/count as the last
  /// emitted result, no completion or rejection flags, trust attached.
  BrainResult _heldResult(TrustBreakdown breakdown) {
    final prev = _lastResult;
    if (prev == null) {
      return BrainResult(
        exerciseId: definition.id,
        currentState: 'unknown',
        previousState: 'unknown',
        repCount: 0,
        angles: const {},
        feedback: const [],
        formScore: 100,
        trust: breakdown,
      );
    }
    return prev.copyWith(
      repJustCompleted: false,
      stateJustChanged: false,
      clearRejection: true,
      trust: breakdown,
    );
  }

  /// Trust verdict for a rep that passed the ROM/timing gates: (commit?,
  /// reason). Thin history (< minFrames, e.g. low analysis fps) falls back
  /// to the current frame — every fed frame already cleared 0.85
  /// individually, so committing stays consistent instead of freezing fast
  /// workouts.
  (bool, HoldReason) _trustRepVerdict() {
    final current = _lastTrust;
    if (current == null) return (true, HoldReason.none); // trust-blind
    if (_trustAccum.n < _trustAccum.minFrames) {
      return (!current.held,
          current.held ? current.reason : HoldReason.none);
    }
    final (commit, _, reason) = _trustAccum.verdict();
    return (commit, reason);
  }

  /// Inter-frame gap of the frame currently being processed (seconds).
  double _frameDt = 0;

  Map<String, dynamic> _buildContext(
    Map<String, double> angles,
    Map<String, LmPoint> landmarkCoords,
    Map<String, double> vels,
  ) {
    final ctx = <String, dynamic>{};
    // Every declared angle always resolves — NaN when unmeasurable this
    // frame. Comparisons fail closed to 'unknown' instead of faking a 0°
    // joint (which used to read as fact, e.g. phantom 'bottom' states on
    // occluded knees, or a missing secondary satisfying `< 45` cues).
    for (final a in definition.angles) {
      ctx['${a.name}_angle'] = angles[a.name] ?? double.nan;
      ctx['${a.name}_vel'] = vels[a.name] ?? 0.0;
    }
    // Bare `angle` = primary angle (matches the YAML convention).
    ctx['angle'] = angles[definition.primaryAngle.name] ?? double.nan;
    ctx['angle_vel'] = vels[definition.primaryAngle.name] ?? 0.0;
    for (final entry in landmarkCoords.entries) {
      ctx['${entry.key}_x'] = entry.value.x;
      ctx['${entry.key}_y'] = entry.value.y;
    }
    // Landmark coords absent from this frame are unknown, not origin:
    // a missing wrist at x=0 would otherwise satisfy `< 0.05` edge rules.
    for (final name in definition.landmarks.keys) {
      if (!landmarkCoords.containsKey(name)) {
        ctx['${name}_x'] = double.nan;
        ctx['${name}_y'] = double.nan;
      }
    }
    ctx['state'] = _stab.state;
    final primaryName = definition.primaryAngle.name;
    if (_wMin.containsKey(primaryName)) {
      ctx['min_angle'] = _wMin[primaryName];
    }
    if (_wMax.containsKey(primaryName)) {
      ctx['max_angle'] = _wMax[primaryName];
    }
    final leftMax = _wMax['left_arm'];
    final rightMax = _wMax['right_arm'];
    if (leftMax != null || rightMax != null) {
      ctx['max_arm_angle'] = math.max(leftMax ?? 0, rightMax ?? 0);
    }
    return ctx;
  }

  void _updateWindows(Map<String, double> angles) {
    for (final entry in angles.entries) {
      final lo = _wMin[entry.key];
      _wMin[entry.key] = lo == null ? entry.value : math.min(lo, entry.value);
      final hi = _wMax[entry.key];
      _wMax[entry.key] = hi == null ? entry.value : math.max(hi, entry.value);
    }
  }

  /// Per-angle angular velocity in deg/s (0 on the first frame or when
  /// timestamps repeat). Same-frame deltas from EMA-smoothed input stay
  /// well above the ±40 °/s direction deadband used by adapted rules.
  Map<String, double> _velocities(
    Map<String, double> angles,
    double timestamp,
  ) {
    final out = <String, double>{};
    final prevT = _lastT;
    final dt = prevT == null ? 0.0 : timestamp - prevT;
    for (final entry in angles.entries) {
      final prev = _lastAngles[entry.key];
      out[entry.key] =
          (prev == null || dt <= 0) ? 0.0 : (entry.value - prev) / dt;
    }
    _lastAngles
      ..clear()
      ..addAll(angles);
    _lastT = timestamp;
    return out;
  }

  /// Adds this frame's delta to the hold clock when the committed state is
  /// a hold (8.1) — duration exercises (plank, wall-sit…) accumulate time
  /// credit; repetition work never calls this with true.
  void _accumulateHold(bool inHold) {
    if (inHold) _holdSeconds += _frameDt;
  }

  String? _evaluateRaw(Map<String, dynamic> context) {
    for (final stateName in definition.stateOrder) {
      final state = definition.getState(stateName);
      if (state == null) continue;
      if (ConditionEvaluator.evaluate(state.condition, context)) {
        return stateName;
      }
    }
    return null;
  }

  List<FeedbackMessage> _evaluateFeedback(Map<String, dynamic> context) {
    final out = <FeedbackMessage>[];
    for (final rule in definition.feedbackRules) {
      if (ConditionEvaluator.evaluate(rule.condition, context)) {
        out.add(FeedbackMessage.fromRule(rule));
      }
    }
    return out;
  }

  BrainResult _processUnilateral(
    Map<String, dynamic> context,
    double timestamp,
    Map<String, double> angles,
  ) {
    final raw = _evaluateRaw(context) ?? 'unknown';
    final committedBefore = _stab.state;
    // Count-critical states (trigger + required ROM visit) confirm in at
    // most 2 frames: they gate the rep itself, and a <90 ms bottom touch or
    // top-hold must never slip past the commit window.
    final rule = definition.counterRule;
    final int? cap =
        (raw == rule.triggerState || raw == rule.requiredPriorState) ? 2 : null;
    final changed = _stab.push(raw, _frameDt, cap);
    _previousState = committedBefore;
    final current = _stab.state;
    // ROM-visit credit — see priorVisitMinFrames: the commit cap alone
    // would let a two-frame noise dip fake depth and count a phantom rep
    // on the return to the trigger.
    final prior = rule.requiredPriorState;
    if (prior != null) {
      if (raw == prior) {
        _priorStreak++;
        if (_priorStreak >= priorVisitMinFrames) _visited.add(prior);
      } else {
        _priorStreak = 0;
      }
    }
    if (current == rule.triggerState) {
      _wMin.clear();
      _wMax.clear();
    }

    var repCompleted = false;
    RepRejectedReason? rejection;
    var repHold = HoldReason.none;
    // committedBefore != 'unknown': the very first commit of a session
    // (usually straight into the standing trigger) is not a completed
    // cycle — gating it keeps a phantom "not counted" off the coach bar
    // the moment the user steps into frame.
    if (changed &&
        committedBefore != 'unknown' &&
        current == rule.triggerState) {
      final romOk = rule.requiredPriorState == null ||
          _visited.contains(rule.requiredPriorState);
      final timingOk =
          (timestamp - _lastCountTime) >= rule.minRepDuration;
      if (romOk && timingOk) {
        // Batch 5: the FSM says rep — trust has the final word.
        final (commit, reason) = _trustRepVerdict();
        if (commit) {
          _repCount += rule.repIncrement;
          _lastCountTime = timestamp;
          repCompleted = true;
          _visited.clear();
          _visited.add(current);
          if (_repStartTime != null) {
            _repDurations.add(timestamp - _repStartTime!);
          }
          _repStartTime = timestamp;
          _repFormScores.add(_currentFormScore);
          _avgFormScore =
              (_repFormScores.reduce((a, b) => a + b) / _repFormScores.length)
                  .round();
        } else {
          // Trust-held rep: looks complete but the rep-level trust vetoed
          // it — held with its reason, never silently counted.
          repHold = reason;
        }
        _trustAccum.reset();
      } else {
        // Trigger committed but a gate refused the count — report WHY so the
        // coach bar can say "not counted" instead of dropping it silently.
        rejection = romOk
            ? RepRejectedReason.tooFast
            : RepRejectedReason.rangeOfMotion;
        _trustAccum.reset();
      }
    }

    context['state'] = current;
    // 8.1: duration exercises consume `holdState` here — time in the hold
    // accumulates as hold credit instead of a meaningless rep tick.
    _accumulateHold(
        definition.holdState != null && current == definition.holdState);
    // Evaluate feedback ONCE — the old code built the debug string with a
    // second full rule evaluation on every frame (pure per-frame waste).
    final feedback = _evaluateFeedback(context);
    if (kDebugMode) {
      debugPrint(
          'DBG uni raw=$raw current=$current min=${context['min_angle']} '
          'fb=${feedback.map((f) => f.name).toList()}');
    }
    return BrainResult(
      exerciseId: definition.id,
      currentState: current,
      previousState: _previousState,
      repCount: _repCount,
      angles: Map<String, double>.from(angles),
      feedback: feedback,
      formScore: _currentFormScore,
      repJustCompleted: repCompleted,
      stateJustChanged: changed,
      repRejectedReason: rejection,
      holdSeconds: _holdSeconds,
      repHoldReason: repHold,
    );
  }

  BrainResult _processBilateral(
    Map<String, dynamic> context,
    double timestamp,
    Map<String, double> angles,
  ) {
    final prevLeft = _stabLeft.state;
    final prevRight = _stabRight.state;

    // 8.1: side angle keys come from the definition's `sides` (hammer-curl
    // `['left', 'right']` → `left_angle`/`right_angle`) instead of hardcoded
    // names — a future bilateral definition with different side names keeps
    // working instead of silently evaluating both sides on the primary.
    final sides = definition.sides;
    final leftKey =
        '${sides.isNotEmpty ? sides[0] : 'left'}_angle';
    final rightKey =
        '${sides.length > 1 ? sides[1] : 'right'}_angle';
    final leftCtx = Map<String, dynamic>.from(context)
      ..['angle'] = context[leftKey] ?? context['angle'] ?? double.nan;
    final rightCtx = Map<String, dynamic>.from(context)
      ..['angle'] = context[rightKey] ?? context['angle'] ?? double.nan;

    final String rawLeft = _evaluateRaw(leftCtx) ?? 'unknown';
    final String rawRight = _evaluateRaw(rightCtx) ?? 'unknown';
    final rule0 = definition.counterRule;
    int? capFor(String raw) =>
        (raw == rule0.triggerState || raw == rule0.requiredPriorState)
            ? 2
            : null;
    final changedLeft = _stabLeft.push(rawLeft, _frameDt, capFor(rawLeft));
    final changedRight = _stabRight.push(rawRight, _frameDt, capFor(rawRight));
    // Per-side ROM-visit credit (same evidence bar as the unilateral path).
    final priorB = rule0.requiredPriorState;
    if (priorB != null) {
      if (rawLeft == priorB) {
        _priorStreakLeft++;
        if (_priorStreakLeft >= priorVisitMinFrames) _visitedLeft.add(priorB);
      } else {
        _priorStreakLeft = 0;
      }
      if (rawRight == priorB) {
        _priorStreakRight++;
        if (_priorStreakRight >= priorVisitMinFrames) {
          _visitedRight.add(priorB);
        }
      } else {
        _priorStreakRight = 0;
      }
    }

    var leftRep = false;
    var rightRep = false;
    RepRejectedReason? leftRejection;
    RepRejectedReason? rightRejection;
    var repHold = HoldReason.none;
    final rule = definition.counterRule;

    // Batch 5: each side's FSM rep passes the trust verdict independently;
    // the accumulator restarts at every rep boundary either way.
    (bool, HoldReason) gateRep() {
      final verdict = _trustRepVerdict();
      _trustAccum.reset();
      return verdict;
    }

    if (changedLeft &&
        prevLeft != 'unknown' &&
        _stabLeft.state == rule.triggerState) {
      final romOk = rule.requiredPriorState == null ||
          _visitedLeft.contains(rule.requiredPriorState);
      final timingOk =
          (timestamp - _lastLeftCountTime) >= rule.minRepDuration;
      if (romOk && timingOk) {
        final (commit, reason) = gateRep();
        if (commit) {
          _leftCount++;
          _lastLeftCountTime = timestamp;
          leftRep = true;
          _visitedLeft.clear();
          _visitedLeft.add(_stabLeft.state);
        } else {
          repHold = reason;
        }
      } else {
        leftRejection = romOk
            ? RepRejectedReason.tooFast
            : RepRejectedReason.rangeOfMotion;
        _trustAccum.reset();
      }
    }
    if (changedRight &&
        prevRight != 'unknown' &&
        _stabRight.state == rule.triggerState) {
      final romOk = rule.requiredPriorState == null ||
          _visitedRight.contains(rule.requiredPriorState);
      final timingOk =
          (timestamp - _lastRightCountTime) >= rule.minRepDuration;
      if (romOk && timingOk) {
        final (commit, reason) = gateRep();
        if (commit) {
          _rightCount++;
          _lastRightCountTime = timestamp;
          rightRep = true;
          _visitedRight.clear();
          _visitedRight.add(_stabRight.state);
        } else if (repHold == HoldReason.none) {
          repHold = reason;
        }
      } else {
        rightRejection = romOk
            ? RepRejectedReason.tooFast
            : RepRejectedReason.rangeOfMotion;
        _trustAccum.reset();
      }
    }
    // WS9.2: one count per completed cycle — a simultaneous curl fires
    // both sides on the same frame, so the left+right sum double-counted
    // every rep. The set tracks reps per arm (max), matching the
    // workout's "N reps" target in both simultaneous and alternating
    // styles.
    _repCount = math.max(_leftCount, _rightCount);

    final shown = <String, double>{};
    for (final entry in angles.entries) {
      shown[entry.key] = entry.value;
    }

    context['state'] = _stabLeft.state;
    final holdState = definition.holdState;
    _accumulateHold(holdState != null &&
        (_stabLeft.state == holdState || _stabRight.state == holdState));
    return BrainResult(
      exerciseId: definition.id,
      currentState: _stabLeft.state,
      previousState: prevLeft,
      repCount: _repCount,
      angles: shown,
      feedback: _evaluateFeedback(context),
      formScore: _currentFormScore,
      repJustCompleted: leftRep || rightRep,
      stateJustChanged: changedLeft || changedRight,
      // One message per frame: a rejected left side wins over the right.
      repRejectedReason: leftRejection ?? rightRejection,
      bilateral: BilateralStatus(
        leftState: _stabLeft.state,
        rightState: _stabRight.state,
        leftCount: _leftCount,
        rightCount: _rightCount,
        leftRepJustCompleted: leftRep,
        rightRepJustCompleted: rightRep,
      ),
      holdSeconds: _holdSeconds,
      repHoldReason: repHold,
    );
  }

  int _calculateFormScore(
    Map<String, dynamic> context,
    List<FeedbackMessage> feedback,
  ) {
    // 1. Angle accuracy (max 40 penalty).
    var anglePenalty = 0.0;
    var angleCount = 0;
    for (final entry in definition.formScore.idealAngles.entries) {
      final current =
          context['${entry.key}_angle'] ?? context['angle'] ?? 0.0;
      if (current is num) {
        anglePenalty += ((current - entry.value).abs() / 10) * 5;
        angleCount++;
      }
    }
    if (angleCount > 0) anglePenalty /= angleCount;

    // 2. Tempo (max 30 penalty).
    var tempoPenalty = 0.0;
    if (_repDurations.isNotEmpty) {
      final last = _repDurations.last;
      final minTempo = definition.formScore.tempoRange['min'] ?? 1.0;
      final maxTempo = definition.formScore.tempoRange['max'] ?? 3.0;
      if (last < minTempo) {
        tempoPenalty = ((minTempo - last) / 0.5) * 15;
      } else if (last > maxTempo) {
        tempoPenalty = (last - maxTempo) * 10;
      }
    }

    // 3. Real form faults only (max 30). Info lines never penalize.
    final faults =
        feedback.where((f) => f.severity == 'warning' || f.severity == 'error');
    final feedbackPenalty = faults.length * 10.0;

    return (100 -
            anglePenalty.clamp(0, 40).round() -
            tempoPenalty.clamp(0, 30).round() -
            feedbackPenalty.clamp(0, 30).round())
        .clamp(0, 100);
  }

  /// Reset engine for a new set/session.
  void reset() {
    _stab.reset();
    _stabLeft.reset();
    _stabRight.reset();
    _previousState = 'unknown';
    _repCount = 0;
    _visited.clear();
    _visitedLeft.clear();
    _visitedRight.clear();
    _priorStreak = 0;
    _priorStreakLeft = 0;
    _priorStreakRight = 0;
    _wMin.clear();
    _wMax.clear();
    _lastAngles.clear();
    _lastT = null;
    _leftCount = 0;
    _rightCount = 0;
    _lastCountTime = 0;
    _lastLeftCountTime = 0;
    _lastRightCountTime = 0;
    _repDurations.clear();
    _repStartTime = null;
    _repFormScores.clear();
    _currentFormScore = 100;
    _avgFormScore = 100;
    _holdSeconds = 0;
    _trustAccum.reset();
    _lastTrust = null;
    _lastResult = null;
  }

  /// Snapshot for reports / VEDA context.
  Map<String, dynamic> getStatus() => {
        'exercise': definition.id,
        'displayName': definition.displayName,
        'counter': _repCount,
        'currentState': _stab.state,
        'formScore': _currentFormScore,
        'avgFormScore': _avgFormScore,
        'formGrade': _formGrade(_currentFormScore),
      };

  String _formGrade(int score) {
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }
}
