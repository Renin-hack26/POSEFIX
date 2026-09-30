/// Pose math unit tests — angle geometry, EMA smoothing, bbox/centroid.
library;

import 'package:fixpose/core/pose/pose_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('angleBetween', () {
    test('right angle', () {
      // BA = (0,-1), BC = (1,0) → 90°.
      expect(angleBetween((x: 0, y: 0), (x: 0, y: 1), (x: 1, y: 1)),
          closeTo(90, 1e-6));
    });

    test('straight line = 180°', () {
      expect(angleBetween((x: 0, y: 0), (x: 1, y: 0), (x: 2, y: 0)),
          closeTo(180, 1e-6));
    });

    test('squat-like knee flexion', () {
      // Hip (0.5,0.3), knee (0.5,0.6), ankle (0.65,0.9) → bent knee.
      final a = angleBetween((x: 0.5, y: 0.3), (x: 0.5, y: 0.6), (x: 0.65, y: 0.9));
      expect(a, lessThan(160));
      expect(a, greaterThan(60));
    });

    test('degenerate points return 0, never NaN', () {
      expect(angleBetween((x: 1, y: 1), (x: 1, y: 1), (x: 2, y: 2)), 0.0);
    });
  });

  group('EmaFilter', () {
    test('first push initializes', () {
      final f = EmaFilter(0.3);
      expect(f.push(10), 10);
    });

    test('converges toward steady input', () {
      final f = EmaFilter(0.5);
      f.push(0);
      expect(f.push(10), 5);
      expect(f.push(10), 7.5);
    });

    test('higher alpha tracks faster', () {
      final slow = EmaFilter(0.1)..push(0);
      final fast = EmaFilter(0.9)..push(0);
      expect(fast.push(100), greaterThan(slow.push(100)));
    });

    test('reset clears state', () {
      final f = EmaFilter(0.5)..push(42);
      f.reset();
      expect(f.value, isNull);
      expect(f.push(7), 7);
    });
  });

  group('boundingBox / centroid / distance', () {
    test('bbox extremes', () {
      final bb = boundingBox([(x: 0.2, y: 0.1), (x: 0.8, y: 0.9)]);
      expect((bb.minX, bb.minY, bb.maxX, bb.maxY), (0.2, 0.1, 0.8, 0.9));
    });

    test('centroid mean', () {
      final c = centroid([(x: 0, y: 0), (x: 1, y: 1)]);
      expect((c.x, c.y), (0.5, 0.5));
    });

    test('normalized distance', () {
      expect(normalizedDistance((x: 0, y: 0), (x: 3, y: 4)), closeTo(5, 1e-9));
    });
  });
}
