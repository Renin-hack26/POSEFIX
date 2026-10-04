/// Sync/download codecs must survive server JSON numbers arriving as int
/// when whole (PostgREST emits `30`, not `30.0`) — `cast<double>()` threw
/// on those and wedged the sync pass on a single row.
library;

import 'package:fixpose/data/mappers/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('decodeDoubles', () {
    test('accepts ints, doubles and mixes', () {
      expect(decodeDoubles('[30, 60]'), [30.0, 60.0]);
      expect(decodeDoubles('[1.5, 2]'), [1.5, 2.0]);
      expect(decodeDoubles('[]'), isEmpty);
    });
  });

  group('exerciseFromMap', () {
    test('int lists decode to typed lists', () {
      final ex = exerciseFromMap({
        'exerciseId': 'squat',
        'roundsCompleted': 2,
        'totalReps': 24,
        'formAccuracyPct': 87,
        'perRepTimesSec': [2, 2.5],
        'roundTimesSec': [60],
        'repsPerRound': [12, 12],
      });
      expect(ex.exerciseId, 'squat');
      expect(ex.roundsCompleted, 2);
      expect(ex.totalReps, 24);
      expect(ex.formAccuracyPct, 87.0);
      expect(ex.perRepTimesSec, [2.0, 2.5]);
      expect(ex.roundTimesSec, [60.0]);
      expect(ex.repsPerRound, [12, 12]);
    });

    test('missing keys fall back to empty/zero', () {
      final ex = exerciseFromMap({'exerciseId': 'plank'});
      expect(ex.roundsCompleted, 0);
      expect(ex.perRepTimesSec, isEmpty);
      expect(ex.repsPerRound, isEmpty);
    });
  });
}
