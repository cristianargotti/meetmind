import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:meetmind/config/theme.dart';
import 'package:meetmind/services/meeting_api_service.dart';

/// Meeting detail screen — view a past meeting's transcript, summary, insights.
class MeetingDetailScreen extends StatefulWidget {
  /// Create meeting detail screen.
  const MeetingDetailScreen({super.key, required this.meetingId});

  /// The meeting ID to display.
  final String meetingId;

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen>
    with SingleTickerProviderStateMixin {
  final MeetingApiService _api = MeetingApiService();
  Map<String, dynamic>? _meeting;
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMeeting();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _api.dispose();
    super.dispose();
  }

  /// Load meeting data from the backend.
  Future<void> _loadMeeting() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final meeting = await _api.getMeeting(widget.meetingId);
      if (mounted) {
        setState(() {
          _meeting = meeting;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Copy transcript to clipboard as Markdown.
  Future<void> _copyTranscript() async {
    final segments = _meeting?['segments'] as List<dynamic>? ?? [];
    if (segments.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln('# ${_meeting?['title'] ?? 'Meeting Transcript'}\n');

    for (final seg in segments) {
      final speaker = seg['speaker'] as String? ?? 'Unknown';
      final text = seg['text'] as String? ?? '';
      buffer.writeln('**$speaker**: $text');
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transcript copied to clipboard')),
      );
    }
  }

  /// Copy summary to clipboard.
  Future<void> _copySummary() async {
    final summary = _meeting?['summary'] as Map<String, dynamic>?;
    if (summary == null) return;

    final buffer = StringBuffer();
    buffer.writeln('# ${summary['title'] ?? 'Meeting Summary'}\n');
    if (summary['overview'] != null) {
      buffer.writeln('## Overview\n${summary['overview']}\n');
    }

    final keyPoints = summary['key_points'] as List<dynamic>? ?? [];
    if (keyPoints.isNotEmpty) {
      buffer.writeln('## Key Points');
      for (final point in keyPoints) {
        buffer.writeln('- $point');
      }
      buffer.writeln();
    }

    final actionItems = summary['action_items'] as List<dynamic>? ?? [];
    if (actionItems.isNotEmpty) {
      buffer.writeln('## Action Items');
      for (final item in actionItems) {
        if (item is Map) {
          buffer.writeln('- [ ] ${item['task'] ?? item}');
        } else {
          buffer.writeln('- [ ] $item');
        }
      }
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Summary copied to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(
          child: CircularProgressIndicator(color: MeetMindTheme.primary),
        ),
      );
    }

    if (_error != null || _meeting == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: MeetMindTheme.error),
              const SizedBox(height: 16),
              Text(_error ?? 'Meeting not found'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadMeeting, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final title = _meeting!['title'] as String? ?? 'Untitled Meeting';
    final durationSecs = _meeting!['duration_secs'] as int? ?? 0;
    final duration = Duration(seconds: durationSecs);
    final startedAt = _meeting!['started_at'] as String?;
    final segments = _meeting!['segments'] as List<dynamic>? ?? [];
    final insights = _meeting!['insights'] as List<dynamic>? ?? [];

    String dateStr = '';
    if (startedAt != null) {
      try {
        final dt = DateTime.parse(startedAt).toLocal();
        dateStr = DateFormat('MMM d, yyyy • h:mm a').format(dt);
      } catch (_) {}
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'copy_transcript') _copyTranscript();
              if (value == 'copy_summary') _copySummary();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'copy_transcript',
                child: ListTile(
                  leading: Icon(Icons.copy_rounded, size: 20),
                  title: Text('Copy Transcript'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'copy_summary',
                child: ListTile(
                  leading: Icon(Icons.summarize_rounded, size: 20),
                  title: Text('Copy Summary'),
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Meeting info header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 13, color: MeetMindTheme.textTertiary),
                const SizedBox(width: 6),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: MeetMindTheme.textTertiary,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.timer_outlined,
                    size: 13, color: MeetMindTheme.textTertiary),
                const SizedBox(width: 4),
                Text(
                  durationSecs > 0
                      ? '${duration.inMinutes}m ${duration.inSeconds % 60}s'
                      : '< 1m',
                  style: TextStyle(
                    fontSize: 12,
                    color: MeetMindTheme.textTertiary,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.segment_rounded,
                    size: 13, color: MeetMindTheme.textTertiary),
                const SizedBox(width: 4),
                Text(
                  '${segments.length} segments',
                  style: TextStyle(
                    fontSize: 12,
                    color: MeetMindTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),

          // Tab bar
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Transcript'),
              Tab(text: 'Summary'),
              Tab(text: 'Insights'),
            ],
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _TranscriptTab(segments: segments),
                _SummaryTab(
                  meeting: _meeting!,
                  onCopySummary: _copySummary,
                ),
                _InsightsTab(insights: insights),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Transcript tab — scrollable list of speaker segments.
class _TranscriptTab extends StatelessWidget {
  const _TranscriptTab({required this.segments});

  final List<dynamic> segments;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) {
      return const Center(
        child: Text(
          'No transcript available',
          style: TextStyle(color: MeetMindTheme.textTertiary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: segments.length,
      itemBuilder: (context, index) {
        final seg = segments[index] as Map<String, dynamic>;
        final speaker = seg['speaker'] as String? ?? 'Unknown';
        final text = seg['text'] as String? ?? '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Speaker badge
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: MeetMindTheme.primaryDim,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  speaker,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: MeetMindTheme.primaryLight,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Text
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: MeetMindTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(
              delay: Duration(milliseconds: index * 30),
              duration: 300.ms,
            );
      },
    );
  }
}

/// Summary tab — overview, key points, action items, decisions.
class _SummaryTab extends StatelessWidget {
  const _SummaryTab({
    required this.meeting,
    required this.onCopySummary,
  });

  final Map<String, dynamic> meeting;
  final VoidCallback onCopySummary;

  @override
  Widget build(BuildContext context) {
    final summary = meeting['summary'] as Map<String, dynamic>?;
    final actionItems = meeting['action_items'] as List<dynamic>? ?? [];

    if (summary == null) {
      return const Center(
        child: Text(
          'No summary generated',
          style: TextStyle(color: MeetMindTheme.textTertiary),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          if (summary['title'] != null) ...[
            Text(
              summary['title'] as String,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: MeetMindTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Overview
          if (summary['overview'] != null) ...[
            _SectionHeader(title: 'Overview'),
            const SizedBox(height: 8),
            Text(
              summary['overview'] as String,
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
                color: MeetMindTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Key Points
          _buildJsonList(
            summary['key_points'],
            'Key Points',
            Icons.star_rounded,
            MeetMindTheme.accent,
          ),

          // Action Items (from dedicated table)
          if (actionItems.isNotEmpty) ...[
            _SectionHeader(title: 'Action Items'),
            const SizedBox(height: 8),
            ...actionItems.map<Widget>((item) {
              if (item is Map<String, dynamic>) {
                return _ActionItemCard(item: item);
              }
              return const SizedBox.shrink();
            }),
            const SizedBox(height: 20),
          ],

          // Decisions
          _buildJsonList(
            summary['decisions'],
            'Decisions',
            Icons.gavel_rounded,
            MeetMindTheme.copilot,
          ),

          // Follow-ups
          _buildJsonList(
            summary['follow_ups'],
            'Follow-ups',
            Icons.schedule_rounded,
            MeetMindTheme.warning,
          ),

          // Copy button
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCopySummary,
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy Summary'),
              style: OutlinedButton.styleFrom(
                foregroundColor: MeetMindTheme.primary,
                side: const BorderSide(color: MeetMindTheme.darkBorder),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  /// Build a section from JSON list data.
  Widget _buildJsonList(
    Object? data,
    String title,
    IconData icon,
    Color color,
  ) {
    if (data == null) return const SizedBox.shrink();

    List<String> items = [];
    if (data is List) {
      items = data.map((e) => e.toString()).toList();
    } else if (data is String) {
      items = [data];
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: title),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Icon(icon, size: 14, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: MeetMindTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

/// Insights tab — list of AI-generated insights.
class _InsightsTab extends StatelessWidget {
  const _InsightsTab({required this.insights});

  final List<dynamic> insights;

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) {
      return const Center(
        child: Text(
          'No insights generated',
          style: TextStyle(color: MeetMindTheme.textTertiary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: insights.length,
      itemBuilder: (context, index) {
        final insight = insights[index] as Map<String, dynamic>;
        final insightTitle = insight['title'] as String? ?? 'Insight';
        final content = insight['content'] as String? ?? '';
        final category = insight['category'] as String? ?? '';
        final importance = insight['importance'] as String? ?? 'medium';

        final importanceColor = switch (importance) {
          'high' => MeetMindTheme.error,
          'medium' => MeetMindTheme.warning,
          _ => MeetMindTheme.textTertiary,
        };

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MeetMindTheme.darkCard,
            borderRadius: BorderRadius.circular(MeetMindTheme.radiusSm),
            border: Border.all(color: MeetMindTheme.darkBorder, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: importanceColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      insightTitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: MeetMindTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (category.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: MeetMindTheme.primaryDim,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          fontSize: 10,
                          color: MeetMindTheme.primaryLight,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                content,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: MeetMindTheme.textSecondary,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(
              delay: Duration(milliseconds: index * 50),
              duration: 300.ms,
            );
      },
    );
  }
}

/// Section header widget.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: MeetMindTheme.textPrimary,
      ),
    );
  }
}

/// Action item card with status and priority.
class _ActionItemCard extends StatelessWidget {
  const _ActionItemCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final task = item['task'] as String? ?? '';
    final assignee = item['assignee'] as String?;
    final priority = item['priority'] as String? ?? 'medium';
    final status = item['status'] as String? ?? 'pending';

    final priorityColor = switch (priority) {
      'high' => MeetMindTheme.error,
      'medium' => MeetMindTheme.warning,
      _ => MeetMindTheme.textTertiary,
    };

    final isDone = status == 'done';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MeetMindTheme.darkCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MeetMindTheme.darkBorder, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 18,
            color: isDone ? MeetMindTheme.success : MeetMindTheme.textTertiary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: isDone
                        ? MeetMindTheme.textTertiary
                        : MeetMindTheme.textPrimary,
                    decoration:
                        isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (assignee != null && assignee.isNotEmpty)
                  Text(
                    assignee,
                    style: const TextStyle(
                      fontSize: 11,
                      color: MeetMindTheme.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: priorityColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
