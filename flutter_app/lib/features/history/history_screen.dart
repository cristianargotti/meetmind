import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:meetmind/config/theme.dart';
import 'package:meetmind/services/meeting_api_service.dart';

/// Meeting history screen — browse past sessions with search & swipe delete.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final MeetingApiService _api = MeetingApiService();
  List<Map<String, dynamic>> _meetings = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadMeetings();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  /// Load meetings from the backend API.
  Future<void> _loadMeetings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final meetings = await _api.listMeetings();
      if (mounted) {
        setState(() {
          _meetings = meetings;
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Connection error';
          _isLoading = false;
        });
      }
    }
  }

  /// Delete a meeting with confirmation.
  Future<void> _deleteMeeting(String meetingId, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Meeting'),
        content: const Text(
          'This will permanently delete the meeting and all its data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: MeetMindTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _api.deleteMeeting(meetingId);
        setState(() {
          _meetings.removeAt(index);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Meeting deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  /// Filter meetings by search query.
  List<Map<String, dynamic>> get _filteredMeetings {
    if (_searchQuery.isEmpty) return _meetings;
    final query = _searchQuery.toLowerCase();
    return _meetings.where((m) {
      final title = (m['title'] as String? ?? '').toLowerCase();
      return title.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meeting History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadMeetings,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search meetings...',
                hintStyle: TextStyle(
                  color: MeetMindTheme.textTertiary.withValues(alpha: 0.5),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: MeetMindTheme.textTertiary,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () =>
                            setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: MeetMindTheme.primary,
                    ),
                  )
                : _error != null
                    ? _buildError()
                    : _filteredMeetings.isEmpty
                        ? _buildEmpty()
                        : _buildMeetingList(),
          ),
        ],
      ),
    );
  }

  /// Build the meeting list with pull-to-refresh.
  Widget _buildMeetingList() {
    return RefreshIndicator(
      onRefresh: _loadMeetings,
      color: MeetMindTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredMeetings.length,
        itemBuilder: (context, index) {
          final meeting = _filteredMeetings[index];
          return _MeetingCard(
            meeting: meeting,
            onTap: () => context.push('/meeting/${meeting['id']}'),
            onDelete: () => _deleteMeeting(
              meeting['id'] as String,
              _meetings.indexOf(meeting),
            ),
          )
              .animate()
              .fadeIn(
                delay: Duration(milliseconds: index * 60),
                duration: 400.ms,
              )
              .slideY(
                begin: 0.1,
                delay: Duration(milliseconds: index * 60),
                duration: 400.ms,
                curve: Curves.easeOutCubic,
              );
        },
      ),
    );
  }

  /// Empty state when no meetings exist yet.
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: MeetMindTheme.primaryDim,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history_rounded,
              size: 48,
              color: MeetMindTheme.primary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _searchQuery.isEmpty ? 'No meetings yet' : 'No matches found',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: MeetMindTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Start your first meeting to see it here'
                : 'Try a different search term',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: MeetMindTheme.textTertiary),
          ),
        ],
      ),
    );
  }

  /// Error state with retry.
  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 48,
            color: MeetMindTheme.error.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Something went wrong',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: MeetMindTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadMeetings,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// A single meeting card in the history list.
class _MeetingCard extends StatelessWidget {
  const _MeetingCard({
    required this.meeting,
    required this.onTap,
    required this.onDelete,
  });

  final Map<String, dynamic> meeting;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = meeting['title'] as String? ?? 'Untitled Meeting';
    final status = meeting['status'] as String? ?? 'unknown';
    final segments = meeting['total_segments'] as int? ?? 0;
    final insights = meeting['total_insights'] as int? ?? 0;
    final costUsd = (meeting['cost_usd'] as num?)?.toDouble() ?? 0.0;
    final durationSecs = meeting['duration_secs'] as int? ?? 0;
    final startedAt = meeting['started_at'] as String?;

    // Format date
    String dateStr = '';
    String timeStr = '';
    if (startedAt != null) {
      try {
        final dt = DateTime.parse(startedAt).toLocal();
        dateStr = DateFormat('MMM d, yyyy').format(dt);
        timeStr = DateFormat('h:mm a').format(dt);
      } catch (_) {
        dateStr = 'Unknown date';
      }
    }

    // Format duration
    final duration = Duration(seconds: durationSecs);
    final durationStr = durationSecs > 0
        ? '${duration.inMinutes}m ${duration.inSeconds % 60}s'
        : '< 1m';

    final isCompleted = status == 'completed';

    return Dismissible(
      key: Key(meeting['id'] as String),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: MeetMindTheme.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(MeetMindTheme.radiusMd),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_rounded, color: MeetMindTheme.error),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // We handle deletion in the callback
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MeetMindTheme.darkCard,
            borderRadius: BorderRadius.circular(MeetMindTheme.radiusMd),
            border: Border.all(color: MeetMindTheme.darkBorder, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: title + status
              Row(
                children: [
                  // Status dot
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? MeetMindTheme.success
                          : MeetMindTheme.warning,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Title
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: MeetMindTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Chevron
                  Icon(
                    Icons.chevron_right_rounded,
                    color: MeetMindTheme.textTertiary.withValues(alpha: 0.5),
                    size: 20,
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Date + time
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 13,
                    color: MeetMindTheme.textTertiary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$dateStr  •  $timeStr',
                    style: TextStyle(
                      fontSize: 12,
                      color: MeetMindTheme.textTertiary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Stats row
              Row(
                children: [
                  _StatChip(
                    icon: Icons.timer_outlined,
                    value: durationStr,
                    color: MeetMindTheme.primary,
                  ),
                  const SizedBox(width: 12),
                  _StatChip(
                    icon: Icons.segment_rounded,
                    value: '$segments',
                    color: MeetMindTheme.accent,
                  ),
                  const SizedBox(width: 12),
                  _StatChip(
                    icon: Icons.lightbulb_outline_rounded,
                    value: '$insights',
                    color: MeetMindTheme.copilot,
                  ),
                  const Spacer(),
                  if (costUsd > 0)
                    Text(
                      '\$${costUsd.toStringAsFixed(3)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: MeetMindTheme.textTertiary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact stat chip for meeting cards.
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: MeetMindTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
