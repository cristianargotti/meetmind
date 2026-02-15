"""Unit tests for Qwen3-ASR STT provider.

Follows CRIS Development Standards:
  - TEST-001: Coverage ≥80%
  - TEST-002: AAA pattern (Arrange-Act-Assert)
  - TEST-003: Mock external dependencies
  - TEST-004: Test edge cases
"""

from __future__ import annotations

import time
from unittest.mock import MagicMock, patch

import numpy as np
import pytest

from meetmind.providers.qwen_stt import (
    MIN_AUDIO_SECONDS,
    SAMPLE_RATE,
    StreamingTranscriber,
    TranscriptSegment,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------
@pytest.fixture()
def mock_model() -> MagicMock:
    """Create a mock Qwen3-ASR model that returns predictable text."""
    model = MagicMock()
    asr_result = MagicMock()
    asr_result.text = "Hola, esto es una prueba."
    model.transcribe.return_value = [asr_result]
    return model


@pytest.fixture()
def transcriber() -> StreamingTranscriber:
    """Create a StreamingTranscriber with defaults for testing."""
    return StreamingTranscriber(
        language="es",
        on_transcript=None,
        min_transcribe_interval=0.1,
    )


# ---------------------------------------------------------------------------
# TranscriptSegment Tests
# ---------------------------------------------------------------------------
class TestTranscriptSegment:
    """Tests for the TranscriptSegment dataclass."""

    def test_create_partial_segment(self) -> None:
        """Partial segments are created with correct attributes."""
        # Arrange & Act
        segment = TranscriptSegment(text="hello", is_partial=True)

        # Assert
        assert segment.text == "hello"
        assert segment.is_partial is True
        assert segment.timestamp > 0

    def test_create_final_segment(self) -> None:
        """Final segments have is_partial=False."""
        # Arrange & Act
        segment = TranscriptSegment(text="done", is_partial=False)

        # Assert
        assert segment.text == "done"
        assert segment.is_partial is False

    def test_timestamp_auto_generated(self) -> None:
        """Timestamps are automatically set to current time."""
        # Arrange
        before = time.time()

        # Act
        segment = TranscriptSegment(text="test", is_partial=True)

        # Assert
        assert segment.timestamp >= before
        assert segment.timestamp <= time.time()


# ---------------------------------------------------------------------------
# StreamingTranscriber Tests — Initialization
# ---------------------------------------------------------------------------
class TestTranscriberInit:
    """Tests for StreamingTranscriber initialization."""

    def test_default_language(self) -> None:
        """Default language is 'es'."""
        # Arrange & Act
        t = StreamingTranscriber()

        # Assert
        assert t.language == "es"

    def test_custom_language(self) -> None:
        """Custom language is stored correctly."""
        # Arrange & Act
        t = StreamingTranscriber(language="pt")

        # Assert
        assert t.language == "pt"

    def test_none_language_defaults_to_es(self) -> None:
        """None language falls back to 'es'."""
        # Arrange & Act
        t = StreamingTranscriber(language=None)  # type: ignore[arg-type]

        # Assert
        assert t.language == "es"

    def test_not_running_by_default(self) -> None:
        """Transcriber starts in stopped state."""
        # Arrange & Act
        t = StreamingTranscriber()

        # Assert
        assert t.is_running is False


# ---------------------------------------------------------------------------
# StreamingTranscriber Tests — Audio Feeding (SEC-002 input validation)
# ---------------------------------------------------------------------------
class TestFeedAudio:
    """Tests for feed_audio input validation."""

    def test_feed_valid_audio(self, transcriber: StreamingTranscriber) -> None:
        """Valid Float32 PCM bytes are accepted and buffered."""
        # Arrange
        audio = np.zeros(1600, dtype=np.float32)
        raw_bytes = audio.tobytes()

        # Act
        transcriber.feed_audio(raw_bytes)

        # Assert
        buffer = transcriber._get_buffer_audio()
        assert buffer is not None
        assert len(buffer) == 1600

    def test_feed_empty_bytes_ignored(self, transcriber: StreamingTranscriber) -> None:
        """Empty bytes are silently ignored (SEC-002)."""
        # Arrange & Act
        transcriber.feed_audio(b"")

        # Assert
        assert transcriber._get_buffer_audio() is None

    def test_feed_invalid_bytes_ignored(self, transcriber: StreamingTranscriber) -> None:
        """Invalid byte sequences are silently ignored (SEC-002)."""
        # Arrange — 3 bytes is not a valid Float32 array
        # Act
        transcriber.feed_audio(b"\x00\x01\x02")

        # Assert — no crash, buffer stays empty
        assert transcriber._get_buffer_audio() is None

    def test_feed_multiple_chunks_concatenated(self, transcriber: StreamingTranscriber) -> None:
        """Multiple audio chunks are accumulated in order."""
        # Arrange
        chunk1 = np.ones(800, dtype=np.float32)
        chunk2 = np.full(800, 0.5, dtype=np.float32)

        # Act
        transcriber.feed_audio(chunk1.tobytes())
        transcriber.feed_audio(chunk2.tobytes())

        # Assert
        buffer = transcriber._get_buffer_audio()
        assert buffer is not None
        assert len(buffer) == 1600
        assert buffer[0] == 1.0
        assert buffer[800] == 0.5


# ---------------------------------------------------------------------------
# StreamingTranscriber Tests — Silence Detection
# ---------------------------------------------------------------------------
class TestSilenceDetection:
    """Tests for silence detection logic."""

    def test_silence_detected(self, transcriber: StreamingTranscriber) -> None:
        """Silence is detected when RMS is below threshold."""
        # Arrange — all zeros = silence
        audio = np.zeros(SAMPLE_RATE, dtype=np.float32)

        # Act & Assert
        assert transcriber._detect_silence(audio) is True

    def test_speech_not_silent(self, transcriber: StreamingTranscriber) -> None:
        """Active speech is not classified as silence."""
        # Arrange — loud signal
        audio = np.full(SAMPLE_RATE, 0.5, dtype=np.float32)

        # Act & Assert
        assert transcriber._detect_silence(audio) is False

    def test_short_audio_not_silence(self, transcriber: StreamingTranscriber) -> None:
        """Audio shorter than silence_duration is not classified as silence."""
        # Arrange — too short to evaluate
        audio = np.zeros(100, dtype=np.float32)

        # Act & Assert
        assert transcriber._detect_silence(audio) is False


# ---------------------------------------------------------------------------
# StreamingTranscriber Tests — Transcription
# ---------------------------------------------------------------------------
class TestTranscription:
    """Tests for the transcription pipeline."""

    @patch("meetmind.providers.qwen_stt._get_model")
    def test_transcribe_emits_partial(
        self, mock_get_model: MagicMock, mock_model: MagicMock
    ) -> None:
        """Transcription emits a partial segment when text changes."""
        # Arrange
        mock_get_model.return_value = mock_model
        on_transcript = MagicMock()

        t = StreamingTranscriber(
            language="es",
            on_transcript=on_transcript,
        )

        # Feed enough audio to trigger transcription
        min_samples = int(SAMPLE_RATE * MIN_AUDIO_SECONDS) + 100
        audio = np.random.randn(min_samples).astype(np.float32)
        t.feed_audio(audio.tobytes())

        # Act
        t._transcribe_buffer(finalize=False)

        # Assert
        on_transcript.assert_called_once()
        segment: TranscriptSegment = on_transcript.call_args[0][0]
        assert segment.is_partial is True
        assert segment.text == "Hola, esto es una prueba."

    @patch("meetmind.providers.qwen_stt._get_model")
    def test_transcribe_dict_result(self, mock_get_model: MagicMock) -> None:
        """Transcription handles dict-like results from model."""
        # Arrange
        model = MagicMock()
        result_obj = {"text": "Resultado dict."}
        model.transcribe.return_value = [result_obj]
        mock_get_model.return_value = model
        on_transcript = MagicMock()

        t = StreamingTranscriber(on_transcript=on_transcript)
        min_samples = int(SAMPLE_RATE * MIN_AUDIO_SECONDS) + 100
        audio = np.random.randn(min_samples).astype(np.float32)
        t.feed_audio(audio.tobytes())

        # Act
        t._transcribe_buffer(finalize=False)

        # Assert
        segment: TranscriptSegment = on_transcript.call_args[0][0]
        assert segment.text == "Resultado dict."

    @patch("meetmind.providers.qwen_stt._get_model")
    def test_transcribe_string_result(self, mock_get_model: MagicMock) -> None:
        """Transcription handles plain string results from model."""
        # Arrange
        model = MagicMock()
        model.transcribe.return_value = ["Resultado string."]
        mock_get_model.return_value = model
        on_transcript = MagicMock()

        t = StreamingTranscriber(on_transcript=on_transcript)
        min_samples = int(SAMPLE_RATE * MIN_AUDIO_SECONDS) + 100
        audio = np.random.randn(min_samples).astype(np.float32)
        t.feed_audio(audio.tobytes())

        # Act
        t._transcribe_buffer(finalize=False)

        # Assert
        segment: TranscriptSegment = on_transcript.call_args[0][0]
        assert segment.text == "Resultado string."

    @patch("meetmind.providers.qwen_stt._get_model")
    def test_transcribe_empty_result_skipped(self, mock_get_model: MagicMock) -> None:
        """Empty transcription results do not emit segments."""
        # Arrange
        model = MagicMock()
        model.transcribe.return_value = []  # empty list
        mock_get_model.return_value = model
        on_transcript = MagicMock()

        t = StreamingTranscriber(on_transcript=on_transcript)
        min_samples = int(SAMPLE_RATE * MIN_AUDIO_SECONDS) + 100
        audio = np.random.randn(min_samples).astype(np.float32)
        t.feed_audio(audio.tobytes())

        # Act
        t._transcribe_buffer(finalize=False)

        # Assert
        on_transcript.assert_not_called()

    @patch("meetmind.providers.qwen_stt._get_model")
    def test_duplicate_text_not_emitted(
        self, mock_get_model: MagicMock, mock_model: MagicMock
    ) -> None:
        """Same text is not emitted twice (dedup)."""
        # Arrange
        mock_get_model.return_value = mock_model
        on_transcript = MagicMock()

        t = StreamingTranscriber(on_transcript=on_transcript)
        min_samples = int(SAMPLE_RATE * MIN_AUDIO_SECONDS) + 100
        audio = np.random.randn(min_samples).astype(np.float32)
        t.feed_audio(audio.tobytes())

        # Act — transcribe twice with same model output
        t._transcribe_buffer(finalize=False)
        t._transcribe_buffer(finalize=False)

        # Assert — only emitted once
        assert on_transcript.call_count == 1


# ---------------------------------------------------------------------------
# StreamingTranscriber Tests — Lifecycle
# ---------------------------------------------------------------------------
class TestLifecycle:
    """Tests for start/stop lifecycle."""

    def test_start_sets_running(self) -> None:
        """Start sets the running state."""
        # Arrange
        t = StreamingTranscriber()

        # Act
        t.start()

        # Assert
        assert t.is_running is True

        # Cleanup
        t._running = False

    def test_double_start_is_noop(self) -> None:
        """Calling start twice does not create a second thread."""
        # Arrange
        t = StreamingTranscriber()

        # Act
        t.start()
        thread1 = t._thread
        t.start()
        thread2 = t._thread

        # Assert
        assert thread1 is thread2

        # Cleanup
        t._running = False

    def test_stop_clears_running(self) -> None:
        """Stop clears the running state."""
        # Arrange
        t = StreamingTranscriber()
        t._running = True

        # Act
        t.stop()

        # Assert
        assert t.is_running is False


# ---------------------------------------------------------------------------
# StreamingTranscriber Tests — Buffer Management
# ---------------------------------------------------------------------------
class TestBufferManagement:
    """Tests for buffer operations."""

    def test_get_buffer_empty(self, transcriber: StreamingTranscriber) -> None:
        """Empty buffer returns None."""
        # Arrange & Act & Assert
        assert transcriber._get_buffer_audio() is None

    def test_reset_buffer(self, transcriber: StreamingTranscriber) -> None:
        """Reset clears all audio chunks."""
        # Arrange
        audio = np.zeros(1600, dtype=np.float32)
        transcriber.feed_audio(audio.tobytes())

        # Act
        transcriber._reset_buffer()

        # Assert
        assert transcriber._get_buffer_audio() is None
