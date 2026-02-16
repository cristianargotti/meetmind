import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meetmind/config/theme.dart';
import 'package:meetmind/l10n/generated/app_localizations.dart';
import 'package:meetmind/providers/subscription_provider.dart';

/// Ask Aura — RAG-powered chat with meeting history.
///
/// Pro-gated feature. Backend integration in Sprint 2.
class AskAuraScreen extends ConsumerStatefulWidget {
  const AskAuraScreen({super.key});

  @override
  ConsumerState<AskAuraScreen> createState() => _AskAuraScreenState();
}

class _AskAuraScreenState extends ConsumerState<AskAuraScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<_ChatMessage> _messages = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _controller.clear();
    });

    // Simulate AI response (replace with real backend call in Sprint 2)
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _messages.add(
            _ChatMessage(
              text: '🧠 ${l10n.commonLoading}',
              isUser: false,
              isPlaceholder: true,
            ),
          );
        });
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
                ? _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    reverse: true,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[_messages.length - 1 - index];
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
                    onPressed: _sendMessage,
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
}

/// Suggested questions empty state.
class _EmptyState extends ConsumerWidget {
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
          color: message.isUser
              ? MeetMindTheme.primary
              : MeetMindTheme.darkCard,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isUser ? 16 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 16),
          ),
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
    this.isPlaceholder = false,
  });

  final String text;
  final bool isUser;
  final bool isPlaceholder;
}
