import 'package:flutter/material.dart';

import 'package:meetmind/config/theme.dart';

/// Input bar for manual text entry + recording toggle.
class InputBar extends StatelessWidget {
  const InputBar({
    required this.controller,
    required this.isRecording,
    required this.onSend,
    required this.onToggleRecording,
    super.key,
  });

  final TextEditingController controller;
  final bool isRecording;
  final VoidCallback onSend;
  final VoidCallback onToggleRecording;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      decoration: const BoxDecoration(
        color: MeetMindTheme.darkSurface,
        border: Border(top: BorderSide(color: MeetMindTheme.darkBorder)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onToggleRecording,
            icon: Icon(
              isRecording ? Icons.pause_circle : Icons.play_circle,
              color: isRecording ? MeetMindTheme.error : MeetMindTheme.success,
              size: 32,
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(
                hintText: 'Type transcript text...',
                hintStyle: TextStyle(color: Colors.white24),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          IconButton(
            onPressed: onSend,
            icon: const Icon(Icons.send, color: MeetMindTheme.primary),
          ),
        ],
      ),
    );
  }
}
