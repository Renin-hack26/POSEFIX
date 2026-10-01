/// Progress report feature tests: data assembly (stats, personal details,
/// window rules, GROQ-first suggestions with rule-based fallback), the
/// markdown-ish section parser, the PDF export smoke (logo/date+time/RENIN
/// footer text present, uncompressed stream) and the report screen itself.
library;

import 'dart:convert';

import 'package:fixpose/core/di/app_dependencies.dart';
import 'package:fixpose/core/pdf/progress_report_pdf.dart';
import 'package:fixpose/core/report/report_sections.dart';
import 'package:fixpose/core/theme/app_theme.dart';
import 'package:fixpose/domain/entities/body_metric.dart';
import 'package:fixpose/domain/entities/chat_message.dart';
import 'package:fixpose/domain/entities/exercise.dart';
import 'package:fixpose/domain/entities/strike_state.dart';
import 'package:fixpose/domain/entities/user_profile.dart';
import 'package:fixpose/domain/entities/workout.dart';
import 'package:fixpose/domain/entities/workout_session.dart';
import 'package:fixpose/domain/repositories/progress_repository.dart';
import 'package:fixpose/domain/repositories/session_repository.dart';
import 'package:fixpose/domain/repositories/user_repository.dart';
import 'package:fixpose/domain/repositories/veda_repository.dart';
import 'package:fixpose/domain/repositories/workout_repository.dart';
import 'package:fixpose/domain/usecases/generate_progress_report.dart';
import 'package:fixpose/presentation/report/report_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Share sheet is a native call — tests swap the platform delegate so the
/// export flow completes deterministically (the real channel never answers
/// in the test environment).
class _FakeSharePlatform extends SharePlatform {
  bool called = false;

  @override
  Future<ShareResult> share(ShareParams params) async {
    called = true;
    return ShareResult.unavailable;
  }
}

class _FakeUserRepo implements UserRepository {
  _FakeUserRepo(this.profile);
  final UserProfile? profile;

  @override
  Future<UserProfile?> currentUser() async => profile;

  @override
  Stream<UserProfile?> authStateChanges() => Stream.value(profile);

  @override
  Future<OtpDispatch> signUp({
    required SignUpData data,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<OtpDispatch> resendSignUpOtp() => throw UnimplementedError();

  @override
  Future<void> verifyOtp({required String email, required String code}) =>
      throw UnimplementedError();

  @override
  Future<void> signIn({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<OtpDispatch> requestPasswordReset({required String email}) =>
      throw UnimplementedError();

  @override
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}

class _FakeSessionRepo implements SessionRepository {
  _FakeSessionRepo(this.items);
  final List<WorkoutSession> items;

  @override
  Future<WorkoutSession?> activeSession() async => null;

  @override
  Future<void> saveActive(WorkoutSession session) async {}

  @override
  Future<void> clearActive() async {}

  @override
  Future<void> completeSession(WorkoutSession session) async {}

  @override
  Future<List<WorkoutSession>> history({int limit = 100}) async =>
      items.take(limit).toList();

  @override
  Future<List<WorkoutSession>> sessionsBetween(
    DateTime from,
    DateTime to,
  ) async =>
      items
          .where((s) => !s.startedAt.isBefore(from) && s.startedAt.isBefore(to))
          .toList();
}

class _FakeProgressRepo implements ProgressRepository {
  _FakeProgressRepo({this.metricsList = const [], this.strikeState});
  final List<BodyMetric> metricsList;
  final StrikeState? strikeState;

  @override
  Future<StrikeState?> strike() async => strikeState;

  @override
  Future<void> saveStrike(StrikeState state) async {}

  @override
  Future<List<BodyMetric>> metrics({int limit = 365}) async => metricsList;

  @override
  Future<void> addMetric(BodyMetric metric) async {}
}

class _FakeWorkoutRepo implements WorkoutRepository {
  _FakeWorkoutRepo(this.items);
  final List<Workout> items;

  @override
  Future<List<Workout>> library() async => items;

  @override
  Future<Workout?> byId(String id) async {
    for (final w in items) {
      if (w.id == id) return w;
    }
    return null;
  }

  @override
  Future<List<Workout>> suggestions({int limit = 5}) async =>
      items.take(limit).toList();
}

class _FakeVedaRepo implements VedaRepository {
  _FakeVedaRepo({this.reply, this.error});
  final String? reply;
  final Object? error;

  @override
  Future<List<ChatMessage>> history() async => [];

  @override
  Future<void> saveMessage(ChatMessage message) async {}

  @override
  Future<void> clearHistory() async {}

  @override
  Future<String> complete({
    required List<ChatMessage> turns,
    required String systemPrompt,
  }) async {
    final e = error;
    if (e != null) throw e;
    return reply ?? '';
  }
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

Workout _workout(String id, String name) => Workout(
      id: id,
      name: name,
      category: WorkoutCategory.fullBody,
      level: Difficulty.beginner,
      goal: 'Get stronger',
      durationMin: 30,
      description: 'desc',
      focusMuscles: const [],
      blocks: const [],
      demoVideoAsset: '',
    );

WorkoutSession _session({
  required String id,
  required String workoutId,
  required DateTime startedAt,
  int durationSec = 1800,
  int reps = 120,
  double form = 88,
}) =>
    WorkoutSession(
      id: id,
      workoutId: workoutId,
      startedAt: startedAt,
      endedAt: startedAt.add(Duration(seconds: durationSec)),
      durationSec: durationSec,
      totalReps: reps,
      formAccuracyPct: form,
    );

final DateTime _now = DateTime(2026, 10, 1, 14, 30);

GenerateProgressReport _usecase({
  UserProfile? profile,
  List<WorkoutSession>? sessions,
  List<BodyMetric> metrics = const [],
  StrikeState? strike,
  String? aiReply,
  Object? aiError,
}) =>
    GenerateProgressReport(
      _FakeUserRepo(profile),
      _FakeSessionRepo(sessions ?? const []),
      _FakeProgressRepo(metricsList: metrics, strikeState: strike),
      _FakeWorkoutRepo([_workout('w1', 'Full Body Blast'), _workout('w2', 'Core Crusher')]),
      _FakeVedaRepo(reply: aiReply, error: aiError),
    );

final UserProfile _profile = UserProfile(
  uid: 'u1',
  firstName: 'Asha',
  middleName: '',
  lastName: 'Kumar',
  dateOfBirth: DateTime(1996, 5, 10),
  gender: Gender.female,
  email: 'asha@example.com',
  weightKg: 64.5,
  heightCm: 162,
);

List<WorkoutSession> _history() => [
      _session(
        id: 's1',
        workoutId: 'w1',
        startedAt: DateTime(2026, 9, 30, 18),
        durationSec: 1800,
        reps: 120,
        form: 88,
      ),
      _session(
        id: 's2',
        workoutId: 'w2',
        startedAt: DateTime(2026, 9, 28, 7),
        durationSec: 1200,
        reps: 90,
        form: 76,
      ),
      // Outside the 30-day window (window fallback case only).
      _session(
        id: 's3',
        workoutId: 'w1',
        startedAt: DateTime(2026, 7, 20, 7),
        durationSec: 600,
        reps: 50,
        form: 70,
      ),
    ];

const _aiReply = '## Overview\nSolid block of training.\n'
    '- Kept a steady rhythm\n'
    '## Recommendations\n- Add one session per week.';

// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GenerateProgressReport', () {
    test('assembles stats, personal details and AI suggestions', () async {
      final usecase = _usecase(
        profile: _profile,
        sessions: _history(),
        metrics: const [
          BodyMetric(dateKey: '2026-09-29', weightKg: 64.5, heightCm: 162),
          BodyMetric(dateKey: '2026-09-01', weightKg: 65.8),
        ],
        strike: const StrikeState(
          currentStrike: 5,
          longestStrike: 9,
          lastActiveDateKey: '2026-09-30',
        ),
        aiReply: _aiReply,
      );
      final report = await usecase(now: _now);

      // Timestamp carries date AND time (PDF requirement).
      expect(report.generatedAt, _now);
      expect(report.generatedAt.hour, 14);
      expect(report.generatedAt.minute, 30);

      // Personal details.
      expect(report.name, 'Asha Kumar');
      expect(report.email, 'asha@example.com');
      expect(report.ageYears, 30);
      expect(report.genderLabel, 'Female');
      expect(report.heightCm, 162);
      expect(report.weightKg, 64.5);
      expect(report.firstWeightKg, 65.8);
      expect(report.bmi, closeTo(64.5 / (1.62 * 1.62), 0.01));

      // Training window: trailing 30 days (sessions in July excluded).
      expect(report.periodFrom, DateTime(2026, 9, 1, 14, 30));
      expect(report.periodTo, _now);
      expect(report.sessionsTotal, 2);
      expect(report.workoutsTotal, 2);
      expect(report.activeDays, 2);
      expect(report.totalMinutes, 50);
      expect(report.totalReps, 210);
      expect(report.avgFormPct, closeTo(82.0, 0.01));
      expect(report.currentStrike, 5);

      // History rows resolve workout names from the library.
      expect(report.recentSessions, hasLength(2));
      expect(report.recentSessions.first.workoutName, 'Full Body Blast');
      expect(report.recentSessions.first.minutes, 30);

      // GROQ answered → verbatim AI text.
      expect(report.aiPowered, isTrue);
      expect(report.suggestions, _aiReply);
    });

    test('falls back to rule-based suggestions when AI fails', () async {
      final report = await _usecase(
        profile: _profile,
        sessions: _history(),
        aiError: Exception('offline'),
      )();

      expect(report.aiPowered, isFalse);
      expect(report.suggestions, contains('## Overview'));
      expect(report.suggestions, contains('## Recommendations'));
      expect(parseReportSections(report.suggestions).length, greaterThanOrEqualTo(4));
      // Stats still computed with AI unavailable.
      expect(report.sessionsTotal, 2);
    });

    test('empty trailing window falls back to full history period', () async {
      final report = await _usecase(
        profile: _profile,
        sessions: [
          _session(
            id: 's3',
            workoutId: 'w1',
            startedAt: DateTime(2026, 7, 20, 7),
          ),
        ],
        aiReply: _aiReply,
      )();

      expect(report.sessionsTotal, 1);
      expect(report.periodFrom, DateTime(2026, 7, 20, 7));
    });

    test('signed-out profile still yields a report from metrics', () async {
      final report = await _usecase(
        profile: null,
        sessions: const [],
        metrics: const [
          BodyMetric(dateKey: '2026-09-20', weightKg: 70, heightCm: 175),
        ],
        aiReply: _aiReply,
      )();

      expect(report.name, 'FixPose Athlete');
      expect(report.weightKg, 70);
      expect(report.heightCm, 175);
      expect(report.sessionsTotal, 0);
      expect(report.bmi, closeTo(70 / (1.75 * 1.75), 0.01));
    });
  });

  group('parseReportSections', () {
    test('splits headings, bullets, paragraphs and strips bold markers', () {
      final sections = parseReportSections(
        '## Overview\n**Great** month.\n- one\n- two\n# Next\nDo this.',
      );

      expect(sections, hasLength(2));
      expect(sections[0].heading, 'Overview');
      expect(sections[0].blocks, hasLength(3));
      expect(sections[0].blocks[0].type, ReportBlockType.paragraph);
      expect(sections[0].blocks[0].text, 'Great month.');
      expect(sections[0].blocks[1].type, ReportBlockType.bullet);
      expect(sections[0].blocks[1].text, 'one');
      expect(sections[1].heading, 'Next');
      expect(sections[1].blocks.single.text, 'Do this.');
    });

    test('body text without headings becomes one section', () {
      final sections = parseReportSections('just a line\nanother line');
      expect(sections, hasLength(1));
      expect(sections.single.heading, isEmpty);
      expect(sections.single.blocks, hasLength(2));
    });
  });

  group('buildProgressReportPdf', () {
    test('produces a PDF with logo header, date+time and RENIN footer',
        () async {
      final report = await _usecase(
        profile: _profile,
        sessions: _history(),
        strike: const StrikeState(
          currentStrike: 5,
          longestStrike: 9,
          lastActiveDateKey: '2026-09-30',
        ),
        aiReply: _aiReply,
      )();

      final bytes = await buildProgressReportPdf(report, compress: false);
      final raw = latin1.decode(bytes);

      expect(bytes, isNotEmpty);
      expect(raw, startsWith('%PDF-'));

      // The pdf package emits one text run per word — join runs so phrase
      // assertions (and human grepping) work.
      String flatten(String pdf) => RegExp(r'\((?:[^()\\]|\\.)*\)')
          .allMatches(pdf)
          .map((m) {
            final s = m.group(0)!;
            return s
                .substring(1, s.length - 1)
                .replaceAll('\\(', '(')
                .replaceAll('\\)', ')');
          })
          .join(' ');
      final text = flatten(raw);

      // Header: brand + generated date AND time.
      expect(text, contains('FixPose'));
      expect(text, contains('AI Progress Report'));
      expect(
        text,
        contains(DateFormat('d MMM yyyy, HH:mm').format(report.generatedAt)),
      );

      // Personal details section.
      expect(text, contains('Personal details'));
      expect(text, contains('Asha Kumar'));
      expect(text, contains('asha@example.com'));

      // Training + metrics + AI sections.
      expect(text, contains('Training summary'));
      expect(text, contains('Body metrics'));
      expect(text, contains('Analysis & recommendations'));
      expect(text, contains('Solid block of training.'));

      // RENIN copyright watermark footer.
      expect(text, contains('RENIN'));
      expect(text, contains('© ${report.generatedAt.year} RENIN.'));
      expect(text, contains('Page 1 of'));
    });
  });

  group('ReportScreen', () {
    testWidgets('renders report data and exports via share sheet',
        (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final prevShare = SharePlatform.instance;
      final fakeShare = _FakeSharePlatform();
      SharePlatform.instance = fakeShare;
      addTearDown(() => SharePlatform.instance = prevShare);

      final usecase = _usecase(
        profile: _profile,
        sessions: _history(),
        metrics: const [
          BodyMetric(dateKey: '2026-09-29', weightKg: 64.5, heightCm: 162),
          BodyMetric(dateKey: '2026-09-01', weightKg: 65.8),
        ],
        strike: const StrikeState(
          currentStrike: 5,
          longestStrike: 9,
          lastActiveDateKey: '2026-09-30',
        ),
        aiReply: _aiReply,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            generateProgressReportProvider.overrideWithValue(usecase),
          ],
          child: MaterialApp(
            theme: ThemeData(extensions: [AppPalette.dark]),
            home: const ReportScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header + generated stamp (date & time) + AI chip.
      expect(find.text('Progress report'), findsOneWidget);
      expect(find.textContaining('Generated'), findsOneWidget);
      expect(find.text('AI analysis'), findsOneWidget);

      // Personal details (top section — built immediately).
      expect(find.text('Asha Kumar'), findsOneWidget);

      // Deeper sections live in the lazy ListView — scroll them into the
      // tree before asserting.
      final scrollable = find.byType(Scrollable);
      await tester.scrollUntilVisible(
        find.text('Full Body Blast'),
        300,
        scrollable: scrollable,
      );
      expect(find.text('Full Body Blast'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Solid block of training.'),
        300,
        scrollable: scrollable,
      );
      expect(find.text('Solid block of training.'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Export PDF'),
        300,
        scrollable: scrollable,
      );

      // No layout overflow anywhere (RenderFlex regression guard).
      expect(tester.takeException(), isNull);

      // Export: share sheet is unavailable in tests → snackbar fallback.
      await tester.ensureVisible(find.text('Export PDF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export PDF'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not share the PDF'), findsNothing);
      expect(fakeShare.called, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('offline AI shows fallback chip and retry action',
        (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final usecase = _usecase(
        profile: _profile,
        sessions: _history(),
        aiError: Exception('offline'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            generateProgressReportProvider.overrideWithValue(usecase),
          ],
          child: MaterialApp(
            theme: ThemeData(extensions: [AppPalette.dark]),
            home: const ReportScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Built-in insights'), findsOneWidget);
      expect(find.text('AI offline — retry analysis'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('AI was unreachable — showing built-in insights.'),
        300,
        scrollable: find.byType(Scrollable),
      );
      expect(find.textContaining('AI was unreachable'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
