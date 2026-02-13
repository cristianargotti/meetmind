import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:meetmind/config/theme.dart';
import 'package:meetmind/models/meeting_models.dart';

/// Copilot chat panel — ask AI questions during a live meeting.
class CopilotPanel extends StatefulWidget {
  const CopilotPanel({
    required this.messages,
    required this.isLoading,
    required this.onSend,
    super.key,
  });

  /// Chat messages list.
  final List<CopilotMessage> messages;

  /// Whether the AI is currently generating a response.
  final bool isLoading;

  /// Callback when user sends a question.
  final ValueChanged<String> onSend;

  @override
  State<CopilotPanel> createState() => _CopilotPanelState();
}

class _CopilotPanelState extends State<CopilotPanel> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(CopilotPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length > oldWidget.messages.length) {
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future<void>.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend() {
    final String text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        // Messages list
        Expanded(
          child: widget.messages.isEmpty
              ? _EmptyCopilotState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount:
                      widget.messages.length + (widget.isLoading ? 1 : 0),
                  itemBuilder: (BuildContext context, int index) {
                    if (index == widget.messages.length) {
                      return const _TypingIndicator();
                    }
                    return _ChatBubble(message: widget.messages[index]);
                  },
                ),
        ),

        // Input bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: MeetMindTheme.darkBorder)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSend(),
                  decoration: InputDecoration(
                    hintText: 'Ask Copilot anything...',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: widget.isLoading ? null : _handleSend,
                icon: const Icon(Icons.send_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: MeetMindTheme.primary,
                  disabledBackgroundColor: MeetMindTheme.primary.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Empty state when no copilot messages yet.
class _EmptyCopilotState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.smart_toy_outlined,
            size: 64,
            color: MeetMindTheme.accent.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'MeetMind Copilot',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask questions about your meeting in real-time.\n'
            'Copilot has the full transcript as context.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white38),
          ),
        ],
      ).animate().fadeIn(duration: 500.ms),
    );
  }
}

/// Individual chat bubble.
class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final CopilotMessage message;

  @override
  Widget build(BuildContext context) {
    final bool isUser = message.sender == CopilotSender.user;
    final bool isError = message.sender == CopilotSender.error;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? MeetMindTheme.primary.withValues(alpha: 0.2)
              : isError
              ? MeetMindTheme.error.withValues(alpha: 0.15)
              : MeetMindTheme.darkCard,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null,
            bottomLeft: !isUser ? const Radius.circular(4) : null,
          ),
          border: Border.all(
            color: isUser
                ? MeetMindTheme.primary.withValues(alpha: 0.3)
                : isError
                ? MeetMindTheme.error.withValues(alpha: 0.3)
                : MeetMindTheme.darkBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              message.text,
              style: TextStyle(
                color: isError ? MeetMindTheme.error : Colors.white,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (!isUser && message.latencyMs != null) ...<Widget>[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.timer_outlined,
                    size: 12,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${message.latencyMs}ms',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                  if (message.modelTier != null) ...<Widget>[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: MeetMindTheme.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        message.modelTier!,
                        style: TextStyle(
                          color: MeetMindTheme.accent.withValues(alpha: 0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    ).animate().slideX(
      begin: isUser ? 0.1 : -0.1,
      duration: 200.ms,
      curve: Curves.easeOut,
    );
  }
}

/// Typing indicator animation.
class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: MeetMindTheme.darkCard,
          borderRadius: BorderRadius.circular(
            16,
          ).copyWith(bottomLeft: const Radius.circular(4)),
          border: Border.all(color: MeetMindTheme.darkBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < 3; i++) ...<Widget>[
              Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: MeetMindTheme.accent.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                  )
                  .animate(onPlay: (AnimationController c) => c.repeat())
                  .scaleXY(
                    begin: 0.5,
                    end: 1.0,
                    duration: 600.ms,
                    delay: Duration(milliseconds: i * 200),
                    curve: Curves.easeInOut,
                  )
                  .then()
                  .scaleXY(begin: 1.0, end: 0.5, duration: 600.ms),
              if (i < 2) const SizedBox(width: 4),
            ],
          ],
        ),
      ),
    );
  }
}
