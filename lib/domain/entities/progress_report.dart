/// AI-generated progress report (Home → Progress report).
///
/// A documented, exportable summary of the athlete's personal details,
/// training history and body metrics plus AI (GROQ) analysis and
/// suggestions — the source for both the on-screen report page and the
/// PDF export (logo + personal details + RENIN copyright footer).
library;

/// One completed session row in the report's training-history table.
class ReportSessionRow {
  const ReportSessionRow({
    required this.date,
    required this.workoutId,
    required this.workoutName,
    required this.minutes,
    required this.reps,
    required this.formPct,
  });

  final DateTime date;
  final String workoutId;
  final String workoutName;
  final int minutes;
  final int reps;
  final double formPct;
}

class ProgressReport {
  const ProgressReport({
    required this.generatedAt,
    required this.name,
    required this.email,
    required this.dateOfBirth,
    required this.ageYears,
    required this.genderLabel,
    required this.heightCm,
    required this.weightKg,
    required this.firstWeightKg,
    required this.bmi,
    required this.periodFrom,
    required this.periodTo,
    required this.sessionsTotal,
    required this.workoutsTotal,
    required this.activeDays,
    required this.totalMinutes,
    required this.totalReps,
    required this.avgFormPct,
    required this.currentStrike,
    required this.recentSessions,
    this.mealsLogged = 0,
    this.avgKcalPerDay = 0,
    this.daysWithMeals = 0,
    this.calorieTarget,
    required this.suggestions,
    required this.aiPowered,
  });

  /// When the report was assembled — stamped on screen and PDF (date + time).
  final DateTime generatedAt;

  // ---- Personal details ----
  final String name;
  final String email;
  final DateTime? dateOfBirth;
  final int? ageYears;
  final String genderLabel;
  final double? heightCm;

  /// Latest tracked weight (profile/metrics), null when never recorded.
  final double? weightKg;

  /// Earliest tracked weight — trend = [weightKg] − [firstWeightKg].
  final double? firstWeightKg;

  final double? bmi;

  // ---- Training history (report window) ----
  final DateTime periodFrom;
  final DateTime periodTo;
  final int sessionsTotal;
  final int workoutsTotal;

  /// Distinct calendar days with at least one session in the window.
  final int activeDays;
  final int totalMinutes;
  final int totalReps;
  final double avgFormPct;
  final int currentStrike;

  /// Newest first, capped by the usecase (10).
  final List<ReportSessionRow> recentSessions;

  // ---- Nutrition (report window, meal page) ----
  /// Meals logged in the window (0 → the nutrition section stays hidden).
  final int mealsLogged;

  /// Window-averaged kcal/day across all window days.
  final int avgKcalPerDay;

  /// Distinct calendar days with at least one logged meal.
  final int daysWithMeals;

  /// Daily calorie target from the meal page (null → never set).
  final int? calorieTarget;

  // ---- AI analysis ----
  /// Markdown-ish text (## headings, '-' bullets) from GROQ, or the built-in
  /// rule-based version when the model was unreachable.
  final String suggestions;

  /// True when GROQ produced [suggestions]; false → built-in fallback.
  final bool aiPowered;

  ProgressReport copyWith({String? suggestions, bool? aiPowered}) =>
      ProgressReport(
        generatedAt: generatedAt,
        name: name,
        email: email,
        dateOfBirth: dateOfBirth,
        ageYears: ageYears,
        genderLabel: genderLabel,
        heightCm: heightCm,
        weightKg: weightKg,
        firstWeightKg: firstWeightKg,
        bmi: bmi,
        periodFrom: periodFrom,
        periodTo: periodTo,
        sessionsTotal: sessionsTotal,
        workoutsTotal: workoutsTotal,
        activeDays: activeDays,
        totalMinutes: totalMinutes,
        totalReps: totalReps,
        avgFormPct: avgFormPct,
        currentStrike: currentStrike,
        recentSessions: recentSessions,
        mealsLogged: mealsLogged,
        avgKcalPerDay: avgKcalPerDay,
        daysWithMeals: daysWithMeals,
        calorieTarget: calorieTarget,
        suggestions: suggestions ?? this.suggestions,
        aiPowered: aiPowered ?? this.aiPowered,
      );
}
