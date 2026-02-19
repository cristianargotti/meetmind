import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:meetmind/services/stt_service.dart';

/// Dart wrapper for the native SpeechAnalyzer iOS plugin (iOS 26+).
///
/// Communicates with [SpeechAnalyzerPlugin.swift] via platform channels.
/// Emits [SttTranscript] on the same stream interface as the legacy
/// [SttService], so [MeetingNotifier] doesn't need to change.
class SpeechAnalyzerService {
  SpeechAnalyzerService._();

  static final SpeechAnalyzerService instance = SpeechAnalyzerService._();

  static const MethodChannel _method =
      MethodChannel('com.aurameet/speech_analyzer');
  static const EventChannel _events =
      EventChannel('com.aurameet/speech_analyzer_events');

  final StreamController<SttTranscript> _transcriptController =
      StreamController<SttTranscript>.broadcast();

  StreamSubscription<dynamic>? _eventSub;
  bool _isInitialized = false;
  bool _isListening = false;
  SttModelStatus _status = SttModelStatus.unloaded;
  String _currentLocale = 'es-CO';

  // ─── Public API (mirrors SttService) ──────────────────────────────────

  /// Stream of transcript results (partial, final, status).
  Stream<SttTranscript> get transcripts => _transcriptController.stream;

  /// Whether currently listening.
  bool get isListening => _isListening;

  /// Current model status.
  SttModelStatus get status => _status;

  /// Current locale.
  String get currentLocale => _currentLocale;

  // ─── Availability ─────────────────────────────────────────────────────

  /// Check if SpeechAnalyzer is available on this device (iOS 26+).
  static Future<bool> isAvailable() async {
    try {
      final bool result = await _method.invokeMethod<bool>('isAvailable') ?? false;
      return result;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      // Plugin not registered — not on iOS or too old
      return false;
    }
  }

  // ─── Initialize ───────────────────────────────────────────────────────

  /// Initialize the SpeechAnalyzer engine.
  ///
  /// Requests speech recognition and microphone permissions.
  Future<bool> initialize({String language = 'es'}) async {
    if (_isInitialized) return true;

    final String locale = _languageToLocale(language);
    _currentLocale = locale;

    try {
      final bool result = await _method.invokeMethod<bool>(
        'initialize',
        <String, String>{'locale': locale},
      ) ?? false;

      if (result) {
        _isInitialized = true;
        _status = SttModelStatus.ready;
        _listenToEvents();
        debugPrint('[SpeechAnalyzer] Initialized (locale=$locale)');
      }
      return result;
    } on PlatformException catch (e) {
      debugPrint('[SpeechAnalyzer] Init failed: ${e.message}');
      _status = SttModelStatus.error;
      return false;
    }
  }

  // ─── Start / Stop ─────────────────────────────────────────────────────

  /// Start continuous transcription.
  void startStream() {
    if (!_isInitialized || _isListening) return;

    _method.invokeMethod<bool>(
      'start',
      <String, String>{'locale': _currentLocale},
    ).then((bool? ok) {
      if (ok == true) {
        _isListening = true;
        debugPrint('[SpeechAnalyzer] Stream started (locale=$_currentLocale)');
      }
    }).catchError((Object e) {
      debugPrint('[SpeechAnalyzer] Start failed: $e');
    });
  }

  /// Stop transcription.
  void stopStream() {
    if (!_isListening) return;

    _method.invokeMethod<bool>('stop').then((_) {
      _isListening = false;
      debugPrint('[SpeechAnalyzer] Stream stopped');
    }).catchError((Object e) {
      debugPrint('[SpeechAnalyzer] Stop failed: $e');
    });
  }

  /// Change the transcription language.
  Future<void> setLanguage(String lang) async {
    final String locale = _languageToLocale(lang);
    _currentLocale = locale;

    try {
      await _method.invokeMethod<bool>(
        'setLanguage',
        <String, String>{'locale': locale},
      );
      debugPrint('[SpeechAnalyzer] Language set to $locale');
    } on PlatformException catch (e) {
      debugPrint('[SpeechAnalyzer] setLanguage failed: ${e.message}');
    }
  }

  /// Dispose the service.
  void dispose() {
    stopStream();
    _eventSub?.cancel();
    _transcriptController.close();
  }

  // ─── EventChannel listener ────────────────────────────────────────────

  void _listenToEvents() {
    _eventSub = _events.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is! Map) return;
        final Map<Object?, Object?> data = event;
        final String type = data['type'] as String? ?? '';
        final String text = data['text'] as String? ?? '';
        final double confidence =
            (data['confidence'] as num?)?.toDouble() ?? 0.0;
        final String locale = data['locale'] as String? ?? _currentLocale;

        switch (type) {
          case 'partial':
            _transcriptController.add(SttTranscript(
              text: text,
              type: TranscriptType.partial,
              confidence: confidence,
              locale: locale,
            ));

          case 'final':
            _transcriptController.add(SttTranscript(
              text: text,
              type: TranscriptType.finalResult,
              confidence: confidence,
              locale: locale,
            ));

          case 'status':
            final String status = data['status'] as String? ?? '';
            if (status == 'listening') {
              _isListening = true;
            } else if (status == 'stopped' || status == 'done') {
              _isListening = false;
            }
            _transcriptController.add(SttTranscript(
              text: status,
              type: TranscriptType.status,
              locale: locale,
            ));
        }
      },
      onError: (Object error) {
        debugPrint('[SpeechAnalyzer] EventChannel error: $error');
      },
    );
  }

  // ─── Locale mapping ───────────────────────────────────────────────────

  static String _languageToLocale(String lang) {
    const Map<String, String> map = <String, String>{
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
    };
    // If already a full locale like 'es-CO', pass through
    if (lang.contains('-')) return lang;
    return map[lang] ?? 'es-CO';
  }
}
