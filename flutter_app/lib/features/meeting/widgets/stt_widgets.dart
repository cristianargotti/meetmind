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

/// Live partial transcript panel — prominently shows what's being heard.
///
/// Designed to be easily readable so the user can follow along
/// in real-time while the AI listens and transcribes.
class PartialTranscriptBar extends StatefulWidget {
  const PartialTranscriptBar({required this.text, super.key});

  final String text;

  @override
  State<PartialTranscriptBar> createState() => _PartialTranscriptBarState();
}

class _PartialTranscriptBarState extends State<PartialTranscriptBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cursorController;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            MeetMindTheme.accent.withValues(alpha: 0.08),
            MeetMindTheme.darkSurface,
          ],
        ),
        border: const Border(
          top: BorderSide(color: MeetMindTheme.darkBorder, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Animated waveform bars
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: SizedBox(
              width: 24,
              height: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(3, (int i) {
                  return const SizedBox(width: 4, height: 24)
                      .animate(
                        onPlay: (AnimationController c) =>
                            c.repeat(reverse: true),
                        delay: Duration(milliseconds: i * 150),
                      )
                      .custom(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                        builder:
                            (
                              BuildContext context,
                              double value,
                              Widget? child,
                            ) {
                              return Container(
                                width: 4,
                                height: 8 + (16 * value),
                                decoration: BoxDecoration(
                                  color: MeetMindTheme.accent.withValues(
                                    alpha: 0.8,
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              );
                            },
                      );
                }),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Live transcript text with blinking cursor
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    widget.text,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 22,
                      height: 1.4,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Blinking cursor
                AnimatedBuilder(
                  animation: _cursorController,
                  builder: (BuildContext context, Widget? child) {
                    return Opacity(
                      opacity: _cursorController.value,
                      child: Container(
                        width: 2.5,
                        height: 24,
                        margin: const EdgeInsets.only(left: 2, bottom: 2),
                        color: MeetMindTheme.accent,
                      ),
                    );
                  },
                ),
              ],
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
