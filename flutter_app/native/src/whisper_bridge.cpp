/**
 * whisper_bridge.cpp — Whisper.cpp bridge implementation for dart:ffi.
 *
 * Thread-safe wrapper around whisper.cpp providing:
 *   - Model lifecycle management
 *   - Batch and streaming transcription
 *   - Ring buffer for real-time audio
 *   - PCM format conversion
 */

#include "whisper_bridge.h"
#include "whisper.h"

#include <cstring>
#include <mutex>
#include <string>
#include <vector>
#include <chrono>

/* ─── Internal Context ──────────────────────── */

struct whisper_bridge_context {
    struct whisper_context *wctx;
    std::mutex             mtx;
    std::string            language;
    int32_t                n_threads;

    // Streaming state
    bool                                  streaming;
    std::vector<float>                    stream_buffer;
    whisper_bridge_segment_callback       stream_callback;
    void                                 *stream_user_data;
    int32_t                               stream_step_samples; // samples per step

    // Last result storage (keeps text alive between calls)
    std::string                           last_result_text;

    whisper_bridge_context()
        : wctx(nullptr)
        , language("auto")
        , n_threads(4)
        , streaming(false)
        , stream_callback(nullptr)
        , stream_user_data(nullptr)
        , stream_step_samples(16000 * 2) // 2 seconds at 16kHz
    {}
};

/* ─── Helpers ───────────────────────────────── */

static whisper_full_params make_params(const whisper_bridge_context *ctx) {
    whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);

    params.n_threads   = ctx->n_threads;
    params.no_context  = true;
    params.single_segment = false;
    params.print_special  = false;
    params.print_progress = false;
    params.print_realtime = false;
    params.print_timestamps = false;
    params.translate    = false;
    params.no_timestamps = true;

    // Language
    if (ctx->language == "auto") {
        params.language = nullptr;  // auto-detect
        params.detect_language = true;
    } else {
        params.language = ctx->language.c_str();
        params.detect_language = false;
    }

    // Speed optimizations for real-time
    params.greedy.best_of = 1;

    return params;
}

static whisper_bridge_result make_result(
    whisper_bridge_context *ctx,
    int n_segments,
    int lang_id,
    float lang_prob,
    int64_t duration_ms
) {
    // Build full text from segments
    ctx->last_result_text.clear();
    for (int i = 0; i < n_segments; i++) {
        const char *seg_text = whisper_full_get_segment_text(ctx->wctx, i);
        if (seg_text) {
            if (!ctx->last_result_text.empty()) {
                ctx->last_result_text += " ";
            }
            ctx->last_result_text += seg_text;
        }
    }

    whisper_bridge_result result;
    result.text        = ctx->last_result_text.c_str();
    result.segments    = n_segments;
    result.lang_id     = lang_id;
    result.lang_prob   = lang_prob;
    result.duration_ms = duration_ms;
    return result;
}

/* ─── Lifecycle ─────────────────────────────── */

BRIDGE_API whisper_bridge_context *whisper_bridge_init(const char *model_path) {
    if (!model_path) {
        return nullptr;
    }

    struct whisper_context_params cparams = whisper_context_default_params();
    cparams.use_gpu = true;

    struct whisper_context *wctx = whisper_init_from_file_with_params(
        model_path, cparams
    );

    if (!wctx) {
        return nullptr;
    }

    auto *ctx = new whisper_bridge_context();
    ctx->wctx = wctx;
    return ctx;
}

BRIDGE_API void whisper_bridge_free(whisper_bridge_context *ctx) {
    if (!ctx) return;

    std::lock_guard<std::mutex> lock(ctx->mtx);
    if (ctx->wctx) {
        whisper_free(ctx->wctx);
        ctx->wctx = nullptr;
    }
    delete ctx;
}

/* ─── Configuration ─────────────────────────── */

BRIDGE_API int32_t whisper_bridge_set_language(
    whisper_bridge_context *ctx,
    const char *lang
) {
    if (!ctx || !lang) return -1;

    std::lock_guard<std::mutex> lock(ctx->mtx);

    // Validate language
    if (strcmp(lang, "auto") == 0) {
        ctx->language = "auto";
        return 0;
    }

    int lang_id = whisper_lang_id(lang);
    if (lang_id < 0) {
        return -1;  // Invalid language code
    }

    ctx->language = lang;
    return 0;
}

BRIDGE_API void whisper_bridge_set_threads(
    whisper_bridge_context *ctx,
    int32_t n_threads
) {
    if (!ctx) return;
    std::lock_guard<std::mutex> lock(ctx->mtx);
    ctx->n_threads = (n_threads > 0) ? n_threads : 4;
}

/* ─── Batch Transcription ───────────────────── */

BRIDGE_API whisper_bridge_result whisper_bridge_transcribe(
    whisper_bridge_context *ctx,
    const float *audio_data,
    int32_t audio_len
) {
    whisper_bridge_result empty = { "", 0, -1, 0.0f, 0 };
    if (!ctx || !audio_data || audio_len <= 0) return empty;

    std::lock_guard<std::mutex> lock(ctx->mtx);

    auto start = std::chrono::high_resolution_clock::now();

    whisper_full_params params = make_params(ctx);

    int ret = whisper_full(ctx->wctx, params, audio_data, audio_len);
    if (ret != 0) {
        return empty;
    }

    auto end = std::chrono::high_resolution_clock::now();
    int64_t duration_ms = std::chrono::duration_cast<std::chrono::milliseconds>(
        end - start
    ).count();

    int n_segments = whisper_full_n_segments(ctx->wctx);
    int lang_id = whisper_full_lang_id(ctx->wctx);
    float lang_prob = 0.0f;

    return make_result(ctx, n_segments, lang_id, lang_prob, duration_ms);
}

/* ─── Streaming ─────────────────────────────── */

BRIDGE_API int32_t whisper_bridge_stream_start(
    whisper_bridge_context *ctx,
    whisper_bridge_segment_callback callback,
    void *user_data
) {
    if (!ctx || !callback) return -1;

    std::lock_guard<std::mutex> lock(ctx->mtx);
    ctx->streaming = true;
    ctx->stream_callback = callback;
    ctx->stream_user_data = user_data;
    ctx->stream_buffer.clear();
    return 0;
}

BRIDGE_API int32_t whisper_bridge_stream_push(
    whisper_bridge_context *ctx,
    const float *audio_data,
    int32_t audio_len
) {
    if (!ctx || !audio_data || audio_len <= 0) return -1;

    std::lock_guard<std::mutex> lock(ctx->mtx);
    if (!ctx->streaming) return -1;

    // Append to ring buffer
    ctx->stream_buffer.insert(
        ctx->stream_buffer.end(),
        audio_data,
        audio_data + audio_len
    );

    // Process when we have enough audio (step_samples)
    if (static_cast<int32_t>(ctx->stream_buffer.size()) >= ctx->stream_step_samples) {
        whisper_full_params params = make_params(ctx);
        params.single_segment = true;

        int ret = whisper_full(
            ctx->wctx, params,
            ctx->stream_buffer.data(),
            static_cast<int>(ctx->stream_buffer.size())
        );

        if (ret == 0) {
            int n_seg = whisper_full_n_segments(ctx->wctx);
            for (int i = 0; i < n_seg; i++) {
                const char *text = whisper_full_get_segment_text(ctx->wctx, i);
                if (text && ctx->stream_callback) {
                    ctx->stream_callback(text, 0, ctx->stream_user_data);
                }
            }
        }

        // Keep last 0.5s for context overlap
        int keep = 16000 / 2;  // 8000 samples = 0.5s
        if (static_cast<int>(ctx->stream_buffer.size()) > keep) {
            ctx->stream_buffer.erase(
                ctx->stream_buffer.begin(),
                ctx->stream_buffer.end() - keep
            );
        }
    }

    return 0;
}

BRIDGE_API whisper_bridge_result whisper_bridge_stream_stop(
    whisper_bridge_context *ctx
) {
    whisper_bridge_result empty = { "", 0, -1, 0.0f, 0 };
    if (!ctx) return empty;

    std::lock_guard<std::mutex> lock(ctx->mtx);
    ctx->streaming = false;

    // Process remaining buffer
    if (!ctx->stream_buffer.empty()) {
        whisper_full_params params = make_params(ctx);

        auto start = std::chrono::high_resolution_clock::now();

        int ret = whisper_full(
            ctx->wctx, params,
            ctx->stream_buffer.data(),
            static_cast<int>(ctx->stream_buffer.size())
        );

        auto end = std::chrono::high_resolution_clock::now();
        int64_t duration_ms = std::chrono::duration_cast<std::chrono::milliseconds>(
            end - start
        ).count();

        if (ret == 0) {
            int n_seg = whisper_full_n_segments(ctx->wctx);
            int lang_id = whisper_full_lang_id(ctx->wctx);

            // Fire final callbacks
            for (int i = 0; i < n_seg; i++) {
                const char *text = whisper_full_get_segment_text(ctx->wctx, i);
                if (text && ctx->stream_callback) {
                    ctx->stream_callback(text, 0, ctx->stream_user_data);
                }
            }

            ctx->stream_buffer.clear();
            ctx->stream_callback = nullptr;
            ctx->stream_user_data = nullptr;

            return make_result(ctx, n_seg, lang_id, 0.0f, duration_ms);
        }
    }

    ctx->stream_buffer.clear();
    ctx->stream_callback = nullptr;
    ctx->stream_user_data = nullptr;
    return empty;
}

/* ─── Utilities ─────────────────────────────── */

BRIDGE_API void whisper_bridge_pcm16_to_f32(
    const int16_t *src,
    float *dst,
    int32_t n
) {
    if (!src || !dst || n <= 0) return;
    for (int32_t i = 0; i < n; i++) {
        dst[i] = static_cast<float>(src[i]) / 32768.0f;
    }
}

BRIDGE_API const char *whisper_bridge_version(void) {
    return "1.0.0-meetmind";
}
