"""Tests for streaming STT provider."""

from unittest.mock import MagicMock, patch

import numpy as np

import pytest
from meetmind.providers.streaming_stt import StreamingTranscriber, TranscriptSegment

faster_whisper = pytest.importorskip("faster_whisper")


def test_transcript_segment_creation() -> None:
    """TranscriptSegment stores text, partial flag, and timestamp."""
    # Act
    segment = TranscriptSegment(text="hello world", is_partial=True)

    # Assert
    assert segment.text == "hello world"
    assert segment.is_partial is True
    assert isinstance(segment.timestamp, float)


def test_transcript_segment_final() -> None:
    """TranscriptSegment can be a final (non-partial) result."""
    # Act
    segment = TranscriptSegment(text="final text", is_partial=False)

    # Assert
    assert segment.is_partial is False


def test_streaming_transcriber_init_defaults() -> None:
    """StreamingTranscriber initializes with default values."""
    # Act
    transcriber = StreamingTranscriber()

    # Assert
    assert transcriber.language == "es"
    assert transcriber.min_transcribe_interval == 0.5
    assert transcriber.silence_threshold == 0.01
    assert transcriber.silence_duration == 0.5
    assert transcriber.max_buffer_seconds == 30.0
    assert transcriber.max_segment_seconds == 15.0
    assert not transcriber.is_running


def test_streaming_transcriber_init_custom() -> None:
    """StreamingTranscriber accepts custom parameters."""
    # Arrange
    callback = MagicMock()

    # Act
    transcriber = StreamingTranscriber(
        language="pt",
        on_transcript=callback,
        min_transcribe_interval=1.0,
        silence_threshold=0.05,
        silence_duration=1.0,
        max_buffer_seconds=60.0,
        max_segment_seconds=30.0,
    )

    # Assert
    assert transcriber.language == "pt"
    assert transcriber.on_transcript is callback
    assert transcriber.min_transcribe_interval == 1.0
    assert transcriber.silence_threshold == 0.05
    assert transcriber.max_buffer_seconds == 60.0


def test_streaming_transcriber_init_none_language() -> None:
    """Empty language string defaults to 'es'."""
    # Act
    transcriber = StreamingTranscriber(language="")

    # Assert
    assert transcriber.language == "es"


def test_streaming_transcriber_start_stop() -> None:
    """Start/stop lifecycle works without errors."""
    # Arrange
    transcriber = StreamingTranscriber()

    # Act
    with patch.object(transcriber, "_transcription_loop"):
        transcriber.start()
        assert transcriber.is_running

        transcriber.stop()
        assert not transcriber.is_running


def test_streaming_transcriber_start_idempotent() -> None:
    """Calling start multiple times doesn't create multiple threads."""
    # Arrange
    transcriber = StreamingTranscriber()

    # Act
    with patch.object(transcriber, "_transcription_loop"):
        transcriber.start()
        first_thread = transcriber._thread
        transcriber.start()  # second call should be no-op

    # Assert
    assert transcriber._thread is first_thread

    # Cleanup
    transcriber._running = False


def test_streaming_transcriber_feed_audio() -> None:
    """feed_audio() accepts Float32 PCM bytes."""
    # Arrange
    transcriber = StreamingTranscriber()
    audio = np.zeros(1600, dtype=np.float32)  # 0.1s of silence

    # Act
    transcriber.feed_audio(audio.tobytes())

    # Assert
    assert len(transcriber._audio_chunks) == 1
    assert len(transcriber._audio_chunks[0]) == 1600


def test_streaming_transcriber_feed_audio_malformed() -> None:
    """feed_audio() handles malformed bytes gracefully."""
    # Arrange
    transcriber = StreamingTranscriber()

    # Act — odd-length bytes can't be a valid Float32 buffer
    transcriber.feed_audio(b"\x01\x02\x03")

    # Assert — malformed buffer is silently skipped
    assert len(transcriber._audio_chunks) == 0


def test_streaming_transcriber_feed_audio_empty() -> None:
    """feed_audio() skips zero-length arrays."""
    # Arrange
    transcriber = StreamingTranscriber()
    empty_audio = np.array([], dtype=np.float32)

    # Act
    transcriber.feed_audio(empty_audio.tobytes())

    # Assert — empty is not appended
    assert len(transcriber._audio_chunks) == 0


def test_get_buffer_audio_empty() -> None:
    """_get_buffer_audio returns None when no audio is buffered."""
    # Arrange
    transcriber = StreamingTranscriber()

    # Act & Assert
    assert transcriber._get_buffer_audio() is None


def test_get_buffer_audio_concatenates() -> None:
    """_get_buffer_audio concatenates multiple chunks."""
    # Arrange
    transcriber = StreamingTranscriber()
    chunk1 = np.ones(800, dtype=np.float32)
    chunk2 = np.ones(800, dtype=np.float32) * 0.5
    transcriber._audio_chunks = [chunk1, chunk2]

    # Act
    result = transcriber._get_buffer_audio()

    # Assert
    assert result is not None
    assert len(result) == 1600


def test_reset_buffer() -> None:
    """_reset_buffer clears all audio chunks."""
    # Arrange
    transcriber = StreamingTranscriber()
    transcriber._audio_chunks = [np.zeros(800, dtype=np.float32)]

    # Act
    transcriber._reset_buffer()

    # Assert
    assert len(transcriber._audio_chunks) == 0


def test_detect_silence_true() -> None:
    """_detect_silence returns True for silent audio."""
    # Arrange
    transcriber = StreamingTranscriber(silence_threshold=0.01, silence_duration=0.5)
    # 1 second of near-silence
    audio = np.zeros(16000, dtype=np.float32)

    # Act
    result = transcriber._detect_silence(audio)

    # Assert
    assert result is True


def test_detect_silence_false_loud() -> None:
    """_detect_silence returns False for loud audio."""
    # Arrange
    transcriber = StreamingTranscriber(silence_threshold=0.01)
    # Loud sine wave
    audio = np.sin(np.linspace(0, 10 * np.pi, 16000)).astype(np.float32)

    # Act
    result = transcriber._detect_silence(audio)

    # Assert
    assert result is False


def test_detect_silence_short_audio() -> None:
    """_detect_silence returns False for audio shorter than silence_duration."""
    # Arrange
    transcriber = StreamingTranscriber(silence_duration=1.0)
    # Only 0.1s of audio
    audio = np.zeros(1600, dtype=np.float32)

    # Act
    result = transcriber._detect_silence(audio)

    # Assert — too short to make a determination
    assert result is False


def test_finalize_and_reset_with_text() -> None:
    """_finalize_and_reset emits final segment and clears buffer."""
    # Arrange
    callback = MagicMock()
    transcriber = StreamingTranscriber(on_transcript=callback)
    transcriber._last_text = "hello world"
    transcriber._audio_chunks = [np.zeros(800, dtype=np.float32)]

    # Act
    transcriber._finalize_and_reset()

    # Assert
    callback.assert_called_once()
    segment = callback.call_args[0][0]
    assert segment.text == "hello world"
    assert segment.is_partial is False
    assert transcriber._last_text == ""
    assert len(transcriber._audio_chunks) == 0


def test_finalize_and_reset_without_text() -> None:
    """_finalize_and_reset does nothing when no text is accumulated."""
    # Arrange
    callback = MagicMock()
    transcriber = StreamingTranscriber(on_transcript=callback)
    transcriber._last_text = ""

    # Act
    transcriber._finalize_and_reset()

    # Assert — callback not called
    callback.assert_not_called()


def test_finalize_and_reset_no_callback() -> None:
    """_finalize_and_reset works even without a callback."""
    # Arrange
    transcriber = StreamingTranscriber(on_transcript=None)
    transcriber._last_text = "some text"

    # Act — should not raise
    transcriber._finalize_and_reset()

    # Assert
    assert transcriber._last_text == ""


def test_transcribe_buffer_too_short() -> None:
    """_transcribe_buffer does nothing for very short audio."""
    # Arrange
    transcriber = StreamingTranscriber()
    # 0.1s of audio (< 0.3s threshold)
    transcriber._audio_chunks = [np.zeros(1600, dtype=np.float32)]

    # Act — should return early without calling model
    transcriber._transcribe_buffer()

    # Assert
    assert transcriber._last_text == ""


def test_transcribe_buffer_empty() -> None:
    """_transcribe_buffer does nothing for empty buffer."""
    # Arrange
    transcriber = StreamingTranscriber()

    # Act — should return early
    transcriber._transcribe_buffer()

    # Assert
    assert transcriber._last_text == ""


@patch("meetmind.providers.streaming_stt._get_model")
def test_transcribe_buffer_success(mock_get_model: MagicMock) -> None:
    """_transcribe_buffer runs Whisper and updates last_text."""
    # Arrange
    mock_model = MagicMock()
    mock_segment = MagicMock()
    mock_segment.text = " Hola mundo "
    mock_model.transcribe.return_value = ([mock_segment], None)
    mock_get_model.return_value = mock_model

    callback = MagicMock()
    transcriber = StreamingTranscriber(on_transcript=callback)
    # 1s of audio (> 0.3s threshold)
    transcriber._audio_chunks = [np.zeros(16000, dtype=np.float32)]

    # Act
    transcriber._transcribe_buffer(finalize=False)

    # Assert
    assert transcriber._last_text == "Hola mundo"
    mock_model.transcribe.assert_called_once()
    # Partial should be emitted since finalize=False
    callback.assert_called_once()
    assert callback.call_args[0][0].is_partial is True


@patch("meetmind.providers.streaming_stt._get_model")
def test_transcribe_buffer_finalize_no_partial(mock_get_model: MagicMock) -> None:
    """_transcribe_buffer with finalize=True doesn't emit partial."""
    # Arrange
    mock_model = MagicMock()
    mock_segment = MagicMock()
    mock_segment.text = " Final text "
    mock_model.transcribe.return_value = ([mock_segment], None)
    mock_get_model.return_value = mock_model

    callback = MagicMock()
    transcriber = StreamingTranscriber(on_transcript=callback)
    transcriber._audio_chunks = [np.zeros(16000, dtype=np.float32)]

    # Act
    transcriber._transcribe_buffer(finalize=True)

    # Assert — no partial emitted (finals come from _finalize_and_reset)
    callback.assert_not_called()
    assert transcriber._last_text == "Final text"


@patch("meetmind.providers.streaming_stt._get_model")
def test_transcribe_buffer_whisper_error(mock_get_model: MagicMock) -> None:
    """_transcribe_buffer handles Whisper exceptions gracefully."""
    # Arrange
    mock_get_model.return_value.transcribe.side_effect = RuntimeError("model crash")
    transcriber = StreamingTranscriber()
    transcriber._audio_chunks = [np.zeros(16000, dtype=np.float32)]

    # Act — should not raise
    transcriber._transcribe_buffer()

    # Assert
    assert transcriber._last_text == ""


@patch("meetmind.providers.streaming_stt._get_model")
def test_transcribe_buffer_empty_result(mock_get_model: MagicMock) -> None:
    """_transcribe_buffer handles empty Whisper results."""
    # Arrange
    mock_model = MagicMock()
    mock_model.transcribe.return_value = ([], None)
    mock_get_model.return_value = mock_model

    transcriber = StreamingTranscriber()
    transcriber._audio_chunks = [np.zeros(16000, dtype=np.float32)]

    # Act
    transcriber._transcribe_buffer()

    # Assert — no text update
    assert transcriber._last_text == ""
