import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:meetmind/config/theme.dart';
import 'package:meetmind/services/whisper_stt_service.dart';

/// STT model status badge shown in the app bar.
class SttBadge extends StatelessWidget {
  const SttBadge({required this.status, super.key});

  final WhisperModelStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color color, String label, IconData icon) = switch (status) {
      WhisperModelStatus.unloaded => (Colors.white24, 'STT OFF', Icons.mic_off),
      WhisperModelStatus.loading => (
        MeetMindTheme.warning,
        'Loading',
        Icons.download,
      ),
      WhisperModelStatus.loaded => (MeetMindTheme.success, 'STT ON', Icons.mic),
      WhisperModelStatus.error => (
        MeetMindTheme.error,
        'Error',
        Icons.error_outline,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Live partial transcript bar — shows real-time STT text.
class PartialTranscriptBar extends StatelessWidget {
  const PartialTranscriptBar({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: MeetMindTheme.darkSurface,
        border: Border(
          top: BorderSide(color: MeetMindTheme.darkBorder, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.mic, color: MeetMindTheme.accent, size: 16)
              .animate(onPlay: (AnimationController c) => c.repeat())
              .fadeIn(duration: 600.ms)
              .then()
              .fadeOut(duration: 600.ms),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}

/// Language selector dropdown for STT.
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({
    required this.currentLanguage,
    required this.onChanged,
    super.key,
  });

  final String currentLanguage;
  final ValueChanged<String> onChanged;

  static const List<({String code, String label, String flag})> languages = [
    (code: 'auto', label: 'Auto', flag: '🌐'),
    (code: 'es', label: 'Español', flag: '🇨🇴'),
    (code: 'pt', label: 'Português', flag: '🇧🇷'),
    (code: 'en', label: 'English', flag: '🇺🇸'),
  ];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      color: MeetMindTheme.darkCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (BuildContext context) {
        return languages.map((lang) {
          return PopupMenuItem<String>(
            value: lang.code,
            child: Row(
              children: [
                Text(lang.flag, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Text(
                  lang.label,
                  style: TextStyle(
                    color: currentLanguage == lang.code
                        ? MeetMindTheme.primary
                        : Colors.white,
                    fontWeight: currentLanguage == lang.code
                        ? FontWeight.w700
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: MeetMindTheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _flagForCode(currentLanguage),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, color: Colors.white54, size: 16),
          ],
        ),
      ),
    );
  }

  String _flagForCode(String code) {
    return languages.where((l) => l.code == code).firstOrNull?.flag ?? '🌐';
  }
}
