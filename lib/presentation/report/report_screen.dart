import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/di/app_dependencies.dart';
import '../../core/pdf/progress_report_pdf.dart';
import '../../core/report/report_sections.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/progress_report.dart';
import '../shared/app_back_button.dart';
import '../shared/glass_card.dart';
import '../shared/grid_background.dart';
import '../shared/primary_button.dart';

/// Home → Progress report — AI-generated documented report: personal
/// details, training history, body metrics and AI suggestions, with PDF
/// export (FixPose logo + RENIN copyright watermark footer, share sheet).
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  late Future<ProgressReport> _future;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ProgressReport> _load() =>
      ref.read(generateProgressReportProvider)();

  /// Builds the PDF and opens the system share sheet.
  Future<void> _export(ProgressReport report) async {
    setState(() => _exporting = true);
    try {
      final bytes = await buildProgressReportPdf(report);
      final gen = DateFormat('d MMM yyyy, HH:mm').format(report.generatedAt);
      final name =
          'FixPose-Progress-Report-${DateFormat('yyyy-MM-dd').format(report.generatedAt)}.pdf';
      await SharePlus.instance.share(ShareParams(
        title: 'FixPose progress report',
        text: 'FixPose AI progress report — generated $gen',
        files: [
          XFile.fromData(bytes, mimeType: 'application/pdf', name: name),
        ],
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share the PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
                child: Row(
                  children: [
                    const AppBackButton(fallback: '/home'),
                    Expanded(
                      child: Text(
                        'Progress report',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: p.ink,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 46,
                      child: IconButton(
                        tooltip: 'Regenerate',
                        icon: Icon(Icons.refresh, size: 22, color: p.ink2),
                        onPressed: _reload,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<ProgressReport>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return _loading(p);
                    }
                    if (snapshot.hasError) {
                      return _error(p, snapshot.error);
                    }
                    final report = snapshot.data!;
                    return _content(p, report);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loading(AppPalette p) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 14),
            Text(
              'Reading your training history…',
              style: TextStyle(fontSize: 13, color: p.ink2),
            ),
            const SizedBox(height: 4),
            Text(
              'Analyzing with AI…',
              style: TextStyle(fontSize: 11.5, color: p.ink3),
            ),
          ],
        ),
      );

  Widget _error(AppPalette p, Object? error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 34, color: p.ink3),
              const SizedBox(height: 10),
              Text(
                'Could not build the report.\n${error ?? ''}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: p.ink2),
              ),
              const SizedBox(height: 14),
              SecondaryButton(
                label: 'Try again',
                icon: Icons.refresh,
                expand: false,
                onPressed: _reload,
              ),
            ],
          ),
        ),
      );

  Widget _content(AppPalette p, ProgressReport r) {
    final sections = parseReportSections(r.suggestions);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
      children: [
        // ---- Generated stamp (date + time) + AI provenance chip ----
        Row(
          children: [
            Expanded(
              child: Text(
                'Generated ${DateFormat('d MMM yyyy, HH:mm').format(r.generatedAt)}',
                style: TextStyle(fontSize: 11, color: p.ink3),
              ),
            ),
            _chip(
              p,
              label: r.aiPowered ? 'AI analysis' : 'Built-in insights',
              icon: r.aiPowered ? Icons.smart_toy : Icons.insights,
              accent: r.aiPowered,
            ),
          ],
        ),
        if (!r.aiPowered) ...[
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _reload,
              child: Text(
                'AI offline — retry analysis',
                style: TextStyle(fontSize: 11, color: p.accentDeep),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),

        // ---- Personal details ----
        _sectionTitle(p, 'Personal details'),
        const SizedBox(height: 8),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            children: [
              _kvRow(p, 'Full name', r.name, 'Email', r.email),
              _kvRow(
                p,
                'Date of birth',
                r.dateOfBirth == null
                    ? '—'
                    : DateFormat('d MMM yyyy').format(r.dateOfBirth!),
                'Age',
                r.ageYears == null ? '—' : '${r.ageYears} years',
              ),
              _kvRow(
                p,
                'Gender',
                r.genderLabel,
                'Height',
                r.heightCm == null
                    ? '—'
                    : '${r.heightCm!.toStringAsFixed(0)} cm',
              ),
              _kvRow(
                p,
                'Weight (latest)',
                r.weightKg == null
                    ? '—'
                    : '${r.weightKg!.toStringAsFixed(1)} kg',
                'BMI',
                r.bmi == null
                    ? '—'
                    : '${r.bmi!.toStringAsFixed(1)} (${_bmiLabel(r.bmi!)})',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // ---- Training summary ----
        _sectionTitle(p, 'Training summary'),
        const SizedBox(height: 8),
        GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${DateFormat('d MMM yyyy').format(r.periodFrom)} – '
                '${DateFormat('d MMM yyyy').format(r.periodTo)}',
                style: TextStyle(fontSize: 11, color: p.ink3),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, c) {
                  final w = (c.maxWidth - 10) / 2;
                  final tiles = <(String, String)>[
                    ('${r.sessionsTotal}', 'Sessions'),
                    ('${r.workoutsTotal}', 'Workouts'),
                    ('${r.activeDays}', 'Active days'),
                    ('${r.currentStrike} d', 'Strike'),
                    (_prettyMinutes(r.totalMinutes), 'Total time'),
                    ('${r.totalReps}', 'Reps'),
                    ('${r.avgFormPct.round()}%', 'Avg form'),
                    ('${_daysBetween(r.periodFrom, r.periodTo)} d', 'Window'),
                  ];
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final t in tiles)
                        SizedBox(
                          width: w,
                          child: _tile(p, t.$1, t.$2),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // ---- Body metrics ----
        _sectionTitle(p, 'Body metrics'),
        const SizedBox(height: 8),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: _bodyMetrics(p, r),
        ),
        const SizedBox(height: 18),

        // ---- Nutrition summary (meal page; hidden until meals exist) ----
        if (r.mealsLogged > 0) ...[
          _sectionTitle(p, 'Nutrition summary'),
          const SizedBox(height: 8),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meals logged between '
                  '${DateFormat('d MMM yyyy').format(r.periodFrom)} – '
                  '${DateFormat('d MMM yyyy').format(r.periodTo)}',
                  style: TextStyle(fontSize: 11, color: p.ink3),
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, c) {
                    final w = (c.maxWidth - 10) / 2;
                    final tiles = <(String, String)>[
                      ('${r.mealsLogged}', 'Meals'),
                      ('${r.avgKcalPerDay}', 'Avg kcal/day'),
                      ('${r.daysWithMeals}', 'Logged days'),
                      (
                        r.calorieTarget == null ? '—' : '${r.calorieTarget}',
                        'Daily target',
                      ),
                    ];
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final t in tiles)
                          SizedBox(
                            width: w,
                            child: _tile(p, t.$1, t.$2),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],

        // ---- Recent sessions ----
        _sectionTitle(p, 'Recent sessions'),
        const SizedBox(height: 8),
        GlassCard(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: r.recentSessions.isEmpty ? 14 : 4,
          ),
          child: r.recentSessions.isEmpty
              ? Text(
                  'No completed sessions in this window yet.',
                  style: TextStyle(fontSize: 12.5, color: p.ink2),
                )
              : Column(
                  children: [
                    for (var i = 0; i < r.recentSessions.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, thickness: 0.7, color: p.border),
                      _sessionRow(p, r.recentSessions[i]),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 18),

        // ---- Analysis & recommendations (AI) ----
        _sectionTitle(p, 'Analysis & recommendations'),
        const SizedBox(height: 8),
        GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!r.aiPowered) ...[
                Text(
                  'AI was unreachable — showing built-in insights.',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: p.ink3,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              for (final section in sections) ...[
                if (section.heading.isNotEmpty) ...[
                  if (section != sections.first)
                    const SizedBox(height: 10),
                  Text(
                    section.heading,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: p.accentDeep,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                for (final block in section.blocks)
                  if (block.type == ReportBlockType.bullet)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 16,
                            child: Text(
                              '•',
                              style: TextStyle(
                                fontSize: 13,
                                color: p.accentDeep,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              block.text,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.4,
                                color: p.ink2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        block.text,
                        style:
                            TextStyle(fontSize: 12.5, height: 1.45, color: p.ink2),
                      ),
                    ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),

        // ---- Export ----
        PrimaryButton(
          label: 'Export PDF',
          icon: Icons.picture_as_pdf,
          loading: _exporting,
          onPressed: _exporting ? null : () => _export(r),
        ),
        const SizedBox(height: 6),
        Text(
          'Includes logo, personal details and the RENIN copyright footer.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10.5, color: p.ink3),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------
  // Pieces
  // -------------------------------------------------------------------

  Widget _chip(
    AppPalette p, {
    required String label,
    required IconData icon,
    required bool accent,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: accent ? p.accentSoft : p.glass,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: p.border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: accent ? p.accentDeep : p.ink3),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: accent ? p.accentDeep : p.ink2,
              ),
            ),
          ],
        ),
      );

  Widget _sectionTitle(AppPalette p, String title) => Row(
        children: [
          Container(width: 3, height: 14, color: p.accentDeep),
          const SizedBox(width: 7),
          // Expanded: the title can never overflow the row (wraps instead),
          // regardless of font/scale — keeps the yellow/black stripes away.
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: p.ink,
              ),
            ),
          ),
        ],
      );

  Widget _kv(AppPalette p, String label, String value) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10.5, color: p.ink3)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: p.ink,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _kvRow(
    AppPalette p,
    String labelA,
    String valueA,
    String labelB,
    String valueB,
  ) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_kv(p, labelA, valueA), _kv(p, labelB, valueB)],
      );

  Widget _tile(AppPalette p, String value, String label) => Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        decoration: BoxDecoration(
          color: p.glass,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.border, width: 1),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: p.ink,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: p.ink3),
            ),
          ],
        ),
      );

  Widget _bodyMetrics(AppPalette p, ProgressReport r) {
    if (r.weightKg == null &&
        r.heightCm == null &&
        r.firstWeightKg == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No body metrics recorded yet.',
          style: TextStyle(fontSize: 12.5, color: p.ink2),
        ),
      );
    }
    final trend = (r.weightKg != null && r.firstWeightKg != null)
        ? (() {
            final delta = r.weightKg! - r.firstWeightKg!;
            return '${r.firstWeightKg!.toStringAsFixed(1)} → '
                '${r.weightKg!.toStringAsFixed(1)} kg '
                '(${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)})';
          })()
        : '—';
    return Column(
      children: [
        _kvRow(
          p,
          'Height',
          r.heightCm == null
              ? '—'
              : '${r.heightCm!.toStringAsFixed(0)} cm',
          'Latest weight',
          r.weightKg == null
              ? '—'
              : '${r.weightKg!.toStringAsFixed(1)} kg',
        ),
        _kvRow(p, 'Weight trend', trend, 'BMI',
            r.bmi == null ? '—' : r.bmi!.toStringAsFixed(1)),
      ],
    );
  }

  Widget _sessionRow(AppPalette p, ReportSessionRow s) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                DateFormat('d MMM').format(s.date),
                style: TextStyle(fontSize: 11, color: p.ink3),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.workoutName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: p.ink,
                    ),
                  ),
                  Text(
                    '${s.minutes} min · ${s.reps} reps',
                    style: TextStyle(fontSize: 10.5, color: p.ink3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${s.formPct.round()}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: p.accentDeep,
              ),
            ),
          ],
        ),
      );

  // -------------------------------------------------------------------
  // Formatters
  // -------------------------------------------------------------------

  static String _prettyMinutes(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  static int _daysBetween(DateTime from, DateTime to) {
    final a = DateTime(from.year, from.month, from.day);
    final b = DateTime(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  static String _bmiLabel(double bmi) {
    if (bmi < 18.5) return 'underweight';
    if (bmi < 25) return 'normal range';
    if (bmi < 30) return 'overweight';
    return 'obese';
  }
}
