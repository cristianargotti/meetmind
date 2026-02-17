import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

// ─── FFI Type Definitions ──────────────────────

/// Opaque context handle.
typedef WhisperBridgeContext = Opaque;

/// Result struct returned by transcription.
final class WhisperBridgeResultNative extends Struct {
  external Pointer<Utf8> text;

  @Int32()
  external int segments;

  @Int32()
  external int langId;

  @Float()
  external double langProb;

  @Int64()
  external int durationMs;
}

// ─── Native Function Signatures ────────────────

// Init
typedef _InitNative =
    Pointer<WhisperBridgeContext> Function(Pointer<Utf8> modelPath);
typedef _InitDart =
    Pointer<WhisperBridgeContext> Function(Pointer<Utf8> modelPath);

// Free
typedef _FreeNative = Void Function(Pointer<WhisperBridgeContext> ctx);
typedef _FreeDart = void Function(Pointer<WhisperBridgeContext> ctx);

// Set language
typedef _SetLanguageNative =
    Int32 Function(Pointer<WhisperBridgeContext> ctx, Pointer<Utf8> lang);
typedef _SetLanguageDart =
    int Function(Pointer<WhisperBridgeContext> ctx, Pointer<Utf8> lang);

// Set threads
typedef _SetThreadsNative =
    Void Function(Pointer<WhisperBridgeContext> ctx, Int32 nThreads);
typedef _SetThreadsDart =
    void Function(Pointer<WhisperBridgeContext> ctx, int nThreads);

// Transcribe
typedef _TranscribeNative =
    WhisperBridgeResultNative Function(
      Pointer<WhisperBridgeContext> ctx,
      Pointer<Float> audioData,
      Int32 audioLen,
    );
typedef _TranscribeDart =
    WhisperBridgeResultNative Function(
      Pointer<WhisperBridgeContext> ctx,
      Pointer<Float> audioData,
      int audioLen,
    );

// PCM16 to F32
typedef _Pcm16ToF32Native =
    Void Function(Pointer<Int16> src, Pointer<Float> dst, Int32 n);
typedef _Pcm16ToF32Dart =
    void Function(Pointer<Int16> src, Pointer<Float> dst, int n);

// Version
typedef _VersionNative = Pointer<Utf8> Function();
typedef _VersionDart = Pointer<Utf8> Function();

// ─── Dart Result Model ─────────────────────────

/// Transcription result from Whisper inference.
class WhisperResult {
  /// Create a WhisperResult from inference output.
  const WhisperResult({
    required this.text,
    required this.segments,
    required this.langId,
    required this.langProb,
    required this.durationMs,
  });

  /// Transcribed text.
  final String text;

  /// Number of segments.
  final int segments;

  /// Detected language ID.
  final int langId;

  /// Language detection probability.
  final double langProb;

  /// Inference duration in ms.
  final int durationMs;
}

// ─── Bindings Class ────────────────────────────

/// dart:ffi bindings to the whisper_bridge native library.
///
/// Must be used from a background [Isolate] to avoid blocking
/// the UI thread during model loading and inference.
class WhisperBindings {
  /// Load the native library for the current platform.
  WhisperBindings() : _lib = _loadLibrary();

  final DynamicLibrary _lib;

  late final _InitDart _init = _lib.lookupFunction<_InitNative, _InitDart>(
    'whisper_bridge_init',
  );

  late final _FreeDart _free = _lib.lookupFunction<_FreeNative, _FreeDart>(
    'whisper_bridge_free',
  );

  late final _SetLanguageDart _setLanguage = _lib
      .lookupFunction<_SetLanguageNative, _SetLanguageDart>(
        'whisper_bridge_set_language',
      );

  late final _SetThreadsDart _setThreads = _lib
      .lookupFunction<_SetThreadsNative, _SetThreadsDart>(
        'whisper_bridge_set_threads',
      );

  late final _TranscribeDart _transcribe = _lib
      .lookupFunction<_TranscribeNative, _TranscribeDart>(
        'whisper_bridge_transcribe',
      );

  late final _Pcm16ToF32Dart _pcm16ToF32 = _lib
      .lookupFunction<_Pcm16ToF32Native, _Pcm16ToF32Dart>(
        'whisper_bridge_pcm16_to_f32',
      );

  late final _VersionDart _version = _lib
      .lookupFunction<_VersionNative, _VersionDart>('whisper_bridge_version');

  /// Initialize whisper with a model file path.
  /// Returns context pointer (null pointer on failure).
  Pointer<WhisperBridgeContext> init(String modelPath) {
    final Pointer<Utf8> pathPtr = modelPath.toNativeUtf8();
    try {
      return _init(pathPtr);
    } finally {
      calloc.free(pathPtr);
    }
  }

  /// Free a whisper context.
  void free(Pointer<WhisperBridgeContext> ctx) {
    _free(ctx);
  }

  /// Set the transcription language (e.g., "es", "pt", "en", "auto").
  bool setLanguage(Pointer<WhisperBridgeContext> ctx, String lang) {
    final Pointer<Utf8> langPtr = lang.toNativeUtf8();
    try {
      return _setLanguage(ctx, langPtr) == 0;
    } finally {
      calloc.free(langPtr);
    }
  }

  /// Set the number of inference threads.
  void setThreads(Pointer<WhisperBridgeContext> ctx, int nThreads) {
    _setThreads(ctx, nThreads);
  }

  /// Transcribe PCM float32 audio.
  ///
  /// [audioData] must be mono 16kHz float32 samples.
  /// This is a **blocking** call — run from an [Isolate].
  WhisperResult transcribe(
    Pointer<WhisperBridgeContext> ctx,
    Float32List audioData,
  ) {
    final Pointer<Float> audioPtr = calloc<Float>(audioData.length);
    try {
      for (int i = 0; i < audioData.length; i++) {
        audioPtr[i] = audioData[i];
      }

      final WhisperBridgeResultNative result = _transcribe(
        ctx,
        audioPtr,
        audioData.length,
      );

      return WhisperResult(
        text: result.text == nullptr ? '' : result.text.toDartString(),
        segments: result.segments,
        langId: result.langId,
        langProb: result.langProb,
        durationMs: result.durationMs,
      );
    } finally {
      calloc.free(audioPtr);
    }
  }

  /// Convert PCM int16 samples to float32 (required by Whisper).
  Float32List pcm16ToFloat32(Int16List pcm16) {
    final int n = pcm16.length;
    final Pointer<Int16> srcPtr = calloc<Int16>(n);
    final Pointer<Float> dstPtr = calloc<Float>(n);

    try {
      for (int i = 0; i < n; i++) {
        srcPtr[i] = pcm16[i];
      }

      _pcm16ToF32(srcPtr, dstPtr, n);

      final Float32List result = Float32List(n);
      for (int i = 0; i < n; i++) {
        result[i] = dstPtr[i];
      }
      return result;
    } finally {
      calloc.free(srcPtr);
      calloc.free(dstPtr);
    }
  }

  /// Get the bridge version string.
  String version() {
    return _version().toDartString();
  }

  static DynamicLibrary _loadLibrary() {
    if (Platform.isIOS || Platform.isMacOS) {
      return DynamicLibrary.open('libwhisper_bridge.dylib');
    } else if (Platform.isAndroid || Platform.isLinux) {
      return DynamicLibrary.open('libwhisper_bridge.so');
    } else if (Platform.isWindows) {
      return DynamicLibrary.open('whisper_bridge.dll');
    }
    throw UnsupportedError(
      'Whisper bridge not supported on ${Platform.operatingSystem}',
    );
  }
}
