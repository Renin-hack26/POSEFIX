/// Exercise registry ↔ content-pack integrity.
///
/// User-reported bug class: a workout's exercise had no FSM definition, so
/// the camera session dead-ended with "Exercise not found" (`chair-dip` in
/// 3 bundled workouts — implemented by the `tricep_dip` FSM via alias).
/// These tests pin that EVERY content id resolves to a counting engine.
library;

import 'dart:convert';
import 'dart:io';

import 'package:fixpose/core/pose/exercise_catalog.dart';
import 'package:fixpose/core/pose/exercise_definition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(registerExerciseCatalog);

  dynamic loadJson(String path) =>
      jsonDecode(File(path).readAsStringSync());

  List<dynamic> itemsOf(dynamic root, List<String> keys) {
    if (root is List) return root;
    final map = root as Map<String, dynamic>;
    for (final key in keys) {
      final v = map[key];
      if (v is List) return v;
    }
    // Single-key wrapper: take its list value.
    for (final v in map.values) {
      if (v is List) return v;
    }
    fail('no list found in JSON root (keys tried: $keys)');
  }

  test('chair-dip resolves to the tricep_dip FSM (content alias)', () {
    final def = ExerciseRegistry.instance.resolve('chair-dip');
    expect(def, isNotNull, reason: 'chair-dip must have a counting engine');
    expect(def!.id, 'tricep_dip');
    // Alias also works in other accepted spellings.
    expect(ExerciseRegistry.instance.resolve('chair_dip')?.id, 'tricep_dip');
    expect(ExerciseRegistry.instance.resolve('Chair Dip')?.id, 'tricep_dip');
  });

  test('every exercise in exercises.json resolves to an FSM definition', () {
    final items = itemsOf(loadJson('assets/data/exercises.json'),
        const ['exercises', 'items']);
    expect(items.length, 40,
        reason: 'exercises.json must keep its 40 entries');
    final missing = <String>[];
    for (final raw in items) {
      final id = (raw as Map<String, dynamic>)['id'] as String;
      if (ExerciseRegistry.instance.resolve(id) == null) missing.add(id);
    }
    expect(missing, isEmpty,
        reason: 'content exercises without a counting FSM: $missing');
  });

  test('every workout block exerciseId resolves to an FSM definition', () {
    final items = itemsOf(loadJson('assets/data/workouts.json'),
        const ['workouts', 'items']);
    expect(items.length, 44,
        reason: 'workouts.json must keep its 44 entries');
    final missing = <String>{};
    var blockRefs = 0;
    for (final raw in items) {
      final workout = raw as Map<String, dynamic>;
      final blocks = (workout['blocks'] as List?) ?? const [];
      for (final b in blocks) {
        final exId = (b as Map<String, dynamic>)['exerciseId'] as String?;
        if (exId == null) continue;
        blockRefs++;
        if (ExerciseRegistry.instance.resolve(exId) == null) {
          missing.add('${workout['id']}/$exId');
        }
      }
    }
    expect(blockRefs, 240,
        reason: 'block→exercise references across the 44 workouts');
    expect(missing, isEmpty,
        reason: 'workout blocks without a counting FSM: $missing');
  });
}
