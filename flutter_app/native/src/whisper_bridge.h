/**
 * whisper_bridge.h — C API for dart:ffi integration.
 *
 * Exposes a minimal, thread-safe interface for:
 *   - Model initialization and cleanup
 *   - Single-shot transcription (batch)
 *   - Streaming transcription (real-time)
 *   - Language configuration
 *
 * All functions use C linkage (no C++ name mangling) for FFI.
 */

#ifndef WHISPER_BRIDGE_H
#define WHISPER_BRIDGE_H

#include <stdint.h>

#ifdef _WIN32
#ifdef WHISPER_BRIDGE_EXPORTS
#define BRIDGE_API __declspec(dllexport)
#else
#define BRIDGE_API __declspec(dllimport)
#endif
#else
#define BRIDGE_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Opaque handle to a whisper bridge context.
 * Contains the whisper model, state, and configuration.
 */
typedef struct whisper_bridge_context whisper_bridge_context;

/**
 * Result of a transcription operation.
 */
typedef struct {
    const char *text;        /**< Transcribed text (owned by context, valid until next call) */
    int32_t    segments;     /**< Number of segments transcribed */
    int32_t    lang_id;      /**< Detected language ID */
    float      lang_prob;    /**< Language detection probability (0.0-1.0) */
    int64_t    duration_ms;  /**< Inference duration in milliseconds */
} whisper_bridge_result;

/**
 * Streaming segment callback.
 * Called for each new segment during real-time transcription.
 *
 * @param text    Transcribed text for this segment
 * @param is_partial  1 if partial (may change), 0 if finalized
 * @param user_data   User-provided context pointer
 */
typedef void (*whisper_bridge_segment_callback)(
    const char *text,
    int32_t is_partial,
    void *user_data
);

/* ─── Lifecycle ─────────────────────────────── */

/**
 * Initialize a whisper bridge context with a model file.
 *
 * @param model_path  Path to the ggml model file (e.g., ggml-base.bin)
 * @return Context handle, or NULL on failure
 */
BRIDGE_API whisper_bridge_context *whisper_bridge_init(const char *model_path);

/**
 * Free a whisper bridge context and release all resources.
 *
 * @param ctx  Context to free (safe to pass NULL)
 */
BRIDGE_API void whisper_bridge_free(whisper_bridge_context *ctx);

/* ─── Configuration ─────────────────────────── */

/**
 * Set the transcription language.
 *
 * @param ctx   Context handle
 * @param lang  Language code: "es", "pt", "en", or "auto" for detection
 * @return 0 on success, -1 on invalid language
 */
BRIDGE_API int32_t whisper_bridge_set_language(
    whisper_bridge_context *ctx,
    const char *lang
);

/**
 * Set the number of processing threads.
 *
 * @param ctx       Context handle
 * @param n_threads Number of threads (default: 4)
 */
BRIDGE_API void whisper_bridge_set_threads(
    whisper_bridge_context *ctx,
    int32_t n_threads
);

/* ─── Batch Transcription ───────────────────── */

/**
 * Transcribe an audio buffer (single-shot).
 *
 * Audio must be PCM float32, mono, 16kHz sample rate.
 * This is a blocking call — run from a background thread/isolate.
 *
 * @param ctx          Context handle
 * @param audio_data   PCM float32 audio samples
 * @param audio_len    Number of samples
 * @return Result struct (text valid until next transcribe call or free)
 */
BRIDGE_API whisper_bridge_result whisper_bridge_transcribe(
    whisper_bridge_context *ctx,
    const float *audio_data,
    int32_t audio_len
);

/* ─── Streaming ─────────────────────────────── */

/**
 * Start streaming mode for real-time transcription.
 *
 * @param ctx       Context handle
 * @param callback  Segment callback (called from inference thread)
 * @param user_data User-provided context for callback
 * @return 0 on success, -1 on failure
 */
BRIDGE_API int32_t whisper_bridge_stream_start(
    whisper_bridge_context *ctx,
    whisper_bridge_segment_callback callback,
    void *user_data
);

/**
 * Push audio data into the streaming buffer.
 *
 * Audio must be PCM float32, mono, 16kHz sample rate.
 * When enough audio accumulates (step_ms), inference runs automatically.
 *
 * @param ctx          Context handle
 * @param audio_data   PCM float32 audio samples
 * @param audio_len    Number of samples
 * @return 0 on success, -1 on failure
 */
BRIDGE_API int32_t whisper_bridge_stream_push(
    whisper_bridge_context *ctx,
    const float *audio_data,
    int32_t audio_len
);

/**
 * Stop streaming mode and finalize any pending audio.
 *
 * @param ctx  Context handle
 * @return Final transcription result
 */
BRIDGE_API whisper_bridge_result whisper_bridge_stream_stop(
    whisper_bridge_context *ctx
);

/* ─── Utilities ─────────────────────────────── */

/**
 * Convert PCM int16 audio to float32 (required by whisper).
 *
 * @param src  Int16 PCM samples
 * @param dst  Float32 output buffer (must be pre-allocated, same length)
 * @param n    Number of samples
 */
BRIDGE_API void whisper_bridge_pcm16_to_f32(
    const int16_t *src,
    float *dst,
    int32_t n
);

/**
 * Get the whisper.cpp version string.
 *
 * @return Version string (e.g., "1.7.4")
 */
BRIDGE_API const char *whisper_bridge_version(void);

#ifdef __cplusplus
}
#endif

#endif /* WHISPER_BRIDGE_H */
