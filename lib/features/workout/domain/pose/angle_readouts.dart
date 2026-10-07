/// Exercise-aware angle readouts (WS8.4) — pure selection + labels.
///
/// The session screen renders the selected pair bottom-left + bottom-right
/// over the camera preview, fed from the BrainEngine's live (EMA-smoothed)
/// angles — never zeros for missing vertices.
///
/// Selection: bilateral exercises show L/R side angles; every other
/// exercise shows the primary angle on the left and the secondary (or next
/// live) angle on the right. Labels come from the angle description for
/// generic names (`primary`), otherwise from the humanized angle name.
///
/// Unit-tested in test/unit/ws8_engine_rules_test.dart.
library;

import 'exercise_definition.dart';

/// One rendered readout (`Knee flexion angle 142°`).
class AngleReadout {
  const AngleReadout({required this.label, required this.degrees});

  final String label;
  final double degrees;

  String get text => '$label ${degrees.round()}°';
}

/// Left readout + optional right readout.
class AngleReadoutPair {
  const AngleReadoutPair({required this.left, this.right});

  final AngleReadout left;
  final AngleReadout? right;
}

/// Selects the readout pair for [def] from this frame's live angles.
/// Null when nothing measurable is live.
AngleReadoutPair? angleReadouts(
  ExerciseDefinition def,
  Map<String, double> live,
) {
  if (def.angles.isEmpty) return null;
  if (def.bilateral) {
    final l = _sideLive(live, 'left', 'left_arm');
    final r = _sideLive(live, 'right', 'right_arm');
    if (l == null && r == null) return null;
    AngleReadout asReadout(String key, double v) =>
        AngleReadout(label: _sideLabel(key), degrees: v);
    if (l == null) return AngleReadoutPair(left: asReadout(r!.$1, r.$2));
    if (r == null) return AngleReadoutPair(left: asReadout(l.$1, l.$2));
    return AngleReadoutPair(
      left: asReadout(l.$1, l.$2),
      right: asReadout(r.$1, r.$2),
    );
  }
  final primary = def.primaryAngle;
  final candidates = [
    for (final a in def.angles)
      if (live.containsKey(a.name)) a,
  ];
  if (candidates.isEmpty) return null;
  final leftDef =
      live.containsKey(primary.name) ? primary : candidates.first;
  final AngleDef? rightDef = live.containsKey('secondary') &&
          'secondary' != leftDef.name
      ? def.getAngle('secondary')
      : candidates.firstWhere(
          (a) => a.name != leftDef.name,
          orElse: () => leftDef,
        );
  final pair = AngleReadoutPair(
    left: AngleReadout(
      label: _labelFor(def, leftDef.name),
      degrees: live[leftDef.name]!,
    ),
    right: rightDef == null || rightDef.name == leftDef.name
        ? null
        : AngleReadout(
            label: _labelFor(def, rightDef.name),
            degrees: live[rightDef.name]!,
          ),
  );
  return pair;
}

/// First live value under the preferred side keys (`left` before
/// `left_arm`), as a (key, value) record.
(String, double)? _sideLive(
  Map<String, double> live,
  String short,
  String long,
) {
  if (live.containsKey(short)) return (short, live[short]!);
  if (live.containsKey(long)) return (long, live[long]!);
  return null;
}

String _sideLabel(String key) => switch (key) {
      'left' => 'L',
      'right' => 'R',
      'left_arm' => 'L arm',
      'right_arm' => 'R arm',
      _ => _humanize(key),
    };

String _labelFor(ExerciseDefinition def, String name) {
  if (name == 'primary' || name == 'secondary') {
    final desc = def.getAngle(name)?.description.trim() ?? '';
    if (desc.isNotEmpty) return desc;
  }
  return _humanize(name);
}

String _humanize(String name) {
  final spaced = name.replaceAll('_', ' ').trim();
  if (spaced.isEmpty) return 'Angle';
  return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
}
