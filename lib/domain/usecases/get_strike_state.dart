import '../../engines/strike_engine/strike_engine.dart';
import '../entities/strike_state.dart';
import '../repositories/progress_repository.dart';

/// Read the strike with day-rollover applied (a broken streak reads 0, and
/// the rolled state is persisted so the reset survives restarts).
class GetStrikeState {
  GetStrikeState(this._progress, this._engine);

  final ProgressRepository _progress;
  final StrikeEngine _engine;

  Future<StrikeState> call() async {
    final stored = await _progress.strike();
    if (stored == null) return _engine.initial;
    final rolled = _engine.onRead(stored, DateTime.now());
    if (!identical(rolled, stored)) {
      await _progress.saveStrike(rolled);
    }
    return rolled;
  }
}
