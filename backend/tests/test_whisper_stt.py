"""Tests for Whisper STT provider."""

import contextlib
from unittest.mock import MagicMock, patch

from meetmind.providers import whisper_stt
from meetmind.providers.whisper_stt import (
    TranscriptionResult,
    transcribe_audio_bytes,
    transcribe_with_speaker,
)

# We need to import faster_whisper to patch it, even if we don't use it directly here
with contextlib.suppress(ImportError):
    import faster_whisper  # noqa: F401


@patch("meetmind.providers.whisper_stt.subprocess.run")
@patch("faster_whisper.WhisperModel")
def test_transcribe_success(mock_whisper_cls: MagicMock, mock_run: MagicMock) -> None:
    """It converts audio via ffmpeg and transcribes it using Whisper."""
    # Arrange
    # Mock ffmpeg success
    mock_run.return_value.returncode = 0

    # Reset lazy-loaded model singleton to force re-init with our mock
    whisper_stt._model = None

    # Configure WhisperModel mock
    mock_instance = mock_whisper_cls.return_value
    mock_segment = MagicMock()
    mock_segment.text = "Hello world"
    mock_instance.transcribe.return_value = ([mock_segment], None)

    # Act
    # >1000 bytes to pass size check
    audio_data = b"fake_audio_data" * 100
    result = transcribe_audio_bytes(audio_data)

    # Assert
    assert result == "Hello world"

    # Verify ffmpeg called
    mock_run.assert_called_once()
    assert mock_run.call_args[0][0][0] == "ffmpeg"

    # Verify Whisper initialized and called
    mock_whisper_cls.assert_called_once()
    mock_instance.transcribe.assert_called_once()


def test_transcribe_small_audio() -> None:
    """It returns empty string for audio < 1000 bytes."""
    # Act
    result = transcribe_audio_bytes(b"small")

    # Assert
    assert result == ""


@patch("meetmind.providers.whisper_stt.subprocess.run")
def test_transcribe_ffmpeg_fail(mock_run: MagicMock) -> None:
    """It returns empty string if ffmpeg fails."""
    # Arrange
    mock_run.return_value.returncode = 1
    mock_run.return_value.stderr = b"error"

    # Act
    audio_data = b"fake_audio_data" * 100
    result = transcribe_audio_bytes(audio_data)

    # Assert
    assert result == ""


# --- TranscriptionResult ---


def test_transcription_result_default() -> None:
    """TranscriptionResult defaults speaker to 'unknown'."""
    # Act
    result = TranscriptionResult(text="hello")

    # Assert
    assert result.text == "hello"
    assert result.speaker == "unknown"


def test_transcription_result_with_speaker() -> None:
    """TranscriptionResult stores custom speaker label."""
    # Act
    result = TranscriptionResult(text="hello", speaker="SPEAKER_00")

    # Assert
    assert result.speaker == "SPEAKER_00"


def test_transcription_result_is_frozen() -> None:
    """TranscriptionResult is immutable (frozen dataclass)."""
    # Arrange
    result = TranscriptionResult(text="hello")

    # Act & Assert
    try:
        result.text = "modified"  # type: ignore[misc]
        assert False, "Should have raised"  # noqa: B011
    except AttributeError:
        pass  # Expected


# --- transcribe_with_speaker ---


def test_transcribe_with_speaker_small_audio() -> None:
    """transcribe_with_speaker returns empty for small audio."""
    # Act
    result = transcribe_with_speaker(b"small")

    # Assert
    assert result.text == ""
    assert result.speaker == "unknown"


@patch("meetmind.providers.whisper_stt._convert_webm_to_wav")
def test_transcribe_with_speaker_ffmpeg_fail(mock_convert: MagicMock) -> None:
    """transcribe_with_speaker returns empty if ffmpeg fails."""
    # Arrange
    mock_convert.return_value = None

    # Act
    audio_data = b"fake_audio_data" * 100
    result = transcribe_with_speaker(audio_data)

    # Assert
    assert result.text == ""
    assert result.speaker == "unknown"


@patch("meetmind.providers.whisper_stt._run_whisper")
@patch("meetmind.providers.whisper_stt._convert_webm_to_wav")
def test_transcribe_with_speaker_no_diarization(
    mock_convert: MagicMock,
    mock_run_whisper: MagicMock,
) -> None:
    """transcribe_with_speaker works without diarization."""
    # Arrange
    mock_webm = MagicMock()
    mock_wav = MagicMock()
    mock_convert.return_value = (mock_webm, mock_wav)
    mock_run_whisper.return_value = "Test transcription"

    # Act
    with patch("meetmind.providers.whisper_stt.settings") as mock_settings:
        mock_settings.enable_diarization = False
        audio_data = b"fake_audio_data" * 100
        result = transcribe_with_speaker(audio_data)

    # Assert
    assert result.text == "Test transcription"
    assert result.speaker == "unknown"
    mock_webm.unlink.assert_called_once_with(missing_ok=True)
    mock_wav.unlink.assert_called_once_with(missing_ok=True)


@patch("meetmind.providers.diarization.get_dominant_speaker", return_value="SPEAKER_01")
@patch("meetmind.providers.diarization.diarize_wav", return_value=[MagicMock()])
@patch("meetmind.providers.whisper_stt._run_whisper", return_value="Test transcription")
@patch("meetmind.providers.whisper_stt._convert_webm_to_wav")
def test_transcribe_with_speaker_diarization_enabled(
    mock_convert: MagicMock,
    mock_run_whisper: MagicMock,
    mock_diarize: MagicMock,
    mock_dominant: MagicMock,
) -> None:
    """transcribe_with_speaker calls diarization when enabled."""
    # Arrange
    mock_webm = MagicMock()
    mock_wav = MagicMock()
    mock_convert.return_value = (mock_webm, mock_wav)

    # Act
    with patch("meetmind.providers.whisper_stt.settings") as mock_settings:
        mock_settings.enable_diarization = True
        audio_data = b"fake_audio_data" * 100
        result = transcribe_with_speaker(audio_data)

    # Assert
    assert result.text == "Test transcription"
    assert result.speaker == "SPEAKER_01"


@patch("meetmind.providers.whisper_stt._run_whisper")
@patch("meetmind.providers.whisper_stt._convert_webm_to_wav")
def test_transcribe_with_speaker_empty_text_skips_diarization(
    mock_convert: MagicMock,
    mock_run_whisper: MagicMock,
) -> None:
    """transcribe_with_speaker skips diarization if text is empty."""
    # Arrange
    mock_webm = MagicMock()
    mock_wav = MagicMock()
    mock_convert.return_value = (mock_webm, mock_wav)
    mock_run_whisper.return_value = ""

    # Act
    with patch("meetmind.providers.whisper_stt.settings") as mock_settings:
        mock_settings.enable_diarization = True
        audio_data = b"fake_audio_data" * 100
        result = transcribe_with_speaker(audio_data)

    # Assert — empty text, diarization skipped
    assert result.text == ""
    assert result.speaker == "unknown"


@patch("meetmind.providers.whisper_stt._convert_webm_to_wav")
def test_transcribe_with_speaker_exception(mock_convert: MagicMock) -> None:
    """transcribe_with_speaker handles exceptions gracefully."""
    # Arrange
    mock_convert.side_effect = RuntimeError("crash")

    # Act
    audio_data = b"fake_audio_data" * 100
    result = transcribe_with_speaker(audio_data)

    # Assert
    assert result.text == ""
    assert result.speaker == "unknown"


@patch("meetmind.providers.whisper_stt.subprocess.run")
def test_transcribe_audio_bytes_exception(mock_run: MagicMock) -> None:
    """transcribe_audio_bytes catches unexpected exceptions."""
    # Arrange
    mock_run.side_effect = RuntimeError("ffmpeg missing")

    # Act
    audio_data = b"fake_audio_data" * 100
    result = transcribe_audio_bytes(audio_data)

    # Assert
    assert result == ""
