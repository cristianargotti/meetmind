import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:meetmind/config/theme.dart';
import 'package:meetmind/providers/meeting_provider.dart';
import 'package:meetmind/services/stt_service.dart';
import 'package:meetmind/services/user_preferences.dart';

/// STT setup screen — replaces the old model download screen.
///
/// With Apple's native speech recognition, no model download is needed.
/// This screen just verifies STT availability and permissions.
class SttSetupScreen extends ConsumerStatefulWidget {
  const SttSetupScreen({super.key});

  @override
  ConsumerState<SttSetupScreen> createState() => _SttSetupScreenState();
}

class _SttSetupScreenState extends ConsumerState<SttSetupScreen> {
  bool _initializing = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final SttModelStatus sttStatus = ref.watch(sttStatusProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Text(
                '🎤 Speech Recognition',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),
              const SizedBox(height: 8),
              Text(
                'Aura Meet uses Apple\'s on-device speech recognition '
                'for real-time transcription. Your audio never '
                'leaves your device.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                  height: 1.5,
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
              const SizedBox(height: 32),
              // Status card
              _StatusCard(status: sttStatus),
              const Spacer(),
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
              const SizedBox(height: 16),
              // Initialize / Continue button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _initializing
                      ? null
                      : sttStatus == SttModelStatus.ready
                          ? () => Navigator.pop(context)
                          : _initializeStt,
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
                    _initializing
                        ? 'Initializing...'
                        : sttStatus == SttModelStatus.ready
                            ? 'Continue ✓'
                            : 'Enable Speech Recognition',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Skip button
              if (sttStatus != SttModelStatus.ready)
                Center(
                  child: TextButton(
                    onPressed:
                        _initializing ? null : () => Navigator.pop(context),
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

  Future<void> _initializeStt() async {
    setState(() {
      _initializing = true;
      _error = null;
    });

    try {
      final SttService stt = ref.read(sttProvider);
      final String lang =
          UserPreferences.instance.transcriptionLanguage.code;
      final bool available = await stt.initialize(language: lang);

      if (mounted) {
        ref.read(sttStatusProvider.notifier).state =
            available ? SttModelStatus.ready : SttModelStatus.error;
        setState(() => _initializing = false);

        if (!available) {
          _error = 'Speech recognition is not available on this device. '
              'Please check Settings > Privacy > Speech Recognition.';
        }
      }
    } catch (e) {
      if (mounted) {
        ref.read(sttStatusProvider.notifier).state = SttModelStatus.error;
        setState(() {
          _initializing = false;
          _error = 'Initialization failed: $e';
        });
      }
    }
  }
}

/// Status card showing STT readiness.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final SttModelStatus status;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String title, String subtitle, Color color) =
        switch (status) {
      SttModelStatus.unloaded => (
          Icons.mic_off,
          'Not Initialized',
          'Tap below to enable speech recognition.',
          Colors.white38,
        ),
      SttModelStatus.ready => (
          Icons.mic,
          'Ready',
          'Apple\'s on-device speech recognition is active.',
          MeetMindTheme.success,
        ),
      SttModelStatus.error => (
          Icons.error_outline,
          'Unavailable',
          'Speech recognition is not available. Check device settings.',
          MeetMindTheme.error,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }
}
