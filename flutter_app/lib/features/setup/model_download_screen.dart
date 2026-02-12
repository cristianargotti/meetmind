import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:meetmind/config/theme.dart';
import 'package:meetmind/providers/meeting_provider.dart';
import 'package:meetmind/services/model_manager.dart';
import 'package:meetmind/services/whisper_stt_service.dart';

/// First-launch model download screen.
///
/// Allows the user to select and download a Whisper model
/// before starting their first meeting.
class ModelDownloadScreen extends ConsumerStatefulWidget {
  const ModelDownloadScreen({super.key});

  @override
  ConsumerState<ModelDownloadScreen> createState() =>
      _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends ConsumerState<ModelDownloadScreen> {
  String _selectedModel = ModelManager.defaultModel;
  double _progress = 0.0;
  bool _downloading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final WhisperModelStatus sttStatus = ref.watch(sttStatusProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Text(
                '🧠 AI Speech Model',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),
              const SizedBox(height: 8),
              Text(
                'Download a speech recognition model for '
                'on-device transcription. Your audio never '
                'leaves your device.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                  height: 1.5,
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
              const SizedBox(height: 32),
              // Model cards
              Expanded(
                child: ListView(
                  children: ModelManager.catalog.entries.map((
                    MapEntry<String, ModelInfo> entry,
                  ) {
                    return _ModelCard(
                      info: entry.value,
                      isSelected: _selectedModel == entry.key,
                      onTap: _downloading
                          ? null
                          : () => setState(() => _selectedModel = entry.key),
                    );
                  }).toList(),
                ),
              ),
              // Error message
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: MeetMindTheme.error,
                    fontSize: 13,
                  ),
                ),
              ],
              // Progress bar
              if (_downloading) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 8,
                    backgroundColor: MeetMindTheme.darkBorder,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      MeetMindTheme.accent,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_progress * 100).toStringAsFixed(1)}% — '
                  'Downloading ${ModelManager.catalog[_selectedModel]?.label}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              // Download / Continue button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _downloading
                      ? null
                      : sttStatus == WhisperModelStatus.loaded
                      ? () => Navigator.pop(context)
                      : _startDownload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MeetMindTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    disabledBackgroundColor: MeetMindTheme.primary.withValues(
                      alpha: 0.4,
                    ),
                  ),
                  child: Text(
                    _downloading
                        ? 'Downloading...'
                        : sttStatus == WhisperModelStatus.loaded
                        ? 'Continue ✓'
                        : 'Download & Initialize',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Skip button
              if (sttStatus != WhisperModelStatus.loaded)
                Center(
                  child: TextButton(
                    onPressed: _downloading
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text(
                      'Skip for now (manual input only)',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _progress = 0.0;
      _error = null;
    });

    try {
      final ModelManager manager = ref.read(modelManagerProvider);
      final String modelPath = await manager.downloadModel(
        _selectedModel,
        onProgress: (double p) {
          if (mounted) setState(() => _progress = p);
        },
      );

      // Initialize Whisper with downloaded model
      if (mounted) {
        ref.read(sttStatusProvider.notifier).state = WhisperModelStatus.loading;
      }

      final WhisperSttService stt = ref.read(whisperProvider);
      await stt.initialize(modelPath: modelPath, language: 'auto');

      if (mounted) {
        ref.read(sttStatusProvider.notifier).state = WhisperModelStatus.loaded;
        setState(() => _downloading = false);
      }
    } catch (e) {
      if (mounted) {
        ref.read(sttStatusProvider.notifier).state = WhisperModelStatus.error;
        setState(() {
          _downloading = false;
          _error = 'Download failed: $e';
        });
      }
    }
  }
}

/// Individual model selection card.
class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.info, required this.isSelected, this.onTap});

  final ModelInfo info;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? MeetMindTheme.primary.withValues(alpha: 0.12)
                : MeetMindTheme.darkCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? MeetMindTheme.primary.withValues(alpha: 0.5)
                  : MeetMindTheme.darkBorder,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: isSelected ? MeetMindTheme.primary : Colors.white38,
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          info.label,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        if (info.name == 'base') ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: MeetMindTheme.accent.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'RECOMMENDED',
                              style: TextStyle(
                                color: MeetMindTheme.accent,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      info.description,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
