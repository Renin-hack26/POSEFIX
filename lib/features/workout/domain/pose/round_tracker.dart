/// Round / set plan tracking for live sessions (WS2.3) — pure logic.
///
/// The session screen drives one [RoundTracker] per exercise: rep targets
/// come from the plan block (or the pre-session editor), rest breaks run
/// between rounds, and per-round reps/times accumulate for the session
/// record (`roundsCompleted` / `repsPerRound` / `roundTimesSec`).
///
/// Time base: engine timestamps (seconds, monotonic within a session).
/// Unit-tested in test/unit/round_tracker_test.dart.
library;

/// What observing the latest engine count produced.
enum RoundEvent {
  /// A non-final round hit its rep target — tick popup, set sound, rest.
  roundComplete,

  /// The final round hit its target — congrats popup, milestone sound.
  targetComplete,
}

/// Tracks one exercise's rounds against its rep target.
class RoundTracker {
  RoundTracker({
    required this.targetRounds,
    required this.targetReps,
    required this.restSec,
  }) : assert(targetRounds >= 1),
       assert(targetReps >= 1);

  final int targetRounds;
  final int targetReps;
  final int restSec;

  int currentRound = 1;
  final List<int> repsPerRound = [];
  final List<double> roundTimesSec = [];

  int _baseline = 0;
  double _roundStartT = 0;
  bool _started = false;

  /// Reps counted in the current round.
  int repsThisRound(int engineCount) => engineCount - _baseline;

  bool get isLastRound => currentRound >= targetRounds;

  bool get isComplete =>
      repsPerRound.length >= targetRounds;

  /// Observes the engine's cumulative rep count. Returns an event exactly
  /// once per completed round (null otherwise).
  RoundEvent? observe(int engineCount, double now) {
    if (!_started) {
      _started = true;
      _baseline = engineCount;
      _roundStartT = now;
    }
    if (engineCount - _baseline < targetReps) return null;
    repsPerRound.add(engineCount - _baseline);
    roundTimesSec.add(now - _roundStartT);
    if (isLastRound) return RoundEvent.targetComplete;
    currentRound++;
    _baseline = engineCount;
    _roundStartT = now;
    return RoundEvent.roundComplete;
  }

  /// Re-anchors the round after a rest break: movement during rest never
  /// counts toward the next round.
  void rebase(int engineCount, double now) {
    _baseline = engineCount;
    _roundStartT = now;
  }
}

/// `04:35`-style elapsed label for the HUD TIME chip.
String formatElapsed(Duration elapsed) {
  final total = elapsed.inSeconds.clamp(0, 99 * 60 + 59);
  final mm = (total ~/ 60).toString().padLeft(2, '0');
  final ss = (total % 60).toString().padLeft(2, '0');
  return '$mm:$ss';
}
