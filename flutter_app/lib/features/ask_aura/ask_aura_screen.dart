import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meetmind/config/theme.dart';
import 'package:meetmind/l10n/generated/app_localizations.dart';
import 'package:meetmind/providers/subscription_provider.dart';
import 'package:meetmind/services/meeting_api_service.dart';

/// Ask Aura — AI copilot chat backed by the real backend.
///
/// Supports two modes:
///   - Live mode: called from within an active recording session,
///     passes the in-progress transcript as context.
///   - History mode: called from the meeting detail screen,
///     transcript_context is empty and the server loads it from the DB.
///
/// Pro-gated — non-Pro users see the paywall CTA.
class AskAuraScreen extends ConsumerStatefulWidget {
  const AskAuraScreen({
    super.key,
    required this.meetingId,
    this.transcriptContext = '',
  });

  /// ID of the meeting to ask questions about.
  final String meetingId;

  /// Live transcript context (empty = server loads from DB).
  final String transcriptContext;

  @override
  ConsumerState<AskAuraScreen> createState() => _AskAuraScreenState();
}

class _AskAuraScreenState extends ConsumerState<AskAuraScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? prefillText]) async {
    final text = (prefillText ?? _controller.text).trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _controller.clear();
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final result = await MeetingApiService().askCopilot(
        meetingId: widget.meetingId,
        question: text,
        transcriptContext: widget.transcriptContext,
      );

      final answer = result['answer'] as String? ?? '—';
      final isError = result['error'] == true;

      if (mounted) {
        setState(() {
          _messages.add(
            _ChatMessage(
              text: answer,
              isUser: false,
              isError: isError,
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            _ChatMessage(
              text: '⚠️ ${e.toString()}',
              isUser: false,
              isError: true,
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: MeetMindTheme.error,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isPro = ref.watch(isProProvider);

    // Pro gate
    if (!isPro) {
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(
              Icons.auto_awesome,
              size: 20,
              color: MeetMindTheme.primary,
            ),
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
                ? _EmptyState(onSuggestionTap: _sendMessage)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isLoading && index == _messages.length) {
                        return const _TypingIndicator();
                      }
                      return _ChatBubble(message: _messages[index]);
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
                      enabled: !_isLoading,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: l10n.askAuraPlaceholder,
                        hintStyle: const TextStyle(color: Colors.white30),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: MeetMindTheme.darkBorder.withValues(
                          alpha: 0.3,
                        ),
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
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          _isLoading ? Colors.white24 : MeetMindTheme.primary,
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
}

/// Animated typing indicator shown while waiting for the AI response.
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
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, size: 14, color: MeetMindTheme.primary),
            const SizedBox(width: 8),
            ...List.generate(3, (i) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.white38,
                  shape: BoxShape.circle,
                ),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .fadeIn(
                    duration: 400.ms,
                    delay: (i * 150).ms,
                  )
                  .fadeOut(duration: 400.ms, delay: ((i * 150) + 400).ms);
            }),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
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
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 14,
                          ),
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

/// Chat bubble widget.
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
          color: message.isError
              ? MeetMindTheme.error.withValues(alpha: 0.15)
              : message.isUser
                  ? MeetMindTheme.primary
                  : MeetMindTheme.darkCard,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isUser ? 16 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 16),
          ),
          border: message.isError
              ? Border.all(color: MeetMindTheme.error.withValues(alpha: 0.3))
              : null,
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isUser ? Colors.white : Colors.white70,
            fontSize: 15,
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.05);
  }
}

/// Simple chat message model.
class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  });

  final String text;
  final bool isUser;
  final bool isError;
}
