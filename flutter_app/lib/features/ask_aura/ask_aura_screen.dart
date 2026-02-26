import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meetmind/config/theme.dart';
import 'package:meetmind/l10n/generated/app_localizations.dart';
import 'package:meetmind/providers/subscription_provider.dart';
import 'package:meetmind/services/meeting_api_service.dart';

/// Ask Aura — RAG-powered chat with meeting history.
///
/// Pro-gated feature. Uses semantic search across all past meetings
/// to answer questions with source references.
class AskAuraScreen extends ConsumerStatefulWidget {
  const AskAuraScreen({super.key});

  @override
  ConsumerState<AskAuraScreen> createState() => _AskAuraScreenState();
}

class _AskAuraScreenState extends ConsumerState<AskAuraScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<_ChatMessage> _messages = [];
  final MeetingApiService _api = MeetingApiService();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _controller.clear();
      _isLoading = true;
    });

    try {
      final Map<String, dynamic> response = await _api.askAura(question: text);
      if (!mounted) return;

      final String answer = response['answer'] as String? ?? '';
      final int? latencyMs = (response['latency_ms'] as num?)?.toInt();
      final List<dynamic> sources =
          response['sources'] as List<dynamic>? ?? <dynamic>[];
      final bool isError = response['error'] as bool? ?? false;

      setState(() {
        _messages.add(
          _ChatMessage(
            text: answer,
            isUser: false,
            latencyMs: latencyMs,
            sources: sources.cast<Map<String, dynamic>>(),
            isError: isError,
          ),
        );
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(text: 'Error: ${e.message}', isUser: false, isError: true),
        );
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Ask Aura error: $e');
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(text: 'Connection error. Try again.', isUser: false, isError: true),
        );
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isPro = ref.watch(isProProvider);

    // Pro gate
    if (!isPro) {
      return _ProGateView(l10n: l10n);
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, size: 20, color: MeetMindTheme.primary),
            const SizedBox(width: 8),
            Text(l10n.askAuraTitle),
          ],
        ),
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: _messages.isEmpty
                ? _EmptyState(onSuggestionTap: _onSuggestionTap)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    reverse: true,
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Show typing indicator at the top (index 0 in reversed list)
                      if (_isLoading && index == 0) {
                        return const _TypingIndicator();
                      }
                      final msgIndex = _isLoading ? index - 1 : index;
                      final msg = _messages[_messages.length - 1 - msgIndex];
                      return _ChatBubble(message: msg);
                    },
                  ),
          ),

          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
            decoration: BoxDecoration(
              color: MeetMindTheme.darkCard,
              border: Border(
                top: BorderSide(
                  color: MeetMindTheme.darkBorder.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _sendMessage(),
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        hintText: l10n.askAuraPlaceholder,
                        hintStyle: const TextStyle(color: Colors.white30),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: MeetMindTheme.darkBorder.withValues(alpha: 0.3),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isLoading ? null : _sendMessage,
                    icon: const Icon(Icons.send_rounded, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: MeetMindTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onSuggestionTap(String suggestion) {
    _controller.text = suggestion;
    _sendMessage();
  }
}

/// Pro gate paywall view.
class _ProGateView extends StatelessWidget {
  const _ProGateView({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(l10n.askAuraTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      MeetMindTheme.primary.withValues(alpha: 0.3),
                      MeetMindTheme.accent.withValues(alpha: 0.2),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 48,
                  color: MeetMindTheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.askAuraTitle,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.askAuraSubtitle,
                style: const TextStyle(color: Colors.white54, fontSize: 16),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => context.push('/paywall'),
                icon: const Icon(Icons.diamond),
                label: Text(l10n.subscriptionUpgrade),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05),
        ),
      ),
    );
  }
}

/// Suggested questions empty state.
class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.onSuggestionTap});

  final void Function(String) onSuggestionTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    final suggestions = [
      l10n.askAuraSuggestion1,
      l10n.askAuraSuggestion2,
      l10n.askAuraSuggestion3,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MeetMindTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 40,
              color: MeetMindTheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.askAuraEmpty,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.askAuraEmptyHint,
            style: const TextStyle(color: Colors.white38, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ...suggestions.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => onSuggestionTap(s),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: MeetMindTheme.darkCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: MeetMindTheme.darkBorder.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lightbulb_outline,
                        size: 18,
                        color: MeetMindTheme.warning,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          s,
                          style: const TextStyle(color: Colors.white60, fontSize: 14),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: Colors.white24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }
}

/// Typing indicator (three animated dots).
class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: MeetMindTheme.darkCard,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: MeetMindTheme.primary.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            )
                .animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                )
                .fadeIn(delay: Duration(milliseconds: i * 200))
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.2, 1.2),
                  duration: 600.ms,
                  curve: Curves.easeInOut,
                );
          }),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}

/// Chat bubble widget with optional source references.
class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: message.isUser
              ? MeetMindTheme.primary
              : message.isError
                  ? MeetMindTheme.darkCard
                  : MeetMindTheme.darkCard,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isUser ? 16 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 16),
          ),
          border: message.isError
              ? Border.all(color: Colors.red.withValues(alpha: 0.3))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: message.isUser
                    ? Colors.white
                    : message.isError
                        ? Colors.red.shade300
                        : Colors.white70,
                fontSize: 15,
              ),
            ),
            // Show sources for AI messages
            if (!message.isUser && message.sources.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: message.sources.map((source) {
                  final String title =
                      source['title'] as String? ?? 'Meeting';
                  final String date = source['date'] as String? ?? '';
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: MeetMindTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$title ($date)',
                      style: TextStyle(
                        color: MeetMindTheme.primary.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            // Show latency
            if (!message.isUser && message.latencyMs != null) ...[
              const SizedBox(height: 4),
              Text(
                '${message.latencyMs}ms',
                style: const TextStyle(color: Colors.white24, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.05);
  }
}

/// Chat message model with source references.
class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.latencyMs,
    this.sources = const [],
    this.isError = false,
  });

  final String text;
  final bool isUser;
  final int? latencyMs;
  final List<Map<String, dynamic>> sources;
  final bool isError;
}
