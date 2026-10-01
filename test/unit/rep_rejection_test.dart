import 'package:fixpose/core/pose/brain_engine.dart';
import 'package:fixpose/core/pose/exercise_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rep rejection & count integrity (WS2 §2.10 + WS9.4): a rep that fires
/// the trigger but fails a quality gate must be REJECTED (not counted)
/// with an explicit reason; a well-formed rep counts exactly once; and a
/// rep that never reaches depth gets a range-of-motion rejection instead
/// of a silent drop.
void main() {
  final squat = squatDefinition;

  BrainEngine newEngine() => BrainEngine(squat);

  /// Feeds one synthetic frame at [angle] (primary) on the monotonic clock.
  BrainResult feed(BrainEngine e, double angle, double t) => e.processFrame(
        angles: {'primary': angle, 'secondary': 70.0},
        landmarkCoords: const {},
        timestamp: t,
      );

  /// Holds [angle] for [n] frames at [dt] cadence starting at [t0];
  /// returns the last result.
  BrainResult hold(BrainEngine e, double angle, double t0, double dt, int n) {
    BrainResult? last;
    for (var i = 0; i < n; i++) {
      last = feed(e, angle, t0 + i * dt);
    }
    return last!;
  }

  /// Full squat cycle: top hold → descend → bottom hold → ascend → top.
  /// Returns the frame that MATTERS: the count frame when one fired, else
  /// the rejection frame, else the last frame fed.
  BrainResult squatRep(
    BrainEngine e, {
    required double t0,
    double dt = 0.04,
    double top = 170,
    double depth = 80,
  }) {
    BrainResult? last;
    BrainResult? countFrame;
    BrainResult? rejectFrame;
    BrainResult track(BrainResult r) {
      last = r;
      if (r.repJustCompleted) countFrame = r;
      if (r.repRejectedReason != null) rejectFrame = r;
      return r;
    }

    track(hold(e, top, t0, dt, 3));
    var t = t0 + 3 * dt;
    // Descend through the mid band into depth.
    for (final a in [150.0, 130.0, 110.0, 95.0, depth]) {
      track(feed(e, a, t));
      t += dt;
    }
    // Bottom hold — enough raw frames for the prior-visit evidence bar.
    track(hold(e, depth, t, dt, 4));
    t += 4 * dt;
    // Ascend back through the mid band to full extension.
    for (final a in [95.0, 110.0, 130.0, 150.0, 162.0, top]) {
      track(feed(e, a, t));
      t += dt;
    }
    // Second top frame commits the trigger.
    track(feed(e, top, t));
    return countFrame ?? rejectFrame ?? last!;
  }

  test('a full-range, controlled squat counts exactly once, no rejection',
      () {
    final engine = newEngine();
    final r = squatRep(engine, t0: 0.0);
    expect(engine, isNotNull);
    expect(r.repCount, 1, reason: 'one full cycle must count exactly once');
    expect(r.repJustCompleted, isTrue,
        reason: 'the count lands on the trigger re-commit frame');
    expect(r.repRejectedReason, isNull);
  });

  test('consecutive controlled squats keep a stable 1:1 count', () {
    final engine = newEngine();
    var t = 0.0;
    BrainResult? last;
    for (var i = 0; i < 5; i++) {
      last = squatRep(engine, t0: t);
      t += 1.0; // one second per rep — comfortably over minRepDuration
    }
    expect(last!.repCount, 5,
        reason: '5 well-formed reps must produce exactly 5 counts');
    expect(last.repRejectedReason, isNull);
  });

  test('a rep too fast for minRepDuration is rejected with tooFast',
      () {
    final engine = newEngine();
    // Compressed clock: the whole cycle completes well under the 0.3 s
    // minRepDuration (measured from the last *counted* rep, initially 0).
    final r = squatRep(engine, t0: 0.02, dt: 0.015, top: 168, depth: 75);
    expect(r.repRejectedReason, RepRejectedReason.tooFast);
    expect(r.repCount, 0, reason: 'a rejected rep must not increment');
    expect(r.repJustCompleted, isFalse);
  });

  test('a shallow rep (never reaches depth) is rejected as rangeOfMotion',
      () {
    final engine = newEngine();
    // Establish the top.
    hold(engine, 170, 0.0, 0.04, 3);
    var t = 0.12;
    // Descent stops at 95° — above the ≤90 bottom threshold.
    for (final a in [150.0, 130.0, 110.0, 95.0, 93.0]) {
      feed(engine, a, t);
      t += 0.04;
    }
    hold(engine, 95, t, 0.04, 4);
    t += 0.16;
    // Back to the top: trigger fires, ROM visit never happened.
    feed(engine, 130, t);
    t += 0.04;
    feed(engine, 155, t);
    t += 0.04;
    final r1 = feed(engine, 170, t);
    t += 0.04;
    final r = feed(engine, 170, t);
    expect(r.repRejectedReason ?? r1.repRejectedReason,
        RepRejectedReason.rangeOfMotion);
    expect(r.repCount, 0);
  });

  test('noise at rest never counts (no bottom visit, no phantom cycle)',
      () {
    final engine = newEngine();
    BrainResult? last;
    var t = 0.0;
    // Standing jitter around the top for two seconds — a bare trigger
    // state without a depth visit must never count or reject-spam.
    for (var i = 0; i < 50; i++) {
      last = feed(engine, i.isEven ? 170.0 : 158.0, t);
      t += 0.04;
    }
    expect(last!.repCount, 0);
    expect(last.repRejectedReason, isNull,
        reason: 'no cycle was attempted, so nothing may be reported');
  });
}
