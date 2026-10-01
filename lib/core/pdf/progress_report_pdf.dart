import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/entities/progress_report.dart';
import '../report/report_sections.dart';

// ---------------------------------------------------------------------------
// Brand palette (print-safe renderings of the on-screen theme).
// ---------------------------------------------------------------------------

final PdfColor _ink = PdfColor.fromInt(0xFF1A2110); // primary text
final PdfColor _ink2 = PdfColor.fromInt(0xFF5A6455); // secondary text
final PdfColor _ink3 = PdfColor.fromInt(0xFF8A9382); // captions / labels
final PdfColor _line = PdfColor.fromInt(0xFFE4E9DC); // hairlines
final PdfColor _tileBg = PdfColor.fromInt(0xFFF3F6EF); // stat tile fill
final PdfColor _accent = PdfColor.fromInt(0xFF7CC414); // accentMid
final PdfColor _accentDeep = PdfColor.fromInt(0xFF4E7A12); // readable on white
final PdfColor _logoTop = PdfColor.fromInt(0xFFD9FF57); // accentBright
final PdfColor _logoInk = PdfColor.fromInt(0xFF1C2A06); // accentInk
final PdfColor _watermark = PdfColor.fromInt(0xFFBDC6B3); // footer RENIN

/// Helvetica (WinAnsi) cannot draw typographic glyphs the model or the app
/// uses — the pdf package prints "Unable to find a font to draw …" and drops
/// them. Map common ones to safe ASCII (bullets are drawn as vector dots).
String _s(String t) => t
    .replaceAll('–', '-')
    .replaceAll('—', '-')
    .replaceAll('•', '-')
    .replaceAll('→', '->')
    .replaceAll('‘', "'")
    .replaceAll('’', "'")
    .replaceAll('“', '"')
    .replaceAll('”', '"')
    .replaceAll('…', '...')
    .replaceAll(RegExp('[^\u0000-\u00FF]'), '?');

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Builds the exportable progress-report PDF: FixPose logo + title, generation
/// date **and time**, personal details, training history, body metrics and the
/// AI suggestions. Every page carries the RENIN copyright watermark footer.
///
/// [compress] = false writes plain content streams (tests assert on text).
Future<Uint8List> buildProgressReportPdf(
  ProgressReport report, {
  bool compress = true,
}) async {
  final doc = pw.Document(compress: compress);
  final df = DateFormat('d MMM yyyy');
  final dtf = DateFormat('d MMM yyyy, HH:mm');
  final sf = DateFormat('d MMM');

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(42, 40, 42, 66),
      build: (context) => [
        // ---- Header: logo + titles + generated date/time ----
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            _logoTile(),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'FixPose',
                    style: pw.TextStyle(
                      fontSize: 21,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink,
                    ),
                  ),
                  pw.Text(
                    'AI Progress Report',
                    style: pw.TextStyle(fontSize: 11, color: _ink2),
                  ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Generated',
                  style: pw.TextStyle(fontSize: 8, color: _ink3),
                ),
                pw.Text(
                  // Date + time of generation (user requirement).
                  _s(dtf.format(report.generatedAt)),
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: _line, thickness: 0.8, height: 1),
        pw.SizedBox(height: 14),

        // ---- Personal details ----
        _sectionTitle('Personal details'),
        pw.SizedBox(height: 8),
        _kvRow('Full name', report.name, 'Email', report.email),
        _kvRow(
          'Date of birth',
          report.dateOfBirth == null ? '—' : df.format(report.dateOfBirth!),
          'Age',
          report.ageYears == null ? '—' : '${report.ageYears} years',
        ),
        _kvRow(
          'Gender',
          report.genderLabel,
          'Height',
          report.heightCm == null
              ? '—'
              : '${report.heightCm!.toStringAsFixed(0)} cm',
        ),
        _kvRow(
          'Weight (latest)',
          report.weightKg == null
              ? '—'
              : '${report.weightKg!.toStringAsFixed(1)} kg',
          'BMI',
          report.bmi == null
              ? '—'
              : '${report.bmi!.toStringAsFixed(1)} (${_bmiLabel(report.bmi!)})',
        ),
        pw.SizedBox(height: 16),

        // ---- Training summary ----
        _sectionTitle('Training summary'),
        pw.SizedBox(height: 4),
        pw.Text(
          _s('${df.format(report.periodFrom)} – ${df.format(report.periodTo)}'),
          style: pw.TextStyle(fontSize: 9, color: _ink3),
        ),
        pw.SizedBox(height: 8),
        _tileRow([
          ('${report.sessionsTotal}', 'Sessions'),
          ('${report.workoutsTotal}', 'Workouts'),
          ('${report.activeDays}', 'Active days'),
          ('${report.currentStrike} d', 'Strike'),
        ]),
        pw.SizedBox(height: 8),
        _tileRow([
          (_prettyMinutes(report.totalMinutes), 'Total time'),
          ('${report.totalReps}', 'Reps'),
          ('${report.avgFormPct.round()}%', 'Avg form'),
          (
            '${_daysBetween(report.periodFrom, report.periodTo)} d',
            'Window',
          ),
        ]),
        pw.SizedBox(height: 16),

        // ---- Body metrics ----
        _sectionTitle('Body metrics'),
        pw.SizedBox(height: 8),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: _tileBg,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Text(
            _bodyMetricsLine(report),
            style: pw.TextStyle(fontSize: 10, color: _ink2, height: 1.4),
          ),
        ),
        pw.SizedBox(height: 16),

        // ---- Nutrition summary (only when meals were logged) ----
        if (report.mealsLogged > 0) ...[
          _sectionTitle('Nutrition summary'),
          pw.SizedBox(height: 8),
          _tileRow([
            ('${report.mealsLogged}', 'Meals logged'),
            ('${report.avgKcalPerDay}', 'Avg kcal/day'),
            ('${report.daysWithMeals}', 'Logged days'),
            if (report.calorieTarget != null)
              ('${report.calorieTarget}', 'Daily target')
            else
              ('-', 'Daily target'),
          ]),
          pw.SizedBox(height: 16),
        ],

        // ---- Recent sessions ----
        _sectionTitle('Recent sessions'),
        pw.SizedBox(height: 8),
        if (report.recentSessions.isEmpty)
          pw.Text(
            _s('No completed sessions in this window yet - start your plan '
                'to fill this table.'),
            style: pw.TextStyle(fontSize: 10, color: _ink2),
          )
        else ...[
          _historyHeader(),
          for (final s in report.recentSessions)
            _historyRow(sf, s.date, s.workoutName, s.minutes, s.reps,
                s.formPct),
        ],
        pw.SizedBox(height: 16),

        // ---- AI analysis & recommendations ----
        _sectionTitle('Analysis & recommendations'),
        pw.SizedBox(height: 8),
        if (!report.aiPowered)
          pw.Text(
            _s('AI was unavailable at generation time - built-in insights '
                'shown.'),
            style: pw.TextStyle(
              fontSize: 8.5,
              fontStyle: pw.FontStyle.italic,
              color: _ink3,
            ),
          ),
        if (!report.aiPowered) pw.SizedBox(height: 6),
        ..._aiBlocks(report.suggestions),
        pw.SizedBox(height: 10),
        pw.Text(
          _s('This report is generated from your FixPose activity and body '
              'metrics and is intended for training guidance only - not '
              'medical advice.'),
          style: pw.TextStyle(fontSize: 7.5, color: _ink3),
        ),
      ],
      // ---- Footer: RENIN watermark + copyright + page numbers ----
      footer: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: _line, width: 0.8)),
        ),
        child: pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'FixPose · AI Progress Report',
                  style: pw.TextStyle(fontSize: 8, color: _ink3),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(fontSize: 8, color: _ink3),
                ),
              ],
            ),
            pw.SizedBox(height: 3),
            pw.Center(
              child: pw.Text(
                'RENIN',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 6,
                  color: _watermark, // watermark styling
                ),
              ),
            ),
            pw.Center(
              child: pw.Text(
                '© ${report.generatedAt.year} RENIN. All rights reserved.',
                style: pw.TextStyle(fontSize: 6.5, color: _ink3),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return doc.save();
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

/// FixPose logo tile — chartreuse gradient rounded square + the accessibility
/// person glyph drawn as vector strokes (mirror of `AppLogo` on screen).
pw.Widget _logoTile({double size = 46}) {
  return pw.Container(
    width: size,
    height: size,
    decoration: pw.BoxDecoration(
      borderRadius: pw.BorderRadius.circular(size * 0.3),
      gradient: pw.LinearGradient(
        begin: pw.Alignment.topLeft,
        end: pw.Alignment.bottomRight,
        colors: [_logoTop, _accent],
      ),
    ),
    child: pw.CustomPaint(
      size: PdfPoint(size, size),
      painter: (canvas, sz) => _paintPersonGlyph(canvas, sz),
    ),
  );
}

void _paintPersonGlyph(PdfGraphics canvas, PdfPoint size) {
  final u = size.x / 46; // design grid is 46x46
  // y is flipped: PDF origin is bottom-left, design is top-left.
  double y(double top) => (46 - top) * u;

  canvas.setFillColor(_logoInk);
  _circlePath(canvas, 23 * u, y(12), 4.7 * u);
  canvas.fillPath();

  canvas
    ..setStrokeColor(_logoInk)
    ..setLineWidth(3.4 * u)
    ..setLineCap(PdfLineCap.round);
  // arms
  canvas
    ..moveTo(10.5 * u, y(21))
    ..lineTo(35.5 * u, y(21));
  // torso
  canvas
    ..moveTo(23 * u, y(16.7))
    ..lineTo(23 * u, y(29.5));
  // legs
  canvas
    ..moveTo(23 * u, y(29.5))
    ..lineTo(15.3 * u, y(40.5))
    ..moveTo(23 * u, y(29.5))
    ..lineTo(30.7 * u, y(40.5));
  canvas.strokePath();
}

void _circlePath(PdfGraphics c, double cx, double cy, double r) {
  final k = 0.5523 * r;
  c
    ..moveTo(cx + r, cy)
    ..curveTo(cx + r, cy + k, cx + k, cy + r, cx, cy + r)
    ..curveTo(cx - k, cy + r, cx - r, cy + k, cx - r, cy)
    ..curveTo(cx - r, cy - k, cx - k, cy - r, cx, cy - r)
    ..curveTo(cx + k, cy - r, cx + r, cy - k, cx + r, cy);
}

pw.Widget _sectionTitle(String text) => pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(width: 3, height: 14, color: _accent),
        pw.SizedBox(width: 7),
        pw.Text(
          _s(text),
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
      ],
    );

pw.Widget _kv(String label, String value) => pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(_s(label), style: pw.TextStyle(fontSize: 8, color: _ink3)),
            pw.SizedBox(height: 2),
            pw.Text(
              _s(value),
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _ink,
              ),
            ),
          ],
        ),
      ),
    );

pw.Widget _kvRow(
  String labelA,
  String valueA,
  String labelB,
  String valueB,
) =>
    pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.6)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [_kv(labelA, valueA), _kv(labelB, valueB)],
      ),
    );

pw.Widget _tileRow(List<(String, String)> items) => pw.Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) pw.SizedBox(width: 8),
          pw.Expanded(child: _tile(items[i].$1, items[i].$2)),
        ],
      ],
    );

pw.Widget _tile(String value, String label) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: pw.BoxDecoration(
        color: _tileBg,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            _s(value),
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 13.5,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
          pw.SizedBox(height: 1),
          pw.Text(
            _s(label),
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 8, color: _ink3),
          ),
        ],
      ),
    );

const List<double> _historyWeights = [0.9, 2.6, 0.7, 0.7, 0.9];

pw.Widget _historyCell(String text, {required bool header, int col = 0}) =>
    pw.Expanded(
      flex: (100 * _historyWeights[col]).round(),
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
        child: pw.Text(
          text,
          maxLines: 1,
          overflow: pw.TextOverflow.clip,
          style: header
              ? pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink2,
                )
              : pw.TextStyle(fontSize: 9.5, color: _ink),
        ),
      ),
    );

pw.Widget _historyHeader() => pw.Container(
      color: _tileBg,
      child: pw.Row(
        children: [
          _historyCell('Date', header: true, col: 0),
          _historyCell('Workout', header: true, col: 1),
          _historyCell('Min', header: true, col: 2),
          _historyCell('Reps', header: true, col: 3),
          _historyCell('Form', header: true, col: 4),
        ],
      ),
    );

pw.Widget _historyRow(
  DateFormat df,
  DateTime date,
  String workout,
  int minutes,
  int reps,
  double formPct,
) =>
    pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.5)),
      ),
      child: pw.Row(
        children: [
          _historyCell(df.format(date), header: false, col: 0),
          _historyCell(workout, header: false, col: 1),
          _historyCell('$minutes', header: false, col: 2),
          _historyCell('$reps', header: false, col: 3),
          _historyCell('${formPct.round()}%', header: false, col: 4),
        ],
      ),
    );

// ---------------------------------------------------------------------------
// AI text blocks
// ---------------------------------------------------------------------------

List<pw.Widget> _aiBlocks(String raw) {
  final out = <pw.Widget>[];
  for (final section in parseReportSections(raw)) {
    if (section.heading.isNotEmpty) {
      out.add(pw.SizedBox(height: 6));
      out.add(
        pw.Text(
          _s(section.heading),
          style: pw.TextStyle(
            fontSize: 11.5,
            fontWeight: pw.FontWeight.bold,
            color: _accentDeep,
          ),
        ),
      );
      out.add(pw.SizedBox(height: 3));
    }
    for (final block in section.blocks) {
      if (block.type == ReportBlockType.bullet) {
        out.add(
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 12,
                child: pw.Padding(
                  // Vector dot — Helvetica cannot draw the • glyph.
                  padding: const pw.EdgeInsets.only(top: 4),
                  child: pw.Container(
                    width: 4,
                    height: 4,
                    decoration: pw.BoxDecoration(
                      color: _accentDeep,
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  _s(block.text),
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: _ink2,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        );
        out.add(pw.SizedBox(height: 2));
      } else {
        out.add(
          pw.Text(
            _s(block.text),
            style: pw.TextStyle(fontSize: 10, color: _ink2, height: 1.4),
          ),
        );
        out.add(pw.SizedBox(height: 4));
      }
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Formatters
// ---------------------------------------------------------------------------

String _prettyMinutes(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

int _daysBetween(DateTime from, DateTime to) {
  final a = DateTime(from.year, from.month, from.day);
  final b = DateTime(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

String _bmiLabel(double bmi) {
  if (bmi < 18.5) return 'underweight';
  if (bmi < 25) return 'normal range';
  if (bmi < 30) return 'overweight';
  return 'obese';
}

String _bodyMetricsLine(ProgressReport r) {
  final parts = <String>[];
  if (r.heightCm != null) {
    parts.add('Height ${r.heightCm!.toStringAsFixed(0)} cm');
  }
  if (r.weightKg != null) {
    parts.add('latest weight ${r.weightKg!.toStringAsFixed(1)} kg');
  }
  if (r.firstWeightKg != null && r.weightKg != null) {
    final delta = r.weightKg! - r.firstWeightKg!;
    parts.add('since first entry '
        '${r.firstWeightKg!.toStringAsFixed(1)} kg '
        '(${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg)');
  }
  if (r.bmi != null) {
    parts.add('BMI ${r.bmi!.toStringAsFixed(1)} — ${_bmiLabel(r.bmi!)}');
  }
  if (parts.isEmpty) return 'No body metrics recorded yet.';
  return _s('${parts.join(', ')}.');
}
