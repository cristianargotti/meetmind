"""Streaming STT provider — real-time subtitles using Moonshine Voice.

Architecture (sub-200ms latency pipeline):
  1. iOS/Chrome sends raw PCM audio via WebSocket every ~100ms.
  2. Per-connection MoonshineTranscriber feeds audio to Moonshine Voice.
  3. Moonshine's event system fires on_line_text_changed for partial results.
  4. Callbacks emit partial/final TranscriptSegments to the client.

Ultra-optimized for real-time:
  - update_interval=0.1s → events fire every 100ms
  - struct.unpack for Int16→Float32 (avoids numpy overhead on small chunks)
  - Direct ctypes array from struct output (skip .tolist())
"""

from __future__ import annotations

import struct
import threading
import time
from dataclasses import dataclass, field
from typing import TYPE_CHECKING, Any

import numpy as np
import structlog

if TYPE_CHECKING:
    from collections.abc import Callable


logger = structlog.get_logger(__name__)

# Per-language model cache (each language downloads once, shared across connections)
_model_cache: dict[str, tuple[str, Any]] = {}
_model_lock = threading.Lock()

# Languages that Moonshine supports natively
# Portuguese falls back to English MEDIUM_STREAMING (best multilingual model)
_LANGUAGE_FALLBACK: dict[str, str] = {
    "pt": "en",
    "pt-br": "en",
}


def _get_model_for(language: str) -> tuple[str, Any]:
    """Get or download the Moonshine model for a language. Thread-safe, cached."""
    effective_lang = _LANGUAGE_FALLBACK.get(language, language)

    if effective_lang not in _model_cache:
        with _model_lock:
            if effective_lang not in _model_cache:
                from moonshine_voice import get_model_for_language  # type: ignore[import-not-found]

                logger.info(
                    "moonshine_downloading_model",
                    requested_language=language,
                    effective_language=effective_lang,
                )

                path, arch = get_model_for_language(effective_lang)
                _model_cache[effective_lang] = (path, arch)

                logger.info(
                    "moonshine_model_ready",
                    language=effective_lang,
                    path=path,
                    arch=str(arch),
                )
    return _model_cache[effective_lang]


@dataclass
class TranscriptSegment:
    """A segment of transcribed text."""

    text: str
    is_partial: bool
    timestamp: float = field(default_factory=time.time)


class MoonshineTranscriber:
    """Per-connection real-time streaming transcriber using Moonshine Voice.

    Ultra-optimized for subtitle-like latency on c6i.xlarge (4 vCPU).
    Audio chunks arrive every ~100ms from the client.

    Args:
        language: Language code for transcription (e.g., 'es', 'en').
        on_transcript: Callback for new transcript segments.
    """

    SAMPLE_RATE = 16000

    def __init__(
        self,
        language: str = "es",
        on_transcript: Callable[[TranscriptSegment], None] | None = None,
    ) -> None:
        self.language = language or "es"
        self.on_transcript = on_transcript
        self._transcriber: Any = None
        self._running = False

    @property
    def is_running(self) -> bool:
        return self._running

    def start(self) -> None:
        """Initialize and start the Moonshine transcriber."""
        if self._running:
            return

        from moonshine_voice.transcriber import (  # type: ignore[import-not-found]
            Transcriber,
            TranscriptEventListener,
        )

        model_path, model_arch = _get_model_for(self.language)

        self._transcriber = Transcriber(
            model_path=model_path,
            model_arch=model_arch,
            update_interval=0.1,  # 100ms for real-time subtitles
            options={},
        )

        # Bridge Moonshine events → our callback system
        outer = self

        class _Listener(TranscriptEventListener):  # type: ignore[misc]
            def on_line_started(self, event: Any) -> None:
                text = getattr(getattr(event, "line", None), "text", "")
                if text and text.strip() and outer.on_transcript:
                    outer.on_transcript(TranscriptSegment(text=text.strip(), is_partial=True))

            def on_line_text_changed(self, event: Any) -> None:
                text = getattr(getattr(event, "line", None), "text", "")
                if text and text.strip() and outer.on_transcript:
                    outer.on_transcript(TranscriptSegment(text=text.strip(), is_partial=True))

            def on_line_completed(self, event: Any) -> None:
                text = getattr(getattr(event, "line", None), "text", "")
                if text and text.strip() and outer.on_transcript:
                    outer.on_transcript(TranscriptSegment(text=text.strip(), is_partial=False))

        self._transcriber.add_listener(_Listener())
        self._transcriber.start()
        self._running = True
        logger.info("moonshine_transcriber_started", language=self.language)

    def stop(self) -> None:
        """Stop the transcriber and finalize."""
        self._running = False
        if self._transcriber:
            try:
                self._transcriber.stop()
            except Exception as e:
                logger.warning("moonshine_stop_error", error=str(e))
            self._transcriber = None
        logger.info("moonshine_transcriber_stopped")

    def feed_audio(self, raw_bytes: bytes) -> None:
        """Feed raw PCM bytes — ultra-optimized path.

        iOS sends Int16 PCM (~3200 bytes every 100ms = 1600 samples).
        Chrome sends Float32 PCM (~6400 bytes every 100ms = 1600 samples).

        Optimizations applied:
          - Small chunks (≤6400 bytes): struct.unpack → list directly (no numpy)
          - Large chunks: numpy for vectorized conversion
          - Skip float32 heuristic for known-small Int16 chunks from iOS
        """
        if not self._running or not self._transcriber:
            return

        n = len(raw_bytes)
        if n == 0:
            return

        try:
            # Fast path for small Int16 chunks from iOS (99% of calls)
            # 1600 samples x 2 bytes = 3200 bytes (100ms at 16kHz)
            if n <= 6400 and n % 2 == 0:
                sample_count = n // 2
                # Check if it could be float32 (divisible by 4 and small values)
                if n % 4 == 0:
                    # Quick float32 check: peek at first 4 bytes
                    first_f32 = struct.unpack_from("<f", raw_bytes, 0)[0]
                    if -1.5 <= first_f32 <= 1.5:
                        # Float32 from Chrome — unpack directly to list
                        f32_count = n // 4
                        samples = list(struct.unpack(f"<{f32_count}f", raw_bytes))
                        self._transcriber.add_audio(samples, self.SAMPLE_RATE)
                        return

                # Int16 from iOS — struct.unpack → normalize → list
                i16_samples = struct.unpack(f"<{sample_count}h", raw_bytes)
                samples = [s / 32768.0 for s in i16_samples]
                self._transcriber.add_audio(samples, self.SAMPLE_RATE)
                return

            # Large chunk fallback: use numpy for efficiency
            if n % 4 == 0:
                pcm_f32 = np.frombuffer(raw_bytes, dtype=np.float32)
                if len(pcm_f32) > 0 and np.max(np.abs(pcm_f32)) <= 1.5:
                    self._transcriber.add_audio(pcm_f32.tolist(), self.SAMPLE_RATE)
                    return

            if n % 2 == 0:
                pcm_i16 = np.frombuffer(raw_bytes, dtype=np.int16)
                pcm_f32 = pcm_i16.astype(np.float32) / 32768.0
                self._transcriber.add_audio(pcm_f32.tolist(), self.SAMPLE_RATE)

        except Exception as e:
            logger.warning("moonshine_feed_error", error=str(e))
