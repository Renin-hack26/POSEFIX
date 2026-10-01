/// Tiny markdown-ish parser for AI report text.
///
/// GROQ is asked for `## headings` + `- bullets` + plain paragraphs; this
/// turns that into structured sections so the report screen and the PDF
/// export render the same document identically. Also strips `**bold**`
/// markers some models add anyway.
library;

enum ReportBlockType { paragraph, bullet }

class ReportBlock {
  const ReportBlock(this.type, this.text);

  final ReportBlockType type;
  final String text;
}

class ReportSection {
  const ReportSection(this.heading, this.blocks);

  /// Empty string when the input starts with body blocks (no heading).
  final String heading;
  final List<ReportBlock> blocks;

  bool get isEmpty => heading.isEmpty && blocks.isEmpty;
}

/// Parses [raw] into sections. Tolerant: unknown lines become paragraphs,
/// `#`/`##`/`###` all start a section, list markers `-`, `*`, `•` are bullets.
List<ReportSection> parseReportSections(String raw) {
  final sections = <ReportSection>[];
  var heading = '';
  var blocks = <ReportBlock>[];

  void flush() {
    if (heading.isNotEmpty || blocks.isNotEmpty) {
      sections.add(ReportSection(heading, List.unmodifiable(blocks)));
    }
    heading = '';
    blocks = <ReportBlock>[];
  }

  for (final rawLine in raw.split('\n')) {
    final line = rawLine.trimRight().replaceAll('**', '');
    if (line.trim().isEmpty) continue;

    final trimmed = line.trimLeft();
    if (trimmed.startsWith('#')) {
      // Heading: '# ' … '### ' (models drift between levels).
      flush();
      heading = trimmed.replaceFirst(RegExp(r'^#+\s*'), '').trim();
      continue;
    }
    if (trimmed.startsWith(RegExp(r'[-*•]\s'))) {
      blocks.add(ReportBlock(
        ReportBlockType.bullet,
        trimmed.replaceFirst(RegExp(r'^[-*•]\s+'), '').trim(),
      ));
      continue;
    }
    blocks.add(ReportBlock(ReportBlockType.paragraph, trimmed));
  }
  flush();
  return sections;
}
