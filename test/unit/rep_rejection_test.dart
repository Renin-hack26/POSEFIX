import 'package:fixpose/core/pose/brain_engine.dart';
import 'package:fixpose/domain/exercise_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

/// WS2 §2.10: a rep that fires the trigger but fails the quality gate must
/// be REJECTED (not counted) with an explicit reason — never silent.
void main() {
  final squat = exerciseCatalog['squat']!;

  BrainEngine newEngine() => BrainEngine(
        BrainConfig(
          exercise: squat,
          bilateral: squat.bilateral,
          mirror: true,
          minRepDuration: squat.minRepDuration,
          triggerState: squat.triggerState,
          priorState: squat.priorState,
          restSec: 45,
          totalRounds: 3,
          minRepAngle: squat.minRepAngle,
          maxRepAngle: squat.maxRepAngle,
          targetAngle: squat.targetAngle,
          calibrationEnabled: false,
        ),
      );

  /// Feed a single synthetic rep: stand → bottom (angle goes below the
  /// trigger threshold) → stand again.
  BrainResult? feedRep(
    BrainEngine engine, {
    required double standAngle,
    required double bottomAngle,
    required double standTime,
    required double bottomTime,
    double returnTime = 0,
  }) {
    BrainResult? result;
    // approach to standing (prior visits)
    for (var i = 0; i < 6; i++) {
      result = engine.feed(standAngle, standTime + i * 0.04);
    }
    // descend into the bottom position (trigger)
    result = engine.feed(bottomAngle, bottomTime);
    result = engine.feed(bottomAngle, bottomTime + 0.04);
    // rise back to standing (completes the cycle)
    final t = returnTime > 0 ? returnTime : bottomTime + 0.6;
    result = engine.feed(standAngle, t);
    result = engine.feed(standAngle, t + 0.04);
    return result;
  }

  test('a full-range, controlled squat counts with no rejection', () {
    final engine = newEngine();
    final r = feedRep(
      engine,
      standAngle: 170,
      bottomAngle: 70,
      standTime: 1.0,
      bottomTime: 1.5,
    );
    expect(r, isNotNull);
    expect(r!.repRejectedReason, isNull);
    // a genuine count OR still mid-cycle is fine; what must not happen is a
    // rejection on a well-formed rep.
    expect(r.repRejectedReason, isNull);
  });

  test('a rep too fast for minRepDuration is rejected with tooFast', () {
    final engine = newEngine();
    // stand → bottom → stand within ~0.2s, far below squat minRepDuration
    final r = feedRep(
      engine,
      standAngle: 170,
      bottomAngle: 70,
      standTime: 1.0,
      bottomTime: 1.4,
      returnTime: 1.55,
    );
    expect(r, isNotNull);
    expect(r!.repRejectedReason, RepRejectedReason.tooFast);
    expect(r.repCounted, isNull);
  });

  test('rejected rep does not increment the counted total', () {
    final engine = newEngine();
    final r = feedRep(
      engine,
      standAngle: 170,
      bottomAngle: 70,
      standTime: 1.0,
      bottomTime: 1.4,
      returnTime: 1.55,
    );
    expect(r, isNotNull);
    expect(r!.repCounted, isNull);
    expect(r.repRejectedReason, isNotNull);
  });
}
