"""Streaming STT provider — ultra-low-latency using faster-whisper.

Architecture (sub-1s latency pipeline):
  1. Chrome Extension sends raw Float32 PCM at 16kHz via AudioContext.
  2. Per-connection StreamingTranscriber accumulates PCM in numpy buffer.
  3. Background thread runs Whisper every ~0.5s on the buffer.
  4. Diffs against previous output → emits partial/final callbacks.

No ffmpeg, no WebM encoding/decoding — pure PCM → Whisper pipeline.
"""

from __future__ import annotations

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

# Global model (shared across all connections)
_model: Any = None
_model_lock = threading.Lock()


def _get_model() -> Any:
    """Lazy-load the faster-whisper model (thread-safe singleton)."""
    global _model
    if _model is None:
        with _model_lock:
            if _model is None:
                from faster_whisper import WhisperModel  # type: ignore[import-untyped]

                logger.info("streaming_stt_loading_model", size=settings.whisper_model)
                _model = WhisperModel(
                    settings.whisper_model,
                    device="cpu",
                    compute_type="int8",
                    cpu_threads=4,
                )
                logger.info("streaming_stt_model_loaded", size=settings.whisper_model)
    return _model


@dataclass
class TranscriptSegment:
    """A segment of transcribed text."""

    text: str
    is_partial: bool
    timestamp: float = field(default_factory=time.time)


class StreamingTranscriber:
    """Per-connection ultra-low-latency streaming transcriber.

    Accepts raw Float32 PCM at 16kHz directly from the Chrome Extension
    (sent via AudioContext ScriptProcessor). No encoding/decoding overhead.

    Args:
        language: Language code for Whisper (e.g., 'es', 'pt').
        on_transcript: Callback for new transcript segments.
        min_transcribe_interval: Min seconds between Whisper runs.
        silence_threshold: RMS threshold for silence detection.
        silence_duration: Seconds of silence before finalizing a segment.
        max_buffer_seconds: Max audio buffer size (OOM protection).
    """

    SAMPLE_RATE = 16000

    def __init__(
        self,
        language: str = "es",
        on_transcript: Callable[[TranscriptSegment], None] | None = None,
        min_transcribe_interval: float = 0.5,
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
        self._running = True
        self._segment_start_time = time.time()
        self._thread = threading.Thread(target=self._transcription_loop, daemon=True)
        self._thread.start()
        logger.info("streaming_transcriber_started", language=self.language)

    def stop(self) -> None:
        """Stop the transcription thread and finalize."""
        self._running = False
        if self._thread:
            self._thread.join(timeout=5)
            self._thread = None

        # Final flush
        self._transcribe_buffer(finalize=True)
        logger.info("streaming_transcriber_stopped")

    def feed_audio(self, raw_bytes: bytes) -> None:
        """Feed raw PCM bytes — auto-detects Int16 (iOS) or Float32 (Chrome).

        iOS Flutter sends Int16 PCM (2 bytes/sample, range -32768..32767).
        Chrome Extension sends Float32 PCM (4 bytes/sample, range -1.0..1.0).
        faster-whisper expects Float32 normalized to [-1.0, 1.0].
        """
        try:
            n = len(raw_bytes)
            if n == 0:
                return

            # Heuristic: try Float32 first if divisible by 4
            if n % 4 == 0:
                pcm_f32 = np.frombuffer(raw_bytes, dtype=np.float32)
                # Float32 audio from Chrome is always in [-1.0, 1.0]
                max_abs = np.max(np.abs(pcm_f32)) if len(pcm_f32) > 0 else 0
                if max_abs <= 1.5:
                    # Confirmed Float32 from Chrome Extension
                    with self._buffer_lock:
                        self._audio_chunks.append(pcm_f32)
                    return

            # Int16 PCM from iOS (or Float32 that looked like garbage)
            if n % 2 == 0:
                pcm_i16 = np.frombuffer(raw_bytes, dtype=np.int16)
                # Normalize Int16 → Float32 [-1.0, 1.0]
                pcm_f32 = pcm_i16.astype(np.float32) / 32768.0
                with self._buffer_lock:
                    self._audio_chunks.append(pcm_f32)
                return

        except ValueError:
            pass  # Skip malformed buffers

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
        tail = audio[-tail_samples:]
        rms = float(np.sqrt(np.mean(tail.astype(np.float32) ** 2)))
        return rms < self.silence_threshold

    def _finalize_and_reset(self) -> None:
        """Finalize current text as a paragraph and reset buffer."""
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

    def _transcription_loop(self) -> None:
        """Background loop: transcribe buffered audio at high frequency.

        Creates paragraph breaks via:
        - Silence detection (natural pauses)
        - Periodic forced finalization (max_segment_seconds)
        - Buffer overflow protection
        """
        while self._running:
            now = time.time()
            elapsed = now - self._last_transcribe_time

            if elapsed >= self.min_transcribe_interval:
                audio = self._get_buffer_audio()
                if audio is not None and len(audio) > self.SAMPLE_RATE * 0.3:
                    is_silence = self._detect_silence(audio)
                    segment_age = now - self._segment_start_time
                    audio_seconds = len(audio) / self.SAMPLE_RATE

                    # Determine if we should force-finalize
                    should_finalize = (
                        is_silence
                        or segment_age > self.max_segment_seconds
                        or audio_seconds > self.max_buffer_seconds
                    )

                    # Run Whisper
                    self._transcribe_buffer(finalize=should_finalize)
                    self._last_transcribe_time = now

                    # Reset buffer after finalization
                    if should_finalize and self._last_text:
                        self._finalize_and_reset()

            time.sleep(0.1)  # Check ~10 times per second

    def _transcribe_buffer(self, finalize: bool = False) -> None:
        """Run Whisper on the current PCM buffer.

        Updates self._last_text. Emits partial transcript if text changed
        and we're not about to finalize (finals come from _finalize_and_reset).
        """
        audio = self._get_buffer_audio()
        if audio is None or len(audio) < self.SAMPLE_RATE * 0.3:
            return

        try:
            model = _get_model()
            segments, _info = model.transcribe(
                audio,
                language=self.language,
                beam_size=1,
                vad_filter=True,
                vad_parameters={
                    "min_silence_duration_ms": 300,
                    "speech_pad_ms": 200,
                },
            )

            full_text = " ".join(seg.text.strip() for seg in segments).strip()

            if not full_text:
                return

            # Only update and emit partial if text changed and not finalizing
            if full_text != self._last_text:
                self._last_text = full_text
                if not finalize and self.on_transcript:
                    self.on_transcript(TranscriptSegment(text=full_text, is_partial=True))

        except Exception as e:
            logger.error("streaming_transcribe_error", error=str(e))
