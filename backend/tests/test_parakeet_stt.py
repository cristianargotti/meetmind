"""Tests for Parakeet TDT streaming STT provider."""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import numpy as np

from meetmind.providers.parakeet_stt import StreamingTranscriber, TranscriptSegment

# ─── TranscriptSegment ───────────────────────────────────────────


def test_segment_creation() -> None:
    """TranscriptSegment stores text, partial flag, and timestamp."""
    segment = TranscriptSegment(text="hello", is_partial=True)
    assert segment.text == "hello"
    assert segment.is_partial is True
    assert isinstance(segment.timestamp, float)


def test_segment_final() -> None:
    """TranscriptSegment can be a final result."""
    segment = TranscriptSegment(text="final", is_partial=False)
    assert segment.is_partial is False


# ─── StreamingTranscriber init ───────────────────────────────────


def test_init_defaults() -> None:
    """StreamingTranscriber initializes with defaults."""
    with patch("meetmind.providers.parakeet_stt._get_model"):
        t = StreamingTranscriber()
    assert t.language == "es"
    assert t.min_transcribe_interval == 0.15
    assert t.silence_threshold == 0.01
    assert t.silence_duration == 0.5
    assert t.max_buffer_seconds == 30.0
    assert t.max_segment_seconds == 15.0
    assert not t.is_running


def test_init_custom() -> None:
    """StreamingTranscriber accepts custom parameters."""
    callback = MagicMock()
    with patch("meetmind.providers.parakeet_stt._get_model"):
        t = StreamingTranscriber(
            language="pt",
            on_transcript=callback,
            min_transcribe_interval=1.0,
            silence_threshold=0.05,
            silence_duration=1.0,
            max_buffer_seconds=60.0,
            max_segment_seconds=30.0,
        )
    assert t.language == "pt"
    assert t.on_transcript is callback
    assert t.min_transcribe_interval == 1.0


def test_init_empty_language() -> None:
    """Empty language defaults to 'es'."""
    with patch("meetmind.providers.parakeet_stt._get_model"):
        t = StreamingTranscriber(language="")
    assert t.language == "es"


# ─── start/stop ──────────────────────────────────────────────────


def test_start_stop() -> None:
    """Start/stop lifecycle works."""
    with patch("meetmind.providers.parakeet_stt._get_model"):
        t = StreamingTranscriber()
        with patch.object(t, "_transcription_loop"):
            t.start()
            assert t.is_running
            t.stop()
            assert not t.is_running


def test_start_idempotent() -> None:
    """Calling start twice doesn't create multiple threads."""
    with patch("meetmind.providers.parakeet_stt._get_model"):
        t = StreamingTranscriber()
        with patch.object(t, "_transcription_loop"):
            t.start()
            first_thread = t._thread
            t.start()
            assert t._thread is first_thread
            t._running = False


# ─── feed_audio ──────────────────────────────────────────────────


def test_feed_audio_int16() -> None:
    """feed_audio handles Int16 PCM (iOS format)."""
    with patch("meetmind.providers.parakeet_stt._get_model"):
        t = StreamingTranscriber()
    t._running = True
    audio = np.zeros(1600, dtype=np.int16)
    t.feed_audio(audio.tobytes())
    assert len(t._audio_chunks) == 1


def test_feed_audio_float32() -> None:
    """feed_audio handles Float32 PCM (Chrome format)."""
    with patch("meetmind.providers.parakeet_stt._get_model"):
        t = StreamingTranscriber()
    t._running = True
    audio = np.zeros(1600, dtype=np.float32)
    t.feed_audio(audio.tobytes())
    assert len(t._audio_chunks) == 1


def test_feed_audio_not_running() -> None:
    """feed_audio skips when not running."""
    with patch("meetmind.providers.parakeet_stt._get_model"):
        t = StreamingTranscriber()
    audio = np.zeros(1600, dtype=np.float32)
    t.feed_audio(audio.tobytes())
    assert len(t._audio_chunks) == 0


def test_feed_audio_too_short() -> None:
    """feed_audio skips bytes shorter than 4."""
    with patch("meetmind.providers.parakeet_stt._get_model"):
        t = StreamingTranscriber()
    t._running = True
    t.feed_audio(b"\x01\x02")
    assert len(t._audio_chunks) == 0


# ─── buffer operations ──────────────────────────────────────────


def test_get_buffer_audio_empty() -> None:
    """Returns None when buffer is empty."""
    with patch("meetmind.providers.parakeet_stt._get_model"):
        t = StreamingTranscriber()
    assert t._get_buffer_audio() is None


def test_get_buffer_audio_concatenates() -> None:
    """Concatenates multiple chunks."""
    with patch("meetmind.providers.parakeet_stt._get_model"):
        t = StreamingTranscriber()
    chunk1 = np.ones(800, dtype=np.float32)
    chunk2 = np.ones(800, dtype=np.float32) * 0.5
    t._audio_chunks = [chunk1, chunk2]
    result = t._get_buffer_audio()
    assert result is not None
    assert len(result) == 1600


def test_reset_buffer() -> None:
    """Clears audio chunks."""
    with patch("meetmind.providers.parakeet_stt._get_model"):
        t = StreamingTranscriber()
    t._audio_chunks = [np.zeros(800, dtype=np.float32)]
    t._reset_buffer()
    assert len(t._audio_chunks) == 0


# ─── silence detection ──────────────────────────────────────────


def test_detect_silence_true() -> None:
    """Returns True for silent audio."""
    with patch("meetmind.providers.parakeet_stt._get_model"):
        t = StreamingTranscriber(silence_threshold=0.01, silence_duration=0.5)
    audio = np.zeros(16000, dtype=np.float32)
    assert t._detect_silence(audio) is True


def test_detect_silence_false_loud() -> None:
    """Returns False for loud audio."""
    with patch("meetmind.providers.parakeet_stt._get_model"):
        t = StreamingTranscriber(silence_threshold=0.01)
    audio = np.sin(np.linspace(0, 10 * np.pi, 16000)).astype(np.float32)
    assert t._detect_silence(audio) is False


def test_detect_silence_short() -> None:
    """Returns False for audio shorter than silence_duration."""
    with patch("meetmind.providers.parakeet_stt._get_model"):
        t = StreamingTranscriber(silence_duration=1.0)
    audio = np.zeros(1600, dtype=np.float32)
    assert t._detect_silence(audio) is False


# ─── finalize ────────────────────────────────────────────────────


def test_finalize_and_reset_with_text() -> None:
    """Emits final segment and clears buffer."""
    callback = MagicMock()
    with patch("meetmind.providers.parakeet_stt._get_model"):
        t = StreamingTranscriber(on_transcript=callback)
    t._last_text = "hello"
    t._audio_chunks = [np.zeros(800, dtype=np.float32)]
    t._finalize_and_reset()
    callback.assert_called_once()
    segment = callback.call_args[0][0]
    assert segment.is_partial is False
    assert t._last_text == ""


def test_finalize_and_reset_no_text() -> None:
    """Does nothing when no text."""
    callback = MagicMock()
    with patch("meetmind.providers.parakeet_stt._get_model"):
        t = StreamingTranscriber(on_transcript=callback)
    t._last_text = ""
    t._finalize_and_reset()
    callback.assert_not_called()


# ─── sentence detection ──────────────────────────────────────────


def test_ends_with_sentence_true() -> None:
    """Detects sentence-ending punctuation."""
    assert StreamingTranscriber._ends_with_sentence("Hello world.") is True
    assert StreamingTranscriber._ends_with_sentence("Really?") is True
    assert StreamingTranscriber._ends_with_sentence("Wow!") is True


def test_ends_with_sentence_false() -> None:
    """Returns False for incomplete sentences."""
    assert StreamingTranscriber._ends_with_sentence("Hello world") is False
    assert StreamingTranscriber._ends_with_sentence("Hello,") is False


# ─── _transcribe_buffer ─────────────────────────────────────────


@patch("meetmind.providers.parakeet_stt._get_model")
def test_transcribe_buffer_empty(mock_model: MagicMock) -> None:
    """Does nothing for empty buffer."""
    t = StreamingTranscriber()
    t._transcribe_buffer()
    assert t._last_text == ""


@patch("meetmind.providers.parakeet_stt._get_model")
def test_transcribe_buffer_too_short(mock_model: MagicMock) -> None:
    """Does nothing for very short audio."""
    t = StreamingTranscriber()
    t._audio_chunks = [np.zeros(1000, dtype=np.float32)]
    t._transcribe_buffer()
    assert t._last_text == ""


@patch("meetmind.providers.parakeet_stt._get_model")
def test_transcribe_buffer_success(mock_model: MagicMock) -> None:
    """Transcribes audio and emits partial."""
    model = MagicMock()
    model.recognize.return_value = "Hola mundo"
    mock_model.return_value = model

    callback = MagicMock()
    t = StreamingTranscriber(on_transcript=callback)
    t._audio_chunks = [np.zeros(16000, dtype=np.float32)]
    t._transcribe_buffer()

    assert t._last_text == "Hola mundo"
    callback.assert_called_once()
    assert callback.call_args[0][0].is_partial is True


@patch("meetmind.providers.parakeet_stt._get_model")
def test_transcribe_buffer_list_result(mock_model: MagicMock) -> None:
    """Handles list result format from onnx-asr."""
    model = MagicMock()
    model.recognize.return_value = ["Result text", "other"]
    mock_model.return_value = model

    t = StreamingTranscriber()
    t._audio_chunks = [np.zeros(16000, dtype=np.float32)]
    t._transcribe_buffer()
    assert t._last_text == "Result text"


@patch("meetmind.providers.parakeet_stt._get_model")
def test_transcribe_buffer_error(mock_model: MagicMock) -> None:
    """Handles transcription errors gracefully."""
    model = MagicMock()
    model.recognize.side_effect = RuntimeError("model error")
    mock_model.return_value = model

    t = StreamingTranscriber()
    t._audio_chunks = [np.zeros(16000, dtype=np.float32)]
    t._transcribe_buffer()
    assert t._last_text == ""
