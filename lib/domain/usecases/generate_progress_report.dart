import 'dart:math';

import 'package:intl/intl.dart';

import '../entities/chat_message.dart';
import '../entities/progress_report.dart';
import '../entities/user_profile.dart';
import '../entities/workout_session.dart';
import '../repositories/progress_repository.dart';
import '../repositories/session_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/veda_repository.dart';
import '../repositories/workout_repository.dart';

/// Assembles the AI progress report (Home → Progress report).
///
/// Inputs: profile (personal details + height/weight), the trailing
/// [windowDays] of completed sessions (widened to full history when the
/// window is empty but older sessions exist), body metrics and strike.
///
/// Suggestions are GROQ-first (one completion over the same transport as
/// VEDA — `openai/gpt-oss-120b`); when the build has no key or the network
/// fails, a deterministic rule-based write-up is used instead. The report —
/// and its PDF — always generate either way.
class GenerateProgressReport {
  GenerateProgressReport(
    this._user,
    this._sessions,
    this._progress,
    this._workouts,
    this._veda,
  );

  final UserRepository _user;
  final SessionRepository _sessions;
  final ProgressRepository _progress;
  final WorkoutRepository _workouts;
  final VedaRepository _veda;

  /// Trailing report window (days).
  static const int windowDays = 30;

  /// Newest sessions listed in the history table.
  static const int recentRows = 10;

  Future<ProgressReport> call({DateTime? now}) async {
    final nowDt = now ?? DateTime.now();
    final profile = await _user.currentUser();
    final allSessions = await _sessions.history(limit: 100);
    final metrics = await _progress.metrics(limit: 365);
    final strike = await _progress.strike();
    final library = await _workouts.library();

    // ---- Window: trailing 30 days, else full history (new accounts) ----
    final cutoff = nowDt.subtract(const Duration(days: windowDays));
    final inWindow =
        allSessions.where((s) => !s.startedAt.isBefore(cutoff)).toList();
    final List<WorkoutSession> windowSessions;
    final DateTime periodFrom;
    if (inWindow.isNotEmpty) {
      windowSessions = inWindow;
      periodFrom = cutoff;
    } else {
      windowSessions = allSessions;
      periodFrom = allSessions.isEmpty
          ? nowDt
          : allSessions
              .map((s) => s.startedAt)
              .reduce((a, b) => a.isBefore(b) ? a : b);
    }

    // ---- Training stats ----
    final sessionsTotal = windowSessions.length;
    final workoutsTotal =
        windowSessions.map((s) => s.workoutId).toSet().length;
    final activeDays = windowSessions
        .map((s) => DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day))
        .toSet()
        .length;
    final totalMinutes = windowSessions.fold<int>(
        0, (sum, s) => sum + (s.durationSec / 60).round());
    final totalReps =
        windowSessions.fold<int>(0, (sum, s) => sum + s.totalReps);
    final avgFormPct = sessionsTotal == 0
        ? 0.0
        : windowSessions.fold<double>(0, (sum, s) => sum + s.formAccuracyPct) /
            sessionsTotal;

    // ---- Body metrics (repo returns newest first) ----
    double? weightKg;
    double? firstWeightKg;
    double? heightCm;
    if (metrics.isNotEmpty) {
      weightKg = metrics.first.weightKg;
      firstWeightKg = metrics.last.weightKg;
      for (final m in metrics) {
        if (m.heightCm != null) {
          heightCm = m.heightCm;
          break;
        }
      }
    }
    heightCm ??= profile?.heightCm;
    weightKg ??= profile?.weightKg;
    double? bmi;
    if (weightKg != null && heightCm != null && heightCm > 0) {
      bmi = weightKg / pow(heightCm / 100, 2);
    }

    // ---- History rows (names resolved from the library) ----
    final names = {for (final w in library) w.id: w.name};
    final rows = windowSessions
        .take(recentRows)
        .map((s) => ReportSessionRow(
              date: s.startedAt,
              workoutId: s.workoutId,
              workoutName: names[s.workoutId] ?? s.workoutId,
              minutes: (s.durationSec / 60).round(),
              reps: s.totalReps,
              formPct: s.formAccuracyPct,
            ))
        .toList();

    final base = ProgressReport(
      generatedAt: nowDt,
      name: (profile?.fullName ?? '').trim().isEmpty
          ? 'FixPose Athlete'
          : profile!.fullName.trim(),
      email: profile?.email ?? '—',
      dateOfBirth: profile?.dateOfBirth,
      ageYears: profile == null ? null : _age(profile.dateOfBirth, nowDt),
      genderLabel: profile?.gender.label ?? '—',
      heightCm: heightCm,
      weightKg: weightKg,
      firstWeightKg: firstWeightKg,
      bmi: bmi,
      periodFrom: periodFrom,
      periodTo: nowDt,
      sessionsTotal: sessionsTotal,
      workoutsTotal: workoutsTotal,
      activeDays: activeDays,
      totalMinutes: totalMinutes,
      totalReps: totalReps,
      avgFormPct: avgFormPct,
      currentStrike: strike?.currentStrike ?? 0,
      recentSessions: rows,
      suggestions: '',
      aiPowered: false,
    );

    // ---- Suggestions: GROQ first, rule-based fallback ----
    try {
      final text = await _veda.complete(
        systemPrompt: _aiSystemPrompt,
        turns: [
          ChatMessage(
            id: 'rpt_${nowDt.microsecondsSinceEpoch}',
            role: ChatRole.user,
            text: _aiUserPrompt(base),
            createdAt: nowDt,
          ),
        ],
      );
      return base.copyWith(suggestions: text, aiPowered: true);
    } catch (_) {
      return base.copyWith(suggestions: _fallbackSuggestions(base));
    }
  }

  static int? _age(DateTime dob, DateTime now) {
    var age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age < 0 || age > 120 ? null : age;
  }

  // ---------------------------------------------------------------------
  // AI prompts
  // ---------------------------------------------------------------------

  static const String _aiSystemPrompt = '''
You are FixPose's certified training analyst. You write a concise, professional progress report for one athlete using ONLY the data provided — never invent numbers.

Reply with plain text in exactly this structure (no code fences, no bold markers):
## Overview
1-2 sentences summarizing the athlete's current training state.
## Progress highlights
- 3 to 5 bullets of concrete wins or observations, each citing the given numbers.
## Areas to improve
- 2 to 4 honest, specific gaps (frequency, form, progression, recovery).
## Recommendations
- 4 to 6 actionable suggestions covering training volume, intensity, progression, recovery and nutrition, tailored to the level, history and body metrics given.

Supportive expert-coach tone. Maximum 220 words in total.''';

  String _aiUserPrompt(ProgressReport r) {
    final df = DateFormat('d MMM yyyy');
    final sf = DateFormat('d MMM');
    final buf = StringBuffer()
      ..writeln('Athlete: ${r.name}, '
          '${r.ageYears ?? '—'} ${r.genderLabel}, '
          'height ${r.heightCm?.toStringAsFixed(0) ?? '—'} cm, '
          'weight ${r.weightKg?.toStringAsFixed(1) ?? '—'} kg'
          '${r.bmi != null ? ', BMI ${r.bmi!.toStringAsFixed(1)}' : ''}')
      ..writeln('Report window: ${df.format(r.periodFrom)} to '
          '${df.format(r.periodTo)}');
    if (r.weightKg != null && r.firstWeightKg != null) {
      final delta = r.weightKg! - r.firstWeightKg!;
      buf.writeln('Weight trend: ${r.firstWeightKg!.toStringAsFixed(1)} → '
          '${r.weightKg!.toStringAsFixed(1)} kg '
          '(${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg)');
    }
    buf
      ..writeln('Sessions: ${r.sessionsTotal} across ${r.workoutsTotal} '
          'workouts, ${r.activeDays} active days, '
          'strike ${r.currentStrike} days')
      ..writeln('Volume: ${r.totalMinutes} min total, ${r.totalReps} reps, '
          'average form accuracy ${r.avgFormPct.round()}%');
    if (r.recentSessions.isNotEmpty) {
      buf.writeln('Recent sessions (newest first):');
      for (final s in r.recentSessions) {
        buf.writeln('- ${sf.format(s.date)} — ${s.workoutName}, '
            '${s.minutes} min, ${s.reps} reps, ${s.formPct.round()}% form');
      }
    }
    return buf.toString().trim();
  }

  // ---------------------------------------------------------------------
  // Rule-based fallback (deterministic — same section structure as the AI)
  // ---------------------------------------------------------------------

  String _fallbackSuggestions(ProgressReport r) {
    final weeks = max(1, (r.periodTo.difference(r.periodFrom).inDays / 7).ceil());
    final perWeek = r.sessionsTotal / weeks;
    final b = StringBuffer()
      ..writeln('## Overview')
      ..writeln(
          'You completed ${r.sessionsTotal} session${r.sessionsTotal == 1 ? '' : 's'} '
          'over the last ${r.periodTo.difference(r.periodFrom).inDays} days — '
          '${r.totalMinutes} minutes and ${r.totalReps} reps logged with '
          'average form accuracy of ${r.avgFormPct.round()}.')
      ..writeln()
      ..writeln('## Progress highlights')
      ..writeln('- ${r.activeDays} active day${r.activeDays == 1 ? '' : 's'} '
          'and a current consistency strike of ${r.currentStrike} days.');
    if (r.avgFormPct >= 80) {
      b.writeln('- Strong movement quality — form accuracy is holding at '
          '${r.avgFormPct.round()}%.');
    }
    if (r.weightKg != null && r.firstWeightKg != null) {
      final delta = r.weightKg! - r.firstWeightKg!;
      b.writeln('- Body weight moved from '
          '${r.firstWeightKg!.toStringAsFixed(1)} kg to '
          '${r.weightKg!.toStringAsFixed(1)} kg '
          '(${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg) over the tracked period.');
    }
    b
      ..writeln('- Training touched ${r.workoutsTotal} different workout'
          '${r.workoutsTotal == 1 ? '' : 's'}, keeping stimulus varied.')
      ..writeln()
      ..writeln('## Areas to improve');
    if (perWeek < 3) {
      b.writeln('- Frequency averages ${perWeek.toStringAsFixed(1)} sessions '
          'per week — consistency is your biggest lever right now.');
    } else {
      b.writeln('- Keep sessions at or above your current '
          '${perWeek.toStringAsFixed(1)} per week to build on the base.');
    }
    if (r.avgFormPct < 80) {
      b.writeln('- Form accuracy (${r.avgFormPct.round()}%) is below the 80% '
          'target — slow the tempo and cut range before adding load.');
    } else {
      b.writeln('- Progression: add reps or load once every set clears 85% '
          'form so the numbers keep climbing.');
    }
    b
      ..writeln('- Recovery quality decides how much of this work sticks — '
          'watch sleep and rest-day discipline.')
      ..writeln()
      ..writeln('## Recommendations')
      ..writeln('- Train ${min(5, max(3, perWeek.round()))} times per week '
          'at a steady rhythm rather than clustering sessions.')
      ..writeln('- Progressive overload: add 1-2 reps per set when form '
          'stays above 85%, then advance the variation.');
    if (r.bmi != null) {
      if (r.bmi! >= 25) {
        b.writeln('- Nutrition: a modest calorie deficit with high protein '
            '(${(r.bmi!.toStringAsFixed(1))} BMI) will support recomposition.');
      } else if (r.bmi! < 18.5) {
        b.writeln('- Nutrition: a small calorie surplus with adequate protein '
            'will support training energy (${r.bmi!.toStringAsFixed(1)} BMI).');
      } else {
        b.writeln('- Nutrition: maintain your current intake '
            '(${r.bmi!.toStringAsFixed(1)} BMI) and keep protein steady '
            'around training.');
      }
    }
    b
      ..writeln('- Prioritize 7-9 hours of sleep and at least one full rest '
          'day each week.')
      ..writeln('- Add 10 minutes of mobility work on rest days to protect '
          'the joints your sessions load.');
    return b.toString();
  }
}
