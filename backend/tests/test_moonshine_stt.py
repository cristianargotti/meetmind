"""Tests for Moonshine Voice streaming STT provider."""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import numpy as np

from meetmind.providers.moonshine_stt import (
    _LANGUAGE_FALLBACK,
    MoonshineTranscriber,
    TranscriptSegment,
)

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


# ─── MoonshineTranscriber init ───────────────────────────────────


def test_init_defaults() -> None:
    """MoonshineTranscriber initializes with defaults."""
    t = MoonshineTranscriber()
    assert t.language == "es"
    assert t.on_transcript is None
    assert not t.is_running
    assert t._transcriber is None


def test_init_custom() -> None:
    """MoonshineTranscriber accepts custom parameters."""
    callback = MagicMock()
    t = MoonshineTranscriber(language="pt", on_transcript=callback)
    assert t.language == "pt"
    assert t.on_transcript is callback


def test_init_empty_language() -> None:
    """Empty language defaults to 'es'."""
    t = MoonshineTranscriber(language="")
    assert t.language == "es"


# ─── Language fallback ──────────────────────────────────────────


def test_language_fallback() -> None:
    """Portuguese falls back to English."""
    assert _LANGUAGE_FALLBACK["pt"] == "en"
    assert _LANGUAGE_FALLBACK["pt-br"] == "en"


# ─── start / stop ───────────────────────────────────────────────


@patch("meetmind.providers.moonshine_stt._get_model_for")
def test_start(mock_get_model: MagicMock) -> None:
    """Start initializes transcriber and sets running flag."""
    mock_get_model.return_value = ("/path/to/model", "arch")

    # Mock the import of moonshine_voice.transcriber
    mock_transcriber_cls = MagicMock()
    mock_transcriber_instance = MagicMock()
    mock_transcriber_cls.return_value = mock_transcriber_instance

    with patch.dict(
        "sys.modules",
        {
            "moonshine_voice": MagicMock(),
            "moonshine_voice.transcriber": MagicMock(
                Transcriber=mock_transcriber_cls,
                TranscriptEventListener=type("TranscriptEventListener", (), {}),
            ),
        },
    ):
        t = MoonshineTranscriber(language="es")
        t.start()
        assert t.is_running
        assert t._transcriber is not None


def test_start_idempotent() -> None:
    """Calling start twice is a no-op."""
    t = MoonshineTranscriber()
    t._running = True
    t.start()  # should return immediately
    assert t._transcriber is None  # didn't re-init


def test_stop() -> None:
    """Stop sets running to False and cleans up."""
    t = MoonshineTranscriber()
    mock_transcriber = MagicMock()
    t._transcriber = mock_transcriber
    t._running = True

    t.stop()

    assert not t.is_running
    assert t._transcriber is None
    mock_transcriber.stop.assert_called_once()


def test_stop_error() -> None:
    """Stop handles errors from transcriber.stop() gracefully."""
    t = MoonshineTranscriber()
    mock_transcriber = MagicMock()
    mock_transcriber.stop.side_effect = RuntimeError("cleanup error")
    t._transcriber = mock_transcriber
    t._running = True

    t.stop()  # should not raise
    assert not t.is_running
    assert t._transcriber is None


def test_stop_no_transcriber() -> None:
    """Stop works when transcriber is None."""
    t = MoonshineTranscriber()
    t._running = True
    t.stop()
    assert not t.is_running


# ─── feed_audio ──────────────────────────────────────────────────


def test_feed_audio_not_running() -> None:
    """Skips when not running."""
    t = MoonshineTranscriber()
    audio = np.zeros(1600, dtype=np.int16)
    t.feed_audio(audio.tobytes())  # should not raise


def test_feed_audio_empty() -> None:
    """Skips empty bytes."""
    t = MoonshineTranscriber()
    t._running = True
    mock = MagicMock()
    t._transcriber = mock
    t.feed_audio(b"")
    mock.add_audio.assert_not_called()


def test_feed_audio_int16_small() -> None:
    """Processes small Int16 PCM (iOS path)."""
    t = MoonshineTranscriber()
    t._running = True
    mock = MagicMock()
    t._transcriber = mock

    # 100 samples of Int16 = 200 bytes
    samples = np.zeros(100, dtype=np.int16)
    t.feed_audio(samples.tobytes())
    mock.add_audio.assert_called_once()
    call_args = mock.add_audio.call_args
    assert call_args[0][1] == 16000  # sample rate


def test_feed_audio_float32_small() -> None:
    """Processes small Float32 PCM (Chrome path)."""
    t = MoonshineTranscriber()
    t._running = True
    mock = MagicMock()
    t._transcriber = mock

    # Float32 with normalized values (will be detected as float32)
    samples = np.zeros(100, dtype=np.float32)
    t.feed_audio(samples.tobytes())
    mock.add_audio.assert_called_once()


def test_feed_audio_large_float32() -> None:
    """Processes large Float32 PCM (numpy path)."""
    t = MoonshineTranscriber()
    t._running = True
    mock = MagicMock()
    t._transcriber = mock

    # Large chunk > 6400 bytes → numpy path
    samples = np.zeros(3200, dtype=np.float32)
    t.feed_audio(samples.tobytes())
    mock.add_audio.assert_called_once()


def test_feed_audio_large_int16() -> None:
    """Processes large Int16 PCM (numpy path)."""
    t = MoonshineTranscriber()
    t._running = True
    mock = MagicMock()
    t._transcriber = mock

    # Large Int16 chunk > 6400 bytes, but not valid float32
    samples = np.full(4000, 10000, dtype=np.int16)
    t.feed_audio(samples.tobytes())
    mock.add_audio.assert_called_once()


def test_feed_audio_error() -> None:
    """Handles errors gracefully."""
    t = MoonshineTranscriber()
    t._running = True
    mock = MagicMock()
    mock.add_audio.side_effect = RuntimeError("feed error")
    t._transcriber = mock

    samples = np.zeros(100, dtype=np.int16)
    t.feed_audio(samples.tobytes())  # should not raise
