/// STRIKE_ENGINE rules (PLANNING §4.3) — pure, time-injected logic:
///  * first completed day starts the strike at 1,
///  * a second session on the same day leaves it untouched (no double credit),
///  * a consecutive day adds one,
///  * a gap of two or more days restarts at 1,
///  * the read-time rollover shows 0 once the streak broke.
library;

import 'package:fixpose/core/utils/extensions.dart';
import 'package:fixpose/domain/entities/strike_state.dart';
import 'package:fixpose/engines/strike_engine/strike_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = StrikeEngine();
  final dayOne = DateTime(2026, 9, 28, 7, 30);

  test('first completed day credits strike 1', () {
    final next = engine.onWorkoutCompleted(null, now: dayOne);

    expect(next.currentStrike, 1);
    expect(next.longestStrike, 1);
    expect(next.lastActiveDateKey, dayOne.dateKey);
  });

  test('second session on the same day is unchanged (credited once)', () {
    final first = engine.onWorkoutCompleted(null, now: dayOne);
    final second = engine.onWorkoutCompleted(first, now: dayOne.add(const Duration(hours: 5)));

    expect(second.currentStrike, first.currentStrike);
    expect(second.lastActiveDateKey, first.lastActiveDateKey);
    // Same instance → the call site can skip the write entirely.
    expect(identical(second, first), isTrue);
  });

  test('consecutive day adds one', () {
    final first = engine.onWorkoutCompleted(null, now: dayOne);
    final next = engine.onWorkoutCompleted(first, now: dayOne.add(const Duration(days: 1)));

    expect(next.currentStrike, 2);
    expect(next.longestStrike, 2);
    expect(next.lastActiveDateKey, dayOne.add(const Duration(days: 1)).dateKey);
  });

  test('a gap of two or more days restarts the strike at 1', () {
    final first = engine.onWorkoutCompleted(null, now: dayOne);
    final after = engine.onWorkoutCompleted(
      first.copyWith(currentStrike: 4, longestStrike: 4),
      now: dayOne.add(const Duration(days: 3)),
    );

    expect(after.currentStrike, 1);
    expect(after.longestStrike, 4); // longest is never revoked
  });

  test('badge tiers unlock as the strike grows', () {
    StrikeState state = engine.onWorkoutCompleted(null, now: dayOne);
    state = engine.onWorkoutCompleted(state, now: dayOne.add(const Duration(days: 1)));
    state = engine.onWorkoutCompleted(state, now: dayOne.add(const Duration(days: 2)));

    expect(state.currentStrike, 3);
    expect(state.unlockedTiers, contains(3));
    expect(state.unlockedTiers, isNot(contains(7)));
  });

  test('read-time rollover resets a broken streak to 0', () {
    final stale = engine.initial.copyWith(
      currentStrike: 6,
      longestStrike: 6,
      lastActiveDateKey: dayOne.dateKey,
    );

    // Still current (yesterday) → untouched.
    final recent = engine.onRead(stale, dayOne.add(const Duration(days: 1)));
    expect(identical(recent, stale), isTrue);

    // Gap ≥ 2 days → display resets, tiers are kept.
    final rolled = engine.onRead(stale, dayOne.add(const Duration(days: 3)));
    expect(rolled.currentStrike, 0);
    expect(rolled.lastActiveDateKey, dayOne.dateKey);
  });
}
