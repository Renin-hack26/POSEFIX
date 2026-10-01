import 'dart:convert';
import 'dart:io';

import 'package:fixpose/core/theme/app_theme.dart';
import 'package:fixpose/data/mappers/content_mappers.dart';
import 'package:fixpose/domain/entities/exercise.dart';
import 'package:fixpose/domain/entities/workout.dart';
import 'package:fixpose/presentation/home/widgets/session_slot.dart';
import 'package:fixpose/presentation/home/widgets/suggestions_carousel.dart';
import 'package:fixpose/presentation/home/widgets/tips_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// TEMPORARY visual probe — renders suspect widgets/cards at 360dp with the
/// real system font so layout defects are visible in the golden PNGs.
/// Run: flutter test --update-goldens test/widget/visual_probe_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> loadRealFont() async {
    final file = File(r'C:\Windows\Fonts\segoeui.ttf');
    if (!file.existsSync()) return;
    final bytes = await file.readAsBytes();
    final loader = FontLoader('SegoeProbe')
      ..addFont(Future<ByteData>.value(
          ByteData.sublistView(Uint8List.fromList(bytes))));
    await loader.load();
  }

  setUpAll(loadRealFont);

  Future<void> pumpAt(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        fontFamily: 'SegoeProbe',
        extensions: [AppPalette.dark],
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF0C1013),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
            child: SingleChildScrollView(child: child),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('probe: coach tips carousel (real tips.json data)', (tester) async {
    final raw = jsonDecode(
        File('assets/data/tips.json').readAsStringSync()) as List<dynamic>;
    final tips = [
      for (final e in raw) (e as Map<String, dynamic>)['text'] as String,
    ]..sort((a, b) => b.length.compareTo(a.length)); // longest first (worst case)
    await pumpAt(
      tester,
      TipsCarousel(tips: [
        for (final t in tips) (title: 'Coach tip', body: t),
      ]),
    );
    await expectLater(find.byType(TipsCarousel),
        matchesGoldenFile('probe_home_tips.png'));
  });

  testWidgets('probe: session slot', (tester) async {
    await pumpAt(
      tester,
      SessionSlot(
        when: 'TODAY · 17:00',
        title: 'Lower Body Foundation',
        details: '6 exercises · 4 sets · about 32 min',
        onStart: () {},
      ),
    );
    await expectLater(find.byType(SessionSlot),
        matchesGoldenFile('probe_home_slot.png'));
  });

  testWidgets('probe: suggestion cards (real workouts.json data)', (tester) async {
    final raw = jsonDecode(
        File('assets/data/workouts.json').readAsStringSync()) as List<dynamic>;
    final workouts = [
      for (final e in raw)
        workoutFromJson(e as Map<String, dynamic>, 'workouts.json'),
    ];
    final icons = [Icons.whatshot, Icons.fitness_center, Icons.self_improvement];
    await pumpAt(
      tester,
      SuggestionsCarousel(
        items: [
          for (var i = 0; i < workouts.length && i < 5; i++)
            (
              title: workouts[i].name,
              caption:
                  '${workouts[i].category.label} · ${workouts[i].durationMin} min',
              subtitle: workouts[i].goal,
              icon: icons[i % icons.length],
              accentThumb: i.isEven,
            ),
        ],
        onOpen: () {},
      ),
    );
    await expectLater(find.byType(SuggestionsCarousel),
        matchesGoldenFile('probe_home_suggestions.png'));
  });

  testWidgets('probe: plan library cards (exact card markup, both themes)',
      (tester) async {
    final raw = jsonDecode(File('assets/data/exercises.json').readAsStringSync())
        as List<dynamic>;
    final exercises = [
      for (final e in raw)
        exerciseFromJson(e as Map<String, dynamic>, 'exercises.json'),
    ].take(3).toList();
    await pumpAt(
      tester,
      _ProbeLibraryCards(exercises: exercises),
    );
    await expectLater(find.byType(_ProbeLibraryCards),
        matchesGoldenFile('probe_plan_library_cards.png'));
  });

  testWidgets('probe: plan broken glyphs vs correct', (tester) async {
    await pumpAt(
      tester,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PLAN HEADER (as coded, U+FFFD):',
              style: TextStyle(fontSize: 11, color: Colors.white70)),
          Text('Oct 1 \uFFFD Oct 7',
              style: const TextStyle(fontSize: 16, color: Colors.white)),
          const SizedBox(height: 8),
          const Text('LIBRARY CARD (as coded):',
              style: TextStyle(fontSize: 11, color: Colors.white70)),
          Text('Chest \uFFFD 4 cues',
              style: const TextStyle(fontSize: 14, color: Colors.white)),
          const SizedBox(height: 8),
          const Text('SESSION PILL (as coded):',
              style: TextStyle(fontSize: 11, color: Colors.white70)),
          Text('Tue \uFFFD 17:00',
              style: const TextStyle(fontSize: 14, color: Colors.white)),
          const SizedBox(height: 8),
          const Text('CORRECT (with middot):',
              style: TextStyle(fontSize: 11, color: Colors.white70)),
          Text('Oct 1 · Oct 7   Chest · 4 cues   Tue · 17:00',
              style: const TextStyle(fontSize: 14, color: Colors.white)),
        ],
      ),
    );
    await expectLater(find.byType(Column),
        matchesGoldenFile('probe_plan_glyphs.png'));
  });
}

/// Both palettes' card rows, labeled — one finder target for the golden.
class _ProbeLibraryCards extends StatelessWidget {
  const _ProbeLibraryCards({required this.exercises});

  final List<Exercise> exercises;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('LIBRARY CARDS — DARK:',
            style: TextStyle(fontSize: 11, color: Colors.white70)),
        const SizedBox(height: 6),
        _ProbeLibraryRow(exercises: exercises, paletteOverride: AppPalette.dark),
        const SizedBox(height: 16),
        const Text('LIBRARY CARDS — LIGHT:',
            style: TextStyle(fontSize: 11, color: Colors.white70)),
        const SizedBox(height: 6),
        _ProbeLibraryRow(
            exercises: exercises, paletteOverride: AppPalette.light),
      ],
    );
  }
}

/// Horizontal row of cards at the section's exact height (146) — copies
/// `_LibrarySection`'s ListView so layout defects reproduce 1:1.
class _ProbeLibraryRow extends StatelessWidget {
  const _ProbeLibraryRow({
    required this.exercises,
    required this.paletteOverride,
  });

  final List<Exercise> exercises;
  final AppPalette paletteOverride;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(extensions: [
        for (final e in base.extensions.values)
          if (e is! AppPalette) e,
        paletteOverride,
      ]),
      child: SizedBox(
        height: 146,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (var i = 0; i < exercises.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              _ProbeLibraryCard(exercise: exercises[i], toneIndex: i % 3),
            ],
          ],
        ),
      ),
    );
  }
}

/// Verbatim copy of PlanScreen's `_LibraryCard` build method.
class _ProbeLibraryCard extends StatelessWidget {
  const _ProbeLibraryCard({required this.exercise, required this.toneIndex});

  final Exercise exercise;
  final int toneIndex;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (colors, glyphColor) = switch (toneIndex) {
      0 => ([p.ink3, p.ink2], p.selFg),
      1 => ([p.accentSoft, p.accentDeep], p.selBg),
      _ => ([p.trackStrong, p.selBg], p.selFg),
    };
    final muscle = exercise.primaryMuscles.isNotEmpty
        ? exercise.primaryMuscles.first.label
        : 'General';
    final card = Container(
      width: 130,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: p.glass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: p.shadowSoft,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
            ),
            child: Center(
              child: Icon(
                _probeIconForMuscle(exercise.primaryMuscles),
                size: 38,
                color: glyphColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$muscle · ${exercise.formCues.length} cues',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: p.ink3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    // Material + InkWell make the card tappable; both paint nothing while
    // the card is at rest, so the rendered pixels stay identical.
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {},
        child: card,
      ),
    );
  }
}

IconData _probeIconForMuscle(List<MuscleGroup> muscles) {
  if (muscles.isEmpty) return Icons.fitness_center;
  return switch (muscles.first) {
    MuscleGroup.chest => Icons.fitness_center,
    MuscleGroup.back => Icons.sports,
    MuscleGroup.legs => Icons.directions_run,
    MuscleGroup.glutes => Icons.directions_walk,
    MuscleGroup.shoulders => Icons.accessibility_new,
    MuscleGroup.arms => Icons.front_hand,
    MuscleGroup.core => Icons.self_improvement,
    MuscleGroup.cardio => Icons.bolt,
    MuscleGroup.fullBody => Icons.sports,
    MuscleGroup.mobility => Icons.self_improvement,
  };
}
