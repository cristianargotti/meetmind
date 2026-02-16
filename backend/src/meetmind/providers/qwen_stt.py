"""Streaming STT provider — Qwen3-ASR 0.6B (Alibaba).

Architecture (sub-300ms latency pipeline):
  1. Chrome Extension sends raw Float32 PCM at 16kHz via AudioContext.
  2. Per-connection StreamingTranscriber accumulates PCM in numpy buffer.
  3. Background thread runs Qwen3-ASR every ~0.3s on the buffer.
  4. Diffs against previous output → emits partial/final callbacks.

Qwen3-ASR advantages:
  - 52 languages (ES, PT, EN, FR, DE, etc.)
  - 600MB model (lightweight, fast Docker images)
  - Streaming + offline unified mode
  - Apache 2.0 license (free for commercial use)
  - Clean API via ``qwen-asr`` package
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

# ---------------------------------------------------------------------------
# Constants (no magic numbers — CRIS standard)
# ---------------------------------------------------------------------------
SAMPLE_RATE: int = 16_000
"""Audio sample rate in Hz expected by Qwen3-ASR."""

MIN_AUDIO_SECONDS: float = 0.3
"""Minimum buffered audio (seconds) before running transcription."""

THREAD_POLL_INTERVAL: float = 0.05
"""Background thread polling interval (seconds) — ~20 checks/sec."""

MODEL_LOAD_TIMEOUT_SECONDS: float = 120.0
"""Maximum time to wait for model loading before raising an error."""

# Qwen3-ASR requires full language names, not ISO codes.
LANGUAGE_MAP: dict[str, str] = {
    "es": "Spanish",
    "pt": "Portuguese",
    "en": "English",
    "fr": "French",
    "de": "German",
    "it": "Italian",
    "ja": "Japanese",
    "ko": "Korean",
    "zh": "Chinese",
    "ru": "Russian",
    "ar": "Arabic",
    "hi": "Hindi",
    "th": "Thai",
    "vi": "Vietnamese",
    "tr": "Turkish",
    "nl": "Dutch",
    "pl": "Polish",
    "sv": "Swedish",
    "da": "Danish",
    "fi": "Finnish",
    "id": "Indonesian",
    "ms": "Malay",
    "cs": "Czech",
    "ro": "Romanian",
    "el": "Greek",
    "hu": "Hungarian",
    "fa": "Persian",
    "tl": "Filipino",
    "mk": "Macedonian",
}
"""Maps ISO 639-1 codes to Qwen3-ASR full language names."""

# ---------------------------------------------------------------------------
# Lazy model singleton (thread-safe)
# ---------------------------------------------------------------------------
_model: Any = None
_model_lock = threading.Lock()


def _detect_device() -> tuple[str, Any]:
    """Auto-detect best device and dtype for Qwen3-ASR inference.

    CUDA for production GPU, CPU for local dev.
    MPS skipped — benchmarks showed no speedup for autoregressive generation.

    Returns:
        Tuple of (device_map, dtype).
    """
    import torch

    if torch.cuda.is_available():
        return "cuda", torch.float16
    return "cpu", torch.float32


def _extract_text(result: Any) -> str:
    """Extract text from an ASRTranscription result object.

    Handles multiple return types for robustness:
    objects with ``.text``, plain strings, dicts, and fallback ``str()``.

    Args:
        result: Single result from ``model.transcribe()``.

    Returns:
        Extracted and stripped text string.
    """
    if hasattr(result, "text"):
        return str(result.text).strip()
    if isinstance(result, str):
        return result.strip()
    if isinstance(result, dict):
        return str(result.get("text", "")).strip()
    return str(result).strip()


def _get_model() -> Any:
    """Lazy-load the Qwen3-ASR model (thread-safe singleton).

    Uses the ``qwen-asr`` package with ``transformers`` backend.
    Model is downloaded on first use and cached by HuggingFace.

    Returns:
        Loaded Qwen3-ASR model instance.

    Raises:
        RuntimeError: If model fails to load within timeout.
    """
    global _model
    if _model is None:
        with _model_lock:
            if _model is None:
                try:
                    import concurrent.futures

                    from qwen_asr import Qwen3ASRModel  # type: ignore[import-untyped]

                    model_name = settings.qwen_asr_model
                    device_map, dtype = _detect_device()

                    logger.info(
                        "qwen_stt_loading_model",
                        model=model_name,
                        device=device_map,
                        dtype=str(dtype),
                    )

                    # PERF-002: Enforce timeout on model download/load
                    def _load() -> Any:
                        return Qwen3ASRModel.from_pretrained(
                            model_name,
                            max_new_tokens=512,
                            device_map=device_map,
                            dtype=dtype,
                        )

                    with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
                        future = pool.submit(_load)
                        _model = future.result(timeout=MODEL_LOAD_TIMEOUT_SECONDS)

                    logger.info("qwen_stt_model_loaded", model=model_name, device=device_map)
                except ImportError as exc:
                    logger.error(
                        "qwen_stt_import_error",
                        error=str(exc),
                        hint="Install with: pip install qwen-asr",
                    )
                    raise RuntimeError(
                        "qwen-asr package not installed. Run: pip install qwen-asr"
                    ) from exc
                except concurrent.futures.TimeoutError:
                    logger.error(
                        "qwen_stt_load_timeout",
                        timeout_seconds=MODEL_LOAD_TIMEOUT_SECONDS,
                    )
                    raise RuntimeError(
                        f"Qwen3-ASR model loading timed out after {MODEL_LOAD_TIMEOUT_SECONDS}s"
                    ) from None
    return _model


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------
@dataclass
class TranscriptSegment:
    """A segment of transcribed text with metadata.

    Attributes:
        text: The transcribed text content.
        is_partial: Whether this is a partial (in-progress) or final transcript.
        timestamp: Unix timestamp when the segment was created.
    """

    text: str
    is_partial: bool
    timestamp: float = field(default_factory=time.time)


# ---------------------------------------------------------------------------
# Streaming transcriber
# ---------------------------------------------------------------------------
class StreamingTranscriber:
    """Per-connection streaming transcriber using Qwen3-ASR 0.6B.

    Accepts raw Float32 PCM at 16kHz directly from the Chrome Extension
    (sent via AudioContext ScriptProcessor). No encoding/decoding overhead.

    Follows CRIS Development Standards:
      - SEC-002: Input validation on audio bytes
      - DOC-001/002: Full docstrings and type hints
      - PERF-002: Timeout-protected model loading
      - OBS-001: Structured logging throughout
      - No generic exception catches
      - No magic numbers (all constants named)

    Args:
        language: Language code for transcription (e.g., 'es', 'pt', 'en').
        on_transcript: Callback invoked with new transcript segments.
        min_transcribe_interval: Minimum seconds between transcription runs.
        silence_threshold: RMS amplitude threshold for silence detection.
        silence_duration: Seconds of continuous silence before finalizing.
        max_buffer_seconds: Maximum audio buffer size (OOM protection).
        max_segment_seconds: Maximum seconds before forced segment finalization.
    """

    def __init__(
        self,
        language: str = "es",
        on_transcript: Callable[[TranscriptSegment], None] | None = None,
        min_transcribe_interval: float = 0.3,
        silence_threshold: float = 0.01,
        silence_duration: float = 0.5,
        max_buffer_seconds: float = 30.0,
        max_segment_seconds: float = 15.0,
    ) -> None:
        """Initialize the streaming transcriber."""
        self.language = language or "es"
        self.on_transcript = on_transcript
        self.min_transcribe_interval = min_transcribe_interval
        self.silence_threshold = silence_threshold
        self.silence_duration = silence_duration
        self.max_buffer_seconds = max_buffer_seconds
        self.max_segment_seconds = max_segment_seconds

        # PCM audio buffer (Float32, 16kHz mono)
        self._audio_chunks: list[np.ndarray[Any, Any]] = []
        self._buffer_lock = threading.Lock()

        # Transcription state
        self._last_text: str = ""
        self._last_transcribe_time: float = 0.0
        self._segment_start_time: float = 0.0

        # Thread control
        self._running: bool = False
        self._thread: threading.Thread | None = None

    @property
    def is_running(self) -> bool:
        """Whether the transcriber is currently active."""
        return self._running

    def start(self) -> None:
        """Start the background transcription thread.

        Spawns a daemon thread that polls the audio buffer and runs
        Qwen3-ASR transcription at the configured interval.
        """
        if self._running:
            return
        self._running = True
        self._segment_start_time = time.time()
        self._thread = threading.Thread(
            target=self._transcription_loop,
            daemon=True,
            name="qwen-stt-worker",
        )
        self._thread.start()
        logger.info(
            "qwen_transcriber_started",
            language=self.language,
            model=settings.qwen_asr_model,
        )

    def stop(self) -> None:
        """Stop the transcription thread and finalize any remaining text.

        Blocks up to 5 seconds waiting for the background thread to
        finish, then flushes any remaining audio through transcription.
        """
        self._running = False
        if self._thread is not None:
            self._thread.join(timeout=5)
            self._thread = None

        # Final flush
        self._transcribe_buffer(finalize=True)
        logger.info("qwen_transcriber_stopped")

    def feed_audio(self, raw_bytes: bytes) -> None:
        """Feed raw Float32 PCM bytes from the Chrome Extension.

        The extension sends raw ArrayBuffer from Float32Array via
        AudioContext ScriptProcessor — no encoding, just raw samples.

        Args:
            raw_bytes: Raw PCM audio bytes (Float32, 16kHz mono).

        Note:
            Invalid or empty buffers are silently skipped (SEC-002).
        """
        if not raw_bytes:
            return

        try:
            pcm = np.frombuffer(raw_bytes, dtype=np.float32)
        except ValueError:
            logger.warning(
                "qwen_stt_invalid_audio",
                byte_count=len(raw_bytes),
            )
            return

        if len(pcm) > 0:
            with self._buffer_lock:
                self._audio_chunks.append(pcm)

    # ------------------------------------------------------------------
    # Private methods
    # ------------------------------------------------------------------

    def _get_buffer_audio(self) -> np.ndarray[Any, Any] | None:
        """Get all buffered audio as a single contiguous array.

        Returns:
            Concatenated audio array, or None if buffer is empty.
        """
        with self._buffer_lock:
            if not self._audio_chunks:
                return None
            audio: np.ndarray[Any, Any] = np.concatenate(self._audio_chunks)
        return audio

    def _reset_buffer(self) -> None:
        """Clear the audio buffer after finalizing a segment."""
        with self._buffer_lock:
            self._audio_chunks.clear()

    def _detect_silence(self, audio: np.ndarray[Any, Any]) -> bool:
        """Check if the tail of the audio buffer is silence.

        Args:
            audio: Full audio buffer to analyze.

        Returns:
            True if the tail RMS is below the silence threshold.
        """
        tail_samples = int(self.silence_duration * SAMPLE_RATE)
        if len(audio) < tail_samples:
            return False
        tail = audio[-tail_samples:]
        rms = float(np.sqrt(np.mean(tail**2)))
        return rms < self.silence_threshold

    def _finalize_and_reset(self) -> None:
        """Finalize current text as a completed segment and reset buffer."""
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
          - Buffer overflow protection (max_buffer_seconds)
        """
        while self._running:
            now = time.time()
            elapsed = now - self._last_transcribe_time

            if elapsed >= self.min_transcribe_interval:
                audio = self._get_buffer_audio()
                min_samples = int(SAMPLE_RATE * MIN_AUDIO_SECONDS)

                if audio is not None and len(audio) > min_samples:
                    is_silence = self._detect_silence(audio)
                    segment_age = now - self._segment_start_time
                    audio_seconds = len(audio) / SAMPLE_RATE

                    should_finalize = (
                        is_silence
                        or segment_age > self.max_segment_seconds
                        or audio_seconds > self.max_buffer_seconds
                    )

                    self._transcribe_buffer(finalize=should_finalize)
                    self._last_transcribe_time = now

                    if should_finalize and self._last_text:
                        self._finalize_and_reset()

            time.sleep(THREAD_POLL_INTERVAL)

    def _transcribe_buffer(self, *, finalize: bool = False) -> None:
        """Run Qwen3-ASR on the current PCM buffer.

        Updates ``self._last_text``. Emits partial transcript if text
        changed and we're not about to finalize.

        Args:
            finalize: If True, this is a final transcription for the segment.
        """
        audio = self._get_buffer_audio()
        min_samples = int(SAMPLE_RATE * MIN_AUDIO_SECONDS)
        if audio is None or len(audio) < min_samples:
            return

        try:
            model = _get_model()
            qwen_language = LANGUAGE_MAP.get(self.language.lower(), self.language.capitalize())
            results = model.transcribe((audio, SAMPLE_RATE), language=qwen_language)

            if not results:
                return

            full_text = _extract_text(results[0])
            if not full_text:
                return

            # Only emit partial if text actually changed
            if full_text != self._last_text:
                self._last_text = full_text
                if not finalize and self.on_transcript:
                    self.on_transcript(TranscriptSegment(text=full_text, is_partial=True))

        except RuntimeError:
            # Model loading failed — already logged in _get_model
            raise
        except FileNotFoundError as exc:
            logger.error("qwen_stt_file_error", error=str(exc))
        except OSError as exc:
            logger.error("qwen_stt_io_error", error=str(exc))
