import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Generates ultra-premium branded PDF executive reports from meeting data.
///
/// Layout:
///   1. Hero header with gradient bar + branding
///   2. Executive summary card (highlighted box)
///   3. Meeting stats row (duration, segments, insights count)
///   4. Key Points — colored accent cards
///   5. Decisions — icon + styled list
///   6. Action Items — checklist with status colors
///   7. Follow-ups — timeline-style cards
///   8. AI Insights — importance-coded cards
///   9. Transcript appendix — compact, secondary
///   10. Branded footer on every page
class MeetingPdfService {
  MeetingPdfService._();
  static final instance = MeetingPdfService._();

  // ─── Brand Colors ───
  static const _purple = PdfColor.fromInt(0xFF8B5CF6);
  static const _purpleLight = PdfColor.fromInt(0xFFF3F0FF);
  static const _green = PdfColor.fromInt(0xFF06D6A0);
  static const _greenLight = PdfColor.fromInt(0xFFF0FDF4);
  static const _orange = PdfColor.fromInt(0xFFF97316);
  static const _orangeLight = PdfColor.fromInt(0xFFFFF7ED);
  static const _yellow = PdfColor.fromInt(0xFFEAB308);
  static const _yellowLight = PdfColor.fromInt(0xFFFFFBEB);
  static const _red = PdfColor.fromInt(0xFFEF4444);
  static const _blue = PdfColor.fromInt(0xFF3B82F6);
  static const _blueLight = PdfColor.fromInt(0xFFEFF6FF);
  static const _grey50 = PdfColor.fromInt(0xFFF9FAFB);
  static const _grey100 = PdfColor.fromInt(0xFFF3F4F6);
  static const _grey200 = PdfColor.fromInt(0xFFE5E7EB);
  static const _grey500 = PdfColor.fromInt(0xFF6B7280);
  static const _grey700 = PdfColor.fromInt(0xFF374151);
  static const _grey900 = PdfColor.fromInt(0xFF111827);

  /// Generate a premium PDF report from meeting data.
  Future<Uint8List> generatePdf(
    Map<String, dynamic> meeting, {
    bool fullExport = true,
  }) async {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: await PdfGoogleFonts.interRegular(),
        bold: await PdfGoogleFonts.interBold(),
        boldItalic: await PdfGoogleFonts.interBold(),
        italic: await PdfGoogleFonts.interMedium(),
      ),
    );

    final title = meeting['title'] as String? ?? 'Untitled Meeting';
    final durationSecs = meeting['duration_secs'] as int? ?? 0;
    final startedAt = meeting['started_at'] as String?;
    final segments = meeting['segments'] as List<dynamic>? ?? [];
    final insights = meeting['insights'] as List<dynamic>? ?? [];
    final summary = meeting['summary'] as Map<String, dynamic>?;
    final actionItems = meeting['action_items'] as List<dynamic>? ?? [];

    String dateStr = '';
    if (startedAt != null) {
      try {
        final dt = DateTime.parse(startedAt).toLocal();
        dateStr = DateFormat('MMMM d, yyyy  ·  h:mm a').format(dt);
      } catch (_) {
        dateStr = startedAt;
      }
    }

    final durationMin = durationSecs ~/ 60;
    final durationSec = durationSecs % 60;
    final durationStr =
        durationSecs > 0 ? '${durationMin}m ${durationSec}s' : '< 1m';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        header: (_) => _buildHeader(),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // ── Hero Title ──
          _buildHeroTitle(title, dateStr),
          pw.SizedBox(height: 16),

          // ── Stats Row ──
          _buildStatsRow(durationStr, segments.length, insights.length,
              actionItems.length),
          pw.SizedBox(height: 20),

          // ── Executive Summary ──
          if (summary != null) ...[
            _buildExecutiveSummary(summary),
            pw.SizedBox(height: 20),
          ],

          // ── Key Points ──
          if (summary != null)
            ..._buildKeyPointsSection(_extractList(summary['key_points'])),

          // ── Decisions ──
          if (summary != null)
            ..._buildDecisionsSection(_extractList(summary['decisions'])),

          // ── Action Items ──
          if (actionItems.isNotEmpty) ...[
            ..._buildActionItemsSection(actionItems),
            pw.SizedBox(height: 16),
          ],

          // ── Follow-ups ──
          if (summary != null)
            ..._buildFollowUpsSection(_extractList(summary['follow_ups'])),

          // ── Pro gate ──
          if (!fullExport) ...[
            pw.SizedBox(height: 20),
            _buildProGate(),
          ],

          // ── AI Insights ──
          if (fullExport && insights.isNotEmpty) ...[
            ..._buildInsightsSection(insights),
            pw.SizedBox(height: 16),
          ],

          // ── Transcript Appendix ──
          if (fullExport && segments.isNotEmpty)
            ..._buildTranscriptAppendix(segments),
        ],
      ),
    );

    return pdf.save();
  }

  /// Share the generated PDF via native share sheet.
  Future<void> sharePdf(
    Map<String, dynamic> meeting, {
    bool fullExport = true,
  }) async {
    final bytes = await generatePdf(meeting, fullExport: fullExport);
    final title = meeting['title'] as String? ?? 'Meeting';
    final safeName = title
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();

    await Printing.sharePdf(
      bytes: bytes,
      filename: 'aurameet_$safeName.pdf',
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  HEADER & FOOTER
  // ═══════════════════════════════════════════════════════════════════

  pw.Widget _buildHeader() {
    return pw.Column(
      children: [
        // Gradient bar
        pw.Container(
          height: 5,
          decoration: const pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [_purple, _green, _blue],
            ),
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'AURA MEET',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _purple,
                letterSpacing: 3,
              ),
            ),
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: pw.BoxDecoration(
                color: _purpleLight,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Text(
                'AI Executive Report',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: _purple,
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
      ],
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Column(
      children: [
        pw.Divider(color: _grey200, thickness: 0.5),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: 'Generated by ',
                    style: pw.TextStyle(fontSize: 7, color: _grey500),
                  ),
                  pw.TextSpan(
                    text: 'Aura Meet',
                    style: pw.TextStyle(
                        fontSize: 7,
                        color: _purple,
                        fontWeight: pw.FontWeight.bold),
                  ),
                  pw.TextSpan(
                    text: '  ·  aurameet.live',
                    style: pw.TextStyle(fontSize: 7, color: _grey500),
                  ),
                ],
              ),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 7, color: _grey500),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  HERO TITLE
  // ═══════════════════════════════════════════════════════════════════

  pw.Widget _buildHeroTitle(String title, String dateStr) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 26,
            fontWeight: pw.FontWeight.bold,
            color: _grey900,
            lineSpacing: 4,
          ),
        ),
        if (dateStr.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Text(
            dateStr,
            style: pw.TextStyle(fontSize: 10, color: _grey500),
          ),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  STATS ROW
  // ═══════════════════════════════════════════════════════════════════

  pw.Widget _buildStatsRow(
    String duration,
    int segmentCount,
    int insightCount,
    int actionCount,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: pw.BoxDecoration(
        color: _grey50,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: _grey200, width: 0.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _statItem('Duration', duration, _purple),
          _statDivider(),
          _statItem('Segments', '$segmentCount', _green),
          _statDivider(),
          _statItem('Insights', '$insightCount', _orange),
          _statDivider(),
          _statItem('Actions', '$actionCount', _blue),
        ],
      ),
    );
  }

  pw.Widget _statItem(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 8, color: _grey500),
        ),
      ],
    );
  }

  pw.Widget _statDivider() {
    return pw.Container(width: 1, height: 28, color: _grey200);
  }

  // ═══════════════════════════════════════════════════════════════════
  //  EXECUTIVE SUMMARY
  // ═══════════════════════════════════════════════════════════════════

  pw.Widget _buildExecutiveSummary(Map<String, dynamic> summary) {
    final overview = summary['overview'] as String? ?? '';
    if (overview.isEmpty) return pw.SizedBox();

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [_purpleLight, PdfColor.fromInt(0xFFF5F3FF)],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: _purple, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 4,
                height: 16,
                decoration: pw.BoxDecoration(
                  color: _purple,
                  borderRadius: pw.BorderRadius.circular(2),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                'Executive Summary',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: _purple,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            overview,
            style: pw.TextStyle(
              fontSize: 10,
              color: _grey700,
              lineSpacing: 5,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  KEY POINTS
  // ═══════════════════════════════════════════════════════════════════

  List<pw.Widget> _buildKeyPointsSection(List<String> items) {
    if (items.isEmpty) return [];
    return [
      _sectionHeader('Key Points', _green),
      pw.SizedBox(height: 8),
      pw.Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items
            .map((item) => pw.Container(
                  width: 248,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: _greenLight,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border(
                      left: pw.BorderSide(color: _green, width: 3),
                    ),
                  ),
                  child: pw.Text(
                    item,
                    style: pw.TextStyle(
                        fontSize: 9, color: _grey700, lineSpacing: 3),
                  ),
                ))
            .toList(),
      ),
      pw.SizedBox(height: 16),
    ];
  }

  // ═══════════════════════════════════════════════════════════════════
  //  DECISIONS
  // ═══════════════════════════════════════════════════════════════════

  List<pw.Widget> _buildDecisionsSection(List<String> items) {
    if (items.isEmpty) return [];
    return [
      _sectionHeader('Decisions', _orange),
      pw.SizedBox(height: 8),
      ...items.map(
        (item) => pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(bottom: 6),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: _orangeLight,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border(
              left: pw.BorderSide(color: _orange, width: 3),
            ),
          ),
          child: pw.Text(
            item,
            style:
                pw.TextStyle(fontSize: 9, color: _grey700, lineSpacing: 3),
          ),
        ),
      ),
      pw.SizedBox(height: 16),
    ];
  }

  // ═══════════════════════════════════════════════════════════════════
  //  ACTION ITEMS
  // ═══════════════════════════════════════════════════════════════════

  List<pw.Widget> _buildActionItemsSection(List<dynamic> items) {
    return [
      _sectionHeader('Action Items', _blue),
      pw.SizedBox(height: 8),
      ...items.map((item) {
        if (item is Map<String, dynamic>) {
          final task = item['task'] as String? ?? '';
          final assignee = item['assignee'] as String?;
          final status = item['status'] as String? ?? 'pending';
          final priority = item['priority'] as String? ?? 'medium';
          final isDone = status == 'done';

          final priorityColor = switch (priority) {
            'high' => _red,
            'medium' => _yellow,
            _ => _grey500,
          };

          return pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.only(bottom: 6),
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: isDone ? _greenLight : _blueLight,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border(
                left: pw.BorderSide(
                    color: isDone ? _green : _blue, width: 3),
              ),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Checkbox
                pw.Container(
                  width: 14,
                  height: 14,
                  margin: const pw.EdgeInsets.only(top: 1, right: 8),
                  decoration: pw.BoxDecoration(
                    color: isDone ? _green : PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(3),
                    border: pw.Border.all(
                        color: isDone ? _green : _grey200, width: 1),
                  ),
                  child: isDone
                      ? pw.Center(
                          child: pw.Text('✓',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColors.white,
                                  fontWeight: pw.FontWeight.bold)))
                      : pw.SizedBox(),
                ),
                // Content
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        task,
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: isDone ? _grey500 : _grey700,
                          lineSpacing: 3,
                          decoration: isDone
                              ? pw.TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (assignee != null && assignee.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 3),
                          child: pw.Text(
                            assignee,
                            style:
                                pw.TextStyle(fontSize: 7, color: _grey500),
                          ),
                        ),
                    ],
                  ),
                ),
                // Priority dot
                pw.Container(
                  width: 8,
                  height: 8,
                  margin: const pw.EdgeInsets.only(top: 3),
                  decoration: pw.BoxDecoration(
                    color: priorityColor,
                    shape: pw.BoxShape.circle,
                  ),
                ),
              ],
            ),
          );
        }
        return pw.SizedBox();
      }),
    ];
  }

  // ═══════════════════════════════════════════════════════════════════
  //  FOLLOW-UPS
  // ═══════════════════════════════════════════════════════════════════

  List<pw.Widget> _buildFollowUpsSection(List<String> items) {
    if (items.isEmpty) return [];
    return [
      _sectionHeader('Follow-ups', _yellow),
      pw.SizedBox(height: 8),
      ...items.map(
        (item) => pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(bottom: 6),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: _yellowLight,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border(
              left: pw.BorderSide(color: _yellow, width: 3),
            ),
          ),
          child: pw.Text(
            item,
            style:
                pw.TextStyle(fontSize: 9, color: _grey700, lineSpacing: 3),
          ),
        ),
      ),
      pw.SizedBox(height: 16),
    ];
  }

  // ═══════════════════════════════════════════════════════════════════
  //  AI INSIGHTS
  // ═══════════════════════════════════════════════════════════════════

  List<pw.Widget> _buildInsightsSection(List<dynamic> insights) {
    return [
      _sectionHeader('AI Insights', _orange),
      pw.SizedBox(height: 8),
      pw.Wrap(
        spacing: 8,
        runSpacing: 8,
        children: insights.map((insight) {
          if (insight is Map<String, dynamic>) {
            final insightTitle = insight['title'] as String? ?? 'Insight';
            final content = insight['content'] as String? ?? '';
            final category = insight['category'] as String? ?? '';
            final importance = insight['importance'] as String? ?? 'medium';

            final importanceColor = switch (importance) {
              'high' => _red,
              'medium' => _orange,
              _ => _grey500,
            };

            return pw.Container(
              width: 248,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: _grey50,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: _grey200, width: 0.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Container(
                        width: 6,
                        height: 6,
                        decoration: pw.BoxDecoration(
                          color: importanceColor,
                          shape: pw.BoxShape.circle,
                        ),
                      ),
                      pw.SizedBox(width: 6),
                      pw.Expanded(
                        child: pw.Text(
                          insightTitle,
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: _grey900,
                          ),
                        ),
                      ),
                      if (category.isNotEmpty)
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: pw.BoxDecoration(
                            color: _purpleLight,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(
                            category,
                            style: pw.TextStyle(
                                fontSize: 6, color: _purple),
                          ),
                        ),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    content,
                    style: pw.TextStyle(
                        fontSize: 8, color: _grey700, lineSpacing: 3),
                    maxLines: 5,
                  ),
                ],
              ),
            );
          }
          return pw.SizedBox();
        }).toList(),
      ),
      pw.SizedBox(height: 16),
    ];
  }

  // ═══════════════════════════════════════════════════════════════════
  //  TRANSCRIPT APPENDIX
  // ═══════════════════════════════════════════════════════════════════

  List<pw.Widget> _buildTranscriptAppendix(List<dynamic> segments) {
    return [
      pw.SizedBox(height: 8),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: pw.BoxDecoration(
          color: _grey100,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Text(
          'APPENDIX  ·  Full Transcript',
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: _grey500,
            letterSpacing: 1.5,
          ),
        ),
      ),
      pw.SizedBox(height: 10),
      ...segments.map((seg) {
        if (seg is Map<String, dynamic>) {
          final speaker = seg['speaker'] as String? ?? 'Unknown';
          final text = seg['text'] as String? ?? '';
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 60,
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: _purpleLight,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    speaker,
                    style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                      color: _purple,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Text(
                    text,
                    style: pw.TextStyle(
                        fontSize: 8, color: _grey700, lineSpacing: 3),
                  ),
                ),
              ],
            ),
          );
        }
        return pw.SizedBox();
      }),
    ];
  }

  // ═══════════════════════════════════════════════════════════════════
  //  PRO GATE
  // ═══════════════════════════════════════════════════════════════════

  pw.Widget _buildProGate() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [_purpleLight, PdfColor.fromInt(0xFFF5F3FF)],
        ),
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: _purple, width: 1.5),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'Upgrade to Aura Pro',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: _purple,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Unlock full PDF reports with transcript, AI insights,\naction items, and unlimited exports.',
            style: pw.TextStyle(fontSize: 9, color: _grey700),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: pw.BoxDecoration(
              color: _purple,
              borderRadius: pw.BorderRadius.circular(20),
            ),
            child: pw.Text(
              'aurameet.live',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  SHARED COMPONENTS
  // ═══════════════════════════════════════════════════════════════════

  pw.Widget _sectionHeader(String title, PdfColor color) {
    return pw.Row(
      children: [
        pw.Container(
          width: 4,
          height: 14,
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: pw.BorderRadius.circular(2),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: _grey900,
          ),
        ),
      ],
    );
  }

  List<String> _extractList(Object? data) {
    if (data is List) {
      return data.map((e) => e.toString()).toList();
    }
    return <String>[];
  }
}
