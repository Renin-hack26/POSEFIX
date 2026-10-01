/// Content integrity for the bundled JSON pack (assets/data/*.json).
///
/// The screens render this seed data directly, so every cross-reference,
/// demo path and required field must hold together — a broken pack fails
/// HERE (a readable list of offenders) instead of as a blank card, a
/// missing demo or a mapper crash on-device.
///
/// Decode chain mirrors ContentLoader / assets_json_test.dart: raw bytes →
/// utf8.decode → jsonDecode (no BOM handling — the BOM itself is asserted
/// byte-exact in assets_json_test.dart).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Raw bytes → utf8.decode → jsonDecode, exactly like the runtime loader.
Future<List<dynamic>> _loadList(String path) async {
  final bytes = await File(path).readAsBytes();
  return jsonDecode(utf8.decode(bytes)) as List<dynamic>;
}

Map<String, dynamic> _asMap(dynamic entry) => entry as Map<String, dynamic>;

/// True for a non-null, non-blank string.
bool _present(dynamic value) => value is String && value.trim().isNotEmpty;

void main() {
  late List<dynamic> exerciseEntries;
  late List<dynamic> workoutEntries;

  setUpAll(() async {
    exerciseEntries = await _loadList('assets/data/exercises.json');
    workoutEntries = await _loadList('assets/data/workouts.json');
  });

  /// Exercise id → record, for reference checking.
  Map<String, Map<String, dynamic>> exerciseById() => {
        for (final e in exerciseEntries) _asMap(e)['id'] as String: _asMap(e),
      };

  test('content pack is complete: 44 workouts over 40 exercises', () {
    expect(workoutEntries.length, 44,
        reason: 'workouts.json should ship the full 44-workout library');
    expect(exerciseEntries.length, 40,
        reason: 'exercises.json should ship the full 40-exercise catalog');
  });

  test('every workout block references an existing exercise', () {
    final ids = exerciseById().keys.toSet();
    final broken = <String>[];
    for (final w in workoutEntries) {
      final workout = _asMap(w);
      final blocks = workout['blocks'] as List<dynamic>? ?? const [];
      for (final b in blocks) {
        final ref = _asMap(b)['exerciseId'];
        if (ref is! String || !ids.contains(ref)) {
          broken.add('${workout['id']} → $ref');
        }
      }
    }
    expect(broken, isEmpty,
        reason: 'these blocks point at exercises that do not exist in '
            'exercises.json (the details plan would render a raw id and '
            'the instruction screen would open "not found"): $broken');
  });

  test('every declared exercise demo points at a bundled file', () {
    final missing = <String>[];
    var declared = 0;
    for (final e in exerciseEntries) {
      final exercise = _asMap(e);
      final asset = exercise['demoVideoAsset'];
      if (asset == null) continue; // documented gap, listed in the report
      declared++;
      if (!_present(asset)) {
        missing.add('${exercise['id']}: blank demoVideoAsset');
      } else if (!asset.startsWith('assets/demo/')) {
        // BUG-5: existence alone is not enough — a stray path outside the
        // bundled demo folder would resolve but never be shipped.
        missing.add('${exercise['id']}: $asset (not under assets/demo/)');
      } else if (!File(asset).existsSync()) {
        missing.add('${exercise['id']}: $asset');
      }
    }
    expect(declared, 36,
        reason: '36 of 40 exercises declare a demo GIF (v-up, warrior-flow, '
            'downward-dog, cobra-stretch are the documented nulls)');
    expect(missing, isEmpty,
        reason: 'declared demo files that are not on disk, or outside the '
            'assets/demo/ convention: $missing');
  });

  test('all 44 workouts carry the details-screen fields', () {
    final broken = <String>[];
    for (final w in workoutEntries) {
      final workout = _asMap(w);
      final id = '${workout['id']}';
      final focus = workout['focusMuscles'] as List<dynamic>? ?? const [];
      final blocks = workout['blocks'] as List<dynamic>? ?? const [];
      if (!_present(workout['name'])) broken.add('$id: name');
      if (!_present(workout['category'])) broken.add('$id: category');
      if (!_present(workout['level'])) broken.add('$id: level');
      if (!_present(workout['goal'])) broken.add('$id: goal');
      if (((workout['durationMin'] as num?)?.toInt() ?? 0) <= 0) {
        broken.add('$id: durationMin=${workout['durationMin']}');
      }
      if (focus.isEmpty) broken.add('$id: focusMuscles empty');
      if (((workout['estimatedCalories'] as num?)?.toInt() ?? 0) <= 0) {
        broken.add('$id: estimatedCalories=${workout['estimatedCalories']}');
      }
      if (blocks.isEmpty) broken.add('$id: blocks empty');
    }
    expect(broken, isEmpty,
        reason: 'required details-screen fields missing/empty: $broken');
  });

  test('all 40 exercises carry the instruction-screen fields', () {
    final broken = <String>[];
    for (final e in exerciseEntries) {
      final exercise = _asMap(e);
      final id = '${exercise['id']}';
      final muscles = exercise['primaryMuscles'] as List<dynamic>? ?? const [];
      if (!_present(exercise['id'])) broken.add('$id: id');
      if (!_present(exercise['name'])) broken.add('$id: name');
      if (!_present(exercise['kind'])) broken.add('$id: kind');
      if (!_present(exercise['difficulty'])) broken.add('$id: difficulty');
      if (!_present(exercise['description'])) broken.add('$id: description');
      if (muscles.isEmpty) broken.add('$id: primaryMuscles empty');
      if (exercise['formCues'] is! List) broken.add('$id: formCues');
      if ((exercise['met'] as num?) == null) broken.add('$id: met');
      if (exercise['isTimed'] is! bool) broken.add('$id: isTimed');
      if ((exercise['defaultSets'] as num?) == null) broken.add('$id: defaultSets');
      if ((exercise['defaultReps'] as num?) == null) broken.add('$id: defaultReps');
      if ((exercise['defaultSeconds'] as num?) == null) {
        broken.add('$id: defaultSeconds');
      }
    }
    expect(broken, isEmpty,
        reason: 'required exerciseFromJson/instruction fields: $broken');
  });

  test('workout demo paths follow the assets/videos/ convention', () {
    // NOTE: the 44 mp4 files are intentionally NOT bundled (assets/videos/
    // ships empty), so only the path shape is asserted here — never the
    // file's existence.
    final broken = <String>[];
    for (final w in workoutEntries) {
      final workout = _asMap(w);
      final id = '${workout['id']}';
      final asset = workout['demoVideoAsset'];
      if (asset == null) continue;
      // BUG-2: the filename must be exactly the workout id — a stale id or
      // a hand-edited path breaks every library card player.
      final expected = 'assets/videos/$id.mp4';
      if (!_present(asset)) {
        broken.add('$id: blank demoVideoAsset (expected $expected)');
      } else if (asset != expected) {
        broken.add('$id: $asset (expected $expected)');
      }
    }
    expect(broken, isEmpty,
        reason: 'workout-level demo paths must be exactly '
            'assets/videos/<id>.mp4 (or null): $broken');
  });

  test('exactly 4 exercises ship no demo GIF (form-guide fallback)', () {
    // Pin the documented no-GIF set: these four declare a null/blank
    // demoVideoAsset and the instruction screen falls back to the static
    // form-guide panel (see instruction_video_screen._buildMediaPanel).
    // Any new null/blank means a GIF was dropped from the content pack.
    final ids = <String>{
      for (final e in exerciseEntries)
        if (_asMap(e)['demoVideoAsset'] == null ||
            (_asMap(e)['demoVideoAsset'] is String &&
                (_asMap(e)['demoVideoAsset'] as String).trim().isEmpty))
          _asMap(e)['id'] as String,
    };
    expect(ids, {'v-up', 'warrior-flow', 'downward-dog', 'cobra-stretch'},
        reason: 'only v-up, warrior-flow, downward-dog and cobra-stretch may '
            'lack a demo GIF — they are the four form-guide-fallback '
            'exercises; every other null/blank is a missing bundle entry');
  });
}
