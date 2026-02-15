"""Streaming STT provider — ultra-low-latency using NVIDIA Parakeet TDT v3.

Architecture (sub-100ms latency pipeline):
  1. iOS/Chrome sends raw PCM audio via WebSocket every ~100ms.
  2. Per-connection StreamingTranscriber accumulates PCM in numpy buffer.
  3. Background thread runs Parakeet every ~0.15s on the buffer.
  4. Diffs against previous output → emits partial/final callbacks.

Parakeet TDT v3 via onnx-asr advantages:
  - 30x real-time on CPU (i7), INT8 quantized
  - ONNX runtime only — NO PyTorch dependency
  - 25 European languages natively (ES, PT, EN, FR, DE, IT...)
  - ~1.25GB FP16 model, ~800MB INT8
  - CC-BY-4.0 license (free for commercial use)
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

from meetmind.config.settings import settings

logger = structlog.get_logger(__name__)

# Global model (shared across all connections, thread-safe)
_model: Any = None
_model_lock = threading.Lock()


def _get_model() -> Any:
    """Lazy-load the Parakeet TDT model via onnx-asr (thread-safe singleton)."""
    global _model
    if _model is None:
        with _model_lock:
            if _model is None:
                import onnx_asr  # type: ignore[import-untyped]

                model_name = getattr(settings, "parakeet_model", "nemo-parakeet-tdt-0.6b-v3")
                quantization = getattr(settings, "parakeet_quantization", "int8")

                logger.info(
                    "parakeet_stt_loading_model",
                    model=model_name,
                    quantization=quantization,
                )

                _model = onnx_asr.load_model(model_name, quantization=quantization)

                logger.info("parakeet_stt_model_loaded", model=model_name)
    return _model


@dataclass
class TranscriptSegment:
    """A segment of transcribed text."""

    text: str
    is_partial: bool
    timestamp: float = field(default_factory=time.time)


class StreamingTranscriber:
    """Per-connection streaming transcriber using Parakeet TDT via onnx-asr.

    Ultra-optimized for real-time subtitles. Accepts raw PCM audio from
    iOS (Int16) or Chrome (Float32) and runs Parakeet inference on buffered
    audio at high frequency.

    Args:
        language: Language code (e.g., 'es', 'pt', 'en'). Parakeet auto-detects
                 from the 25 supported European languages.
        on_transcript: Callback for new transcript segments.
        min_transcribe_interval: Min seconds between transcription runs.
        silence_threshold: RMS threshold for silence detection.
        silence_duration: Seconds of silence before finalizing a segment.
        max_buffer_seconds: Max audio buffer size (OOM protection).
        max_segment_seconds: Max seconds before forced segment finalization.
    """

    SAMPLE_RATE = 16000

    def __init__(
        self,
        language: str = "es",
        on_transcript: Callable[[TranscriptSegment], None] | None = None,
        min_transcribe_interval: float = 0.15,
        silence_threshold: float = 0.01,
        silence_duration: float = 0.5,
        max_buffer_seconds: float = 30.0,
        max_segment_seconds: float = 15.0,
    ) -> None:
        self.language = language or "es"
        self.on_transcript = on_transcript
        self.min_transcribe_interval = min_transcribe_interval
        self.silence_threshold = silence_threshold
        self.silence_duration = silence_duration
        self.max_buffer_seconds = max_buffer_seconds
        self.max_segment_seconds = max_segment_seconds

        # PCM audio buffer (Float32, 16kHz mono)
        self._audio_chunks: list[np.ndarray] = []
        self._buffer_lock = threading.Lock()

        # Transcription state
        self._last_text = ""
        self._last_transcribe_time = 0.0
        self._segment_start_time = 0.0

        # Thread control
        self._running = False
        self._thread: threading.Thread | None = None

    @property
    def is_running(self) -> bool:
        """Whether the transcriber is currently running."""
        return self._running

    def start(self) -> None:
        """Start the background transcription thread."""
        if self._running:
            return

        # Pre-load model on start (blocks briefly but avoids first-request latency)
        _get_model()

        self._running = True
        self._segment_start_time = time.time()
        self._thread = threading.Thread(target=self._transcription_loop, daemon=True)
        self._thread.start()
        logger.info(
            "parakeet_transcriber_started",
            language=self.language,
        )

    def stop(self) -> None:
        """Stop the transcription thread and finalize."""
        self._running = False
        if self._thread:
            self._thread.join(timeout=5)
            self._thread = None

        # Final flush
        self._transcribe_buffer(finalize=True)
        logger.info("parakeet_transcriber_stopped")

    def feed_audio(self, raw_bytes: bytes) -> None:
        """Feed raw PCM bytes — Int16 from iOS, Float32 from Chrome.

        Always converts to normalized Float32 [-1.0, 1.0] for the buffer.
        Default assumption: Int16 (iOS is the primary client).
        """
        if not self._running:
            return

        n = len(raw_bytes)
        if n < 4:
            return

        try:
            # Default: treat as Int16 (iOS sends Int16 PCM at 16kHz)
            # Only use Float32 if ALL samples are in normalized range
            pcm: np.ndarray

            if n % 4 == 0:
                # Could be Float32 — check if values are normalized
                candidate = np.frombuffer(raw_bytes, dtype=np.float32)
                if len(candidate) > 0 and np.all(np.abs(candidate) <= 1.0):
                    # Confirmed Float32 normalized audio (Chrome)
                    pcm = candidate.copy()
                elif n % 2 == 0:
                    # Not normalized → must be Int16
                    pcm = np.frombuffer(raw_bytes, dtype=np.int16).astype(np.float32) / 32768.0
                else:
                    return
            elif n % 2 == 0:
                # Odd 4-byte alignment → definitely Int16
                pcm = np.frombuffer(raw_bytes, dtype=np.int16).astype(np.float32) / 32768.0
            else:
                return

            if len(pcm) > 0:
                with self._buffer_lock:
                    self._audio_chunks.append(pcm)
        except Exception as e:
            logger.warning("parakeet_feed_error", error=str(e))

    def _get_buffer_audio(self) -> np.ndarray | None:
        """Get all buffered audio as a single contiguous array."""
        with self._buffer_lock:
            if not self._audio_chunks:
                return None
            audio = np.concatenate(self._audio_chunks)
        return audio

    def _reset_buffer(self) -> None:
        """Clear the audio buffer after finalizing a segment."""
        with self._buffer_lock:
            self._audio_chunks.clear()

    def _detect_silence(self, audio: np.ndarray) -> bool:
        """Check if the tail of the audio is silence."""
        tail_samples = int(self.silence_duration * self.SAMPLE_RATE)
        if len(audio) < tail_samples:
            return False
        tail = audio[-tail_samples:].astype(np.float64)  # prevent overflow
        rms = float(np.sqrt(np.mean(tail * tail)))
        return rms < self.silence_threshold

    def _finalize_and_reset(self) -> None:
        """Finalize current text as a complete paragraph and reset buffer."""
        if self._last_text:
            segment = TranscriptSegment(
                text=self._last_text,
                is_partial=False,
            )
            if self.on_transcript:
                self.on_transcript(segment)
        self._last_text = ""
        self._reset_buffer()
        self._segment_start_time = time.time()

    @staticmethod
    def _ends_with_sentence(text: str) -> bool:
        """Check if text ends at a natural sentence boundary.

        Parakeet TDT v3 outputs punctuation and capitalization natively,
        so we can use sentence-ending marks to find natural break points.
        """
        stripped = text.rstrip()
        return stripped.endswith((".", "?", "!", "…"))

    def _transcription_loop(self) -> None:
        """Background loop: transcribe buffered audio at high frequency.

        Smart paragraph breaks:
        - Silence + sentence ending → finalize (natural paragraph)
        - Max segment time → finalize at next sentence boundary
        - Buffer overflow → forced finalize (safety)

        This ensures paragraphs are always complete sentences,
        never cut mid-phrase.
        """
        while self._running:
            now = time.time()
            elapsed = now - self._last_transcribe_time

            if elapsed >= self.min_transcribe_interval:
                audio = self._get_buffer_audio()
                if audio is not None and len(audio) > self.SAMPLE_RATE * 0.15:
                    is_silence = self._detect_silence(audio)
                    segment_age = now - self._segment_start_time
                    audio_seconds = len(audio) / self.SAMPLE_RATE

                    # Run transcription first to get latest text
                    self._transcribe_buffer()
                    self._last_transcribe_time = now

                    # Smart finalization: prefer sentence boundaries
                    ends_sentence = self._ends_with_sentence(self._last_text)

                    should_finalize = False
                    if audio_seconds > self.max_buffer_seconds:
                        # Safety: always finalize on buffer overflow
                        should_finalize = True
                    elif is_silence and ends_sentence:
                        # Natural break: silence + complete sentence
                        should_finalize = True
                    elif segment_age > self.max_segment_seconds and ends_sentence:
                        # Long segment: finalize at next sentence end
                        should_finalize = True
                    elif is_silence and segment_age > 3.0:
                        # Extended silence after 3s: finalize even mid-sentence
                        should_finalize = True

                    if should_finalize and self._last_text:
                        self._finalize_and_reset()

            time.sleep(0.03)  # ~33Hz check rate

    def _transcribe_buffer(self) -> None:
        """Run Parakeet TDT on the current PCM buffer via onnx-asr.

        onnx-asr accepts numpy float32 arrays directly — no temp files.
        INT8 quantized model gives ~30x real-time on 4-core CPU.
        """
        audio = self._get_buffer_audio()
        if audio is None or len(audio) < self.SAMPLE_RATE * 0.15:
            return

        try:
            model = _get_model()

            # onnx-asr accepts numpy float32 arrays directly
            result = model.recognize(audio, sample_rate=self.SAMPLE_RATE)

            # Handle result format
            if isinstance(result, str):
                full_text = result.strip()
            elif isinstance(result, list) and len(result) > 0:
                full_text = str(result[0]).strip()
            else:
                full_text = str(result).strip() if result else ""

            if not full_text:
                return

            if full_text != self._last_text:
                self._last_text = full_text
                if self.on_transcript:
                    self.on_transcript(TranscriptSegment(text=full_text, is_partial=True))

        except Exception as e:
            logger.error("parakeet_transcribe_error", error=str(e))

