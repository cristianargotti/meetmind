import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

/// Meeting export service — copy and share meeting data.
class ExportService {
  ExportService._();
  static final instance = ExportService._();

  /// Format a meeting as readable text.
  String formatMeetingText(Map<String, dynamic> meeting, {bool fullExport = true}) {
    final buffer = StringBuffer();
    final title = meeting['title'] ?? 'Meeting';
    final date = meeting['created_at'] ?? '';
    final duration = meeting['duration_seconds'] ?? 0;
    final transcript = meeting['transcript'] as List? ?? [];
    final insights = meeting['insights'] as List? ?? [];
    final summary = meeting['summary'] ?? '';
    final actionItems = meeting['action_items'] as List? ?? [];

    // Header
    buffer.writeln('# $title');
    if (date.isNotEmpty) {
      try {
        final dt = DateTime.parse(date);
        buffer.writeln('📅 ${DateFormat('MMMM d, yyyy · h:mm a').format(dt)}');
      } catch (_) {
        buffer.writeln('📅 $date');
      }
    }
    if (duration > 0) {
      final mins = (duration as int) ~/ 60;
      buffer.writeln('⏱️ ${mins}min');
    }
    buffer.writeln();

    // Summary (always included)
    if (summary.toString().isNotEmpty) {
      buffer.writeln('## Summary');
      buffer.writeln(summary);
      buffer.writeln();
    }

    if (!fullExport) {
      buffer.writeln('---');
      buffer.writeln('📌 Upgrade to Aura Pro for full export (transcript, insights, action items)');
      return buffer.toString();
    }

    // Insights
    if (insights.isNotEmpty) {
      buffer.writeln('## Key Insights');
      for (final insight in insights) {
        final text = insight is Map ? (insight['text'] ?? insight.toString()) : insight.toString();
        buffer.writeln('💡 $text');
      }
      buffer.writeln();
    }

    // Action Items
    if (actionItems.isNotEmpty) {
      buffer.writeln('## Action Items');
      for (final item in actionItems) {
        final text = item is Map ? (item['text'] ?? item.toString()) : item.toString();
        final status = item is Map ? (item['status'] ?? 'pending') : 'pending';
        final check = status == 'done' ? '✅' : '⬜';
        buffer.writeln('$check $text');
      }
      buffer.writeln();
    }

    // Transcript
    if (transcript.isNotEmpty) {
      buffer.writeln('## Transcript');
      for (final entry in transcript) {
        if (entry is Map) {
          final speaker = entry['speaker'] ?? '';
          final text = entry['text'] ?? '';
          buffer.writeln('**$speaker:** $text');
        } else {
          buffer.writeln(entry.toString());
        }
      }
      buffer.writeln();
    }

    buffer.writeln('---');
    buffer.writeln('Exported from Aura Meet');

    return buffer.toString();
  }

  /// Copy meeting to clipboard.
  Future<void> copyToClipboard(Map<String, dynamic> meeting, {bool fullExport = true}) async {
    final text = formatMeetingText(meeting, fullExport: fullExport);
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Share meeting via native share sheet.
  Future<void> shareMeeting(Map<String, dynamic> meeting, {bool fullExport = true}) async {
    final text = formatMeetingText(meeting, fullExport: fullExport);
    final title = meeting['title'] ?? 'Meeting Notes';
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        title: title,
      ),
    );
  }
}
