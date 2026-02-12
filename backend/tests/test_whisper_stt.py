"""Tests for Whisper STT provider."""

from unittest.mock import MagicMock, patch

from meetmind.providers.whisper_stt import transcribe_audio_bytes, _get_model
from meetmind.providers import whisper_stt

# We need to import faster_whisper to patch it, even if we don't use it directly here
try:
    import faster_whisper  # noqa: F401
except ImportError:
    pass


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
