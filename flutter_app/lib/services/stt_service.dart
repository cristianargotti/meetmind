import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:meetmind/services/speech_analyzer_service.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// On-device Speech-to-Text service (facade pattern).
///
/// Automatically selects the best engine at runtime:
///   - **iOS 26+**: Apple SpeechAnalyzer (no session limit, on-device)
///   - **iOS < 26**: SFSpeechRecognizer via speech_to_text plugin (60s limit)
///
/// Features:
///   - Word-by-word ~100-200ms latency
///   - Auto language detection
///   - Continuous listening
///   - 30+ language support
class SttService {
  SttService._();

  /// Singleton instance.
  static final SttService instance = SttService._();

  // ─── Engine delegation ─────────────────────────────────────────────
  /// True when using SpeechAnalyzer (iOS 26+), false for legacy engine.
  bool _useAnalyzer = false;
  StreamSubscription<SttTranscript>? _analyzerSub;

  // ─── Legacy engine ─────────────────────────────────────────────────
  final SpeechToText _speech = SpeechToText();
  final StreamController<SttTranscript> _transcriptController =
      StreamController<SttTranscript>.broadcast();

  bool _isInitialized = false;
  bool _isListening = false;
  String _currentLocale = 'es-CO';
  SttModelStatus _status = SttModelStatus.unloaded;

  /// Stream of transcript results (partial & final).
  /// Stream of transcript results.
  /// When using SpeechAnalyzer, this forwards its stream.
  /// When using legacy engine, uses the local controller.
  Stream<SttTranscript> get transcripts =>
      _useAnalyzer
          ? SpeechAnalyzerService.instance.transcripts
          : _transcriptController.stream;

  /// Whether the service is currently listening.
  bool get isListening =>
      _useAnalyzer ? SpeechAnalyzerService.instance.isListening : _isListening;

  /// Current model/service status.
  SttModelStatus get status =>
      _useAnalyzer ? SpeechAnalyzerService.instance.status : _status;

  /// Current locale being used for recognition.
  String get currentLocale =>
      _useAnalyzer
          ? SpeechAnalyzerService.instance.currentLocale
          : _currentLocale;

  /// List of available locales (populated after initialize).
  List<String> _availableLocales = [];

  /// Available locale IDs (e.g. 'en-US', 'es-CO').
  List<String> get availableLocales => List.unmodifiable(_availableLocales);

  // ─── Auto-detect state ────────────────────────────────────────────────
  bool _autoDetectMode = false;
  final List<double> _recentConfidences = [];
  int _langProbeIndex = 0;
  String? _bestProbeLocale;
  double _bestProbeConfidence = 0.0;

  /// Candidate locales to try during auto-detection (most common).
  static const List<String> _probeCandidates = [
    'es-CO', 'en-US', 'pt-BR', 'fr-FR', 'de-DE',
    'it-IT', 'ja-JP', 'ko-KR', 'zh-CN', 'ru-RU',
  ];

  /// Confidence threshold — below this, we try other languages.
  static const double _lowConfidenceThreshold = 0.35;

  /// Number of final results to evaluate before probing.
  static const int _confidenceWindowSize = 3;

  // ─────────────────────────────────────────────────────────────────────

  /// Initialize the speech recognition engine.
  ///
  /// Automatically selects SpeechAnalyzer (iOS 26+) or legacy engine.
  /// Call once at app startup. Returns true if available.
  /// When [language] is 'auto', enables auto language detection.
  Future<bool> initialize({String language = 'es'}) async {
    // ── Try SpeechAnalyzer first (iOS 26+, no session limit) ──
    try {
      final bool analyzerAvailable =
          await SpeechAnalyzerService.isAvailable();
      if (analyzerAvailable) {
        final bool ok = await SpeechAnalyzerService.instance.initialize(
          language: language == 'auto' ? 'es' : language,
        );
        if (ok) {
          _useAnalyzer = true;
          _isInitialized = true;
          _status = SttModelStatus.ready;
          debugPrint('[SttInit] Using SpeechAnalyzer (iOS 26+, no limit)');
          debugPrint('[SttInit] Ready (lang=$language)');
          return true;
        }
      }
    } catch (e) {
      debugPrint('[SttInit] SpeechAnalyzer probe failed: $e');
    }

    // ── Fallback to legacy SFSpeechRecognizer (60s limit) ──
    debugPrint('[SttInit] Falling back to legacy SFSpeechRecognizer');
    try {
      _isInitialized = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
        debugLogging: kDebugMode,
      );

      if (_isInitialized) {
        // Cache available locales
        final locales = await _speech.locales();
        _availableLocales = locales.map((l) => l.localeId).toList();

        // Resolve locale + set auto-detect mode
        _autoDetectMode = (language == 'auto');
        _currentLocale = _resolveLocale(language);
        _status = SttModelStatus.ready;

        debugPrint('[SttInit] Legacy engine ready (locale=$_currentLocale, '
            'autoDetect=$_autoDetectMode)');
        debugPrint(
          '[SttInit] Available: ${_availableLocales.take(15).join(", ")}',
        );
      } else {
        _status = SttModelStatus.error;
        debugPrint('[SttInit] Speech recognition not available');
      }

      return _isInitialized;
    } catch (e) {
      _status = SttModelStatus.error;
      debugPrint('[SttInit] Init error: $e');
      return false;
    }
  }

  /// Start listening for speech. Results arrive on [transcripts].
  void startStream() {
    if (!_isInitialized) {
      debugPrint('[SttService] Cannot start — not initialized');
      return;
    }

    if (_useAnalyzer) {
      SpeechAnalyzerService.instance.startStream();
      return;
    }

    _isListening = true;
    _permanentError = false;
    _recentConfidences.clear();
    _langProbeIndex = 0;
    _bestProbeLocale = null;
    _bestProbeConfidence = 0.0;
    _startListening();
    debugPrint('[SttService] Stream started (locale=$_currentLocale)');
  }

  /// Stop listening.
  void stopStream() {
    if (_useAnalyzer) {
      SpeechAnalyzerService.instance.stopStream();
      return;
    }
    _isListening = false;
    _speech.stop();
    debugPrint('[SttService] Stream stopped');
  }

  /// Set the transcription language.
  ///
  /// Pass 'auto' for automatic detection, or a code like 'es', 'en', 'pt'.
  void setLanguage(String lang) {
    if (_useAnalyzer) {
      SpeechAnalyzerService.instance.setLanguage(lang);
      return;
    }

    _autoDetectMode = (lang == 'auto');
    _currentLocale = _resolveLocale(lang);
    _recentConfidences.clear();
    _langProbeIndex = 0;
    debugPrint('[SttService] Language set to $_currentLocale '
        '(autoDetect=$_autoDetectMode)');

    // If currently listening, restart with new locale
    if (_isListening) {
      _speech.stop();
      _permanentError = false;
      _startListening();
    }
  }

  /// Dispose the service.
  void dispose() {
    if (_useAnalyzer) {
      _analyzerSub?.cancel();
      SpeechAnalyzerService.instance.dispose();
      return;
    }
    _speech.stop();
    _speech.cancel();
    _transcriptController.close();
  }

  // ─────────────────────────────────────────────────────────────────────
  // Private
  // ─────────────────────────────────────────────────────────────────────

  bool _permanentError = false;
  bool _isRestarting = false;
  Timer? _restartTimer;
  int _retryErrorCount = 0;
  static const int _maxRetryErrors = 3;

  Future<void> _startListening() async {
    if (_permanentError || !_isListening || !_isInitialized) return;
    if (_isRestarting) return; // Prevent concurrent restarts
    _isRestarting = true;

    try {
      await _speech.listen(
        onResult: _onResult,
        localeId: _currentLocale,
        listenFor: const Duration(seconds: 59),
        pauseFor: const Duration(seconds: 3),
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
          onDevice: false, // Allow server on simulator
        ),
      );
    } catch (e) {
      debugPrint('[SttService] listen() failed: $e');
      _isListening = false;
    } finally {
      _isRestarting = false;
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    final String text = result.recognizedWords.trim();
    if (text.isEmpty) return;

    if (result.finalResult) {
      debugPrint('[SttService] Final [$_currentLocale] '
          'conf=${result.confidence.toStringAsFixed(2)}: "$text"');

      // Reset retry counter on successful recognition
      _retryErrorCount = 0;

      _transcriptController.add(SttTranscript(
        text: text,
        type: TranscriptType.finalResult,
        confidence: result.confidence,
        locale: _currentLocale,
      ));

      // ─── Auto language detection logic ───
      if (_autoDetectMode) {
        _trackConfidence(result.confidence);
      }

      // NOTE: Don't restart here — _onStatus('done') handles it.
      // Restarting from both causes a race condition / freeze.
    } else {
      // Partial result — live preview
      _transcriptController.add(SttTranscript(
        text: text,
        type: TranscriptType.partial,
        confidence: result.confidence,
        locale: _currentLocale,
      ));
    }
  }

  /// Track confidence and trigger language probe if consistently low.
  void _trackConfidence(double confidence) {
    // Apple returns -1 when confidence isn't available — ignore those
    if (confidence < 0) return;

    _recentConfidences.add(confidence);
    if (_recentConfidences.length > _confidenceWindowSize) {
      _recentConfidences.removeAt(0);
    }

    // Only check after we have enough samples
    if (_recentConfidences.length < _confidenceWindowSize) return;

    final double avgConfidence =
        _recentConfidences.reduce((a, b) => a + b) / _recentConfidences.length;

    debugPrint(
      '[SttService] Avg confidence: ${avgConfidence.toStringAsFixed(2)} '
      '(threshold=$_lowConfidenceThreshold)',
    );

    if (avgConfidence < _lowConfidenceThreshold) {
      _probeNextLanguage();
    } else {
      // Good confidence — lock in this language
      if (_bestProbeLocale != null && _bestProbeLocale != _currentLocale) {
        debugPrint('[SttService] 🎯 Language locked: $_currentLocale '
            '(conf=${avgConfidence.toStringAsFixed(2)})');
      }
      _bestProbeLocale = _currentLocale;
      _bestProbeConfidence = avgConfidence;
      _langProbeIndex = 0; // Reset probe cycle
    }
  }

  /// Try the next candidate language.
  void _probeNextLanguage() {
    // Track current locale's performance
    final double currentAvg = _recentConfidences.isNotEmpty
        ? _recentConfidences.reduce((a, b) => a + b) /
            _recentConfidences.length
        : 0.0;

    if (_bestProbeLocale == null || currentAvg > _bestProbeConfidence) {
      _bestProbeLocale = _currentLocale;
      _bestProbeConfidence = currentAvg;
    }

    // Find next candidate that's available on this device
    String? nextLocale;
    final int startIndex = _langProbeIndex;

    do {
      _langProbeIndex = (_langProbeIndex + 1) % _probeCandidates.length;
      final String candidate = _probeCandidates[_langProbeIndex];

      // Check if available and not the current locale
      if (candidate != _currentLocale &&
          _availableLocales.contains(candidate)) {
        nextLocale = candidate;
        break;
      }
    } while (_langProbeIndex != startIndex);

    if (nextLocale == null) {
      // Tried all candidates — use the best one
      if (_bestProbeLocale != null && _bestProbeLocale != _currentLocale) {
        debugPrint('[SttService] 🔄 All probed — best was $_bestProbeLocale '
            '(conf=${_bestProbeConfidence.toStringAsFixed(2)})');
        _switchLocale(_bestProbeLocale!);
      }
      return;
    }

    debugPrint('[SttService] 🔍 Low confidence — probing $nextLocale');
    _recentConfidences.clear();
    _switchLocale(nextLocale);
  }

  /// Switch to a new locale, restarting the listening session.
  void _switchLocale(String newLocale) {
    _currentLocale = newLocale;
    if (_isListening) {
      _speech.stop();
      // Small delay to let the stop complete
      Future.delayed(const Duration(milliseconds: 150), () {
        if (_isListening && _isInitialized && !_permanentError) {
          _startListening();
        }
      });
    }

    // Notify listeners about the language switch
    _transcriptController.add(SttTranscript(
      text: '🌐 Switched to ${_localeToLabel(newLocale)}',
      type: TranscriptType.status,
      confidence: 0.0,
      locale: newLocale,
    ));
  }

  void _onStatus(String status) {
    debugPrint('[SttService] Status: $status');

    // Debounce: iOS fires 'done' twice — only restart once
    if (status == 'done' && _isListening && !_permanentError) {
      _restartTimer?.cancel();
      _restartTimer = Timer(const Duration(milliseconds: 300), () {
        if (_isListening && _isInitialized && !_permanentError) {
          debugPrint('[SttService] Session ended — auto-restarting');
          _startListening();
        }
      });
    }
  }

  void _onError(dynamic error) {
    final String errorMsg = error.toString();
    debugPrint('[SttService] Error: $errorMsg');

    final bool isPermanent =
        errorMsg.contains('error_assets_not_installed') ||
            errorMsg.contains('error_permission') ||
            errorMsg.contains('error_not_available');

    if (isPermanent) {
      debugPrint('[SttService] ⛔ Permanent error — stopping');
      _permanentError = true;
      _isListening = false;
      _speech.stop();
      return;
    }

    // error_retry: Apple's recognizer sometimes needs a fresh session
    if (errorMsg.contains('error_retry')) {
      _retryErrorCount++;
      debugPrint('[SttService] error_retry #$_retryErrorCount/$_maxRetryErrors');
      if (_retryErrorCount >= _maxRetryErrors) {
        // Don't give up — reinitialize the engine instead
        debugPrint('[SttService] 🔄 Max retries hit — reinitializing engine');
        _retryErrorCount = 0;
        _speech.stop();
        _speech.cancel();
        _isRestarting = false;

        // Reinitialize after a pause
        _restartTimer?.cancel();
        _restartTimer = Timer(const Duration(seconds: 3), () async {
          if (!_isListening) return;
          try {
            _isInitialized = await _speech.initialize(
              onStatus: _onStatus,
              onError: _onError,
              debugLogging: kDebugMode,
            );
            if (_isInitialized && _isListening) {
              debugPrint('[SttService] ✅ Engine reinitialized — resuming');
              _startListening();
            }
          } catch (e) {
            debugPrint('[SttService] Reinit failed: $e');
          }
        });
        return;
      }
    }

    // Transient error — restart with delay
    final Duration delay = errorMsg.contains('error_no_match')
        ? const Duration(milliseconds: 200)
        : const Duration(seconds: 2);

    if (_isListening && !_permanentError) {
      _restartTimer?.cancel();
      _restartTimer = Timer(delay, () {
        if (_isListening && _isInitialized && !_permanentError) {
          debugPrint('[SttService] Restarting after transient error');
          _startListening();
        }
      });
    }
  }

  // ─── Locale resolution ─────────────────────────────────────────────

  /// Resolve a language code to the best available iOS locale.
  String _resolveLocale(String lang) {
    if (lang == 'auto') {
      // Start with device locale, auto-detect will refine
      final Locale deviceLocale = PlatformDispatcher.instance.locale;
      final String deviceId =
          '${deviceLocale.languageCode}-${deviceLocale.countryCode ?? ''}';
      debugPrint('[SttService] Auto-detect start: device=$deviceId');

      if (_availableLocales.contains(deviceId)) return deviceId;
      final match = _availableLocales
          .where((l) => l.startsWith('${deviceLocale.languageCode}-'))
          .firstOrNull;
      if (match != null) return match;

      return 'es-CO';
    }

    return _languageToLocale(lang);
  }

  /// Map simple language code to preferred iOS locale.
  static const Map<String, String> _localeMap = {
    'es': 'es-CO',
    'en': 'en-US',
    'pt': 'pt-BR',
    'fr': 'fr-FR',
    'de': 'de-DE',
    'it': 'it-IT',
    'ja': 'ja-JP',
    'ko': 'ko-KR',
    'zh': 'zh-CN',
    'ru': 'ru-RU',
    'ar': 'ar-SA',
    'hi': 'hi-IN',
    'nl': 'nl-NL',
    'pl': 'pl-PL',
    'tr': 'tr-TR',
    'sv': 'sv-SE',
    'da': 'da-DK',
    'no': 'nb-NO',
    'fi': 'fi-FI',
    'el': 'el-GR',
    'he': 'he-IL',
    'th': 'th-TH',
    'vi': 'vi-VN',
    'id': 'id-ID',
    'ms': 'ms-MY',
    'uk': 'uk-UA',
    'cs': 'cs-CZ',
    'ro': 'ro-RO',
    'hu': 'hu-HU',
    'ca': 'ca-ES',
  };

  String _languageToLocale(String lang) {
    return _localeMap[lang] ?? 'es-CO';
  }

  /// Human-readable label for a locale.
  static String _localeToLabel(String locale) {
    const Map<String, String> labels = {
      'es-CO': 'Español 🇨🇴',
      'en-US': 'English 🇺🇸',
      'pt-BR': 'Português 🇧🇷',
      'fr-FR': 'Français 🇫🇷',
      'de-DE': 'Deutsch 🇩🇪',
      'it-IT': 'Italiano 🇮🇹',
      'ja-JP': '日本語 🇯🇵',
      'ko-KR': '한국어 🇰🇷',
      'zh-CN': '中文 🇨🇳',
      'ru-RU': 'Русский 🇷🇺',
    };
    return labels[locale] ?? locale;
  }
}

// =============================================================================
// Data models
// =============================================================================

/// Transcription result.
class SttTranscript {
  const SttTranscript({
    required this.text,
    required this.type,
    this.confidence = 0.0,
    this.locale = '',
  });

  final String text;
  final TranscriptType type;
  final double confidence;

  /// The locale that produced this transcript.
  final String locale;
}

/// Type of transcript result.
enum TranscriptType {
  /// Partial result (may change).
  partial,

  /// Final committed result.
  finalResult,

  /// Status message (e.g. language switch notification).
  status,
}

/// Service status.
enum SttModelStatus {
  /// Not initialized.
  unloaded,

  /// Ready to listen.
  ready,

  /// Error occurred.
  error,
}
