"""Unit tests for Qwen3-ASR model loading and transcription edge cases.

Follows CRIS Development Standards:
  - TEST-001: Coverage ≥80%
  - TEST-002: AAA pattern (Arrange-Act-Assert)
  - TEST-003: Mock external dependencies
  - TEST-004: Test edge cases
"""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import numpy as np
import pytest

qwen_asr = pytest.importorskip("qwen_asr")

from meetmind.providers.qwen_stt import (
    MIN_AUDIO_SECONDS,
    SAMPLE_RATE,
    StreamingTranscriber,
    TranscriptSegment,
    _extract_text,
)


# ---------------------------------------------------------------------------
# _extract_text Tests
# ---------------------------------------------------------------------------
class TestExtractText:
    """Tests for the _extract_text helper function."""

    def test_extract_from_asr_object(self) -> None:
        """Extracts text from objects with .text attribute."""
        # Arrange
        result = MagicMock()
        result.text = "Hola mundo"

        # Act & Assert
        assert _extract_text(result) == "Hola mundo"

    def test_extract_from_string(self) -> None:
        """Extracts text from plain strings."""
        assert _extract_text("Hello world") == "Hello world"

    def test_extract_from_dict(self) -> None:
        """Extracts text from dict with 'text' key."""
        assert _extract_text({"text": "Dict result"}) == "Dict result"

    def test_extract_from_unknown_type(self) -> None:
        """Falls back to str() for unknown types."""
        assert _extract_text(42) == "42"

    def test_extract_strips_whitespace(self) -> None:
        """Whitespace is stripped from all result types."""
        result = MagicMock()
        result.text = "  padded  "
        assert _extract_text(result) == "padded"


# ---------------------------------------------------------------------------
# Model Loading Tests (covers _get_model error path)
# ---------------------------------------------------------------------------
class TestGetModel:
    """Tests for the lazy model loading singleton."""

    def test_import_error_raises_runtime_error(self) -> None:
        """Missing qwen-asr package raises RuntimeError."""
        import meetmind.providers.qwen_stt as mod

        # Reset the singleton
        mod._model = None

        # Mock the import to raise ImportError
        original_import = (
            __builtins__.__import__ if hasattr(__builtins__, "__import__") else __import__
        )

        def mock_import(name: str, *args: object, **kwargs: object) -> object:
            if name == "qwen_asr":
                raise ImportError("No module named 'qwen_asr'")
            return original_import(name, *args, **kwargs)

        with (
            patch("builtins.__import__", side_effect=mock_import),
            pytest.raises(RuntimeError, match="qwen-asr package not installed"),
        ):
            mod._get_model()

        # Cleanup
        mod._model = None

    def test_successful_model_load(self) -> None:
        """Successful model load returns the model instance."""
        import meetmind.providers.qwen_stt as mod

        # Reset the singleton
        mod._model = None

        mock_model_instance = MagicMock()
        mock_class = MagicMock()
        mock_class.from_pretrained.return_value = mock_model_instance

        with patch.dict(
            "sys.modules",
            {"qwen_asr": MagicMock(Qwen3ASRModel=mock_class)},
        ):
            result = mod._get_model()

        # Assert
        assert result is mock_model_instance

        # Cleanup
        mod._model = None


# ---------------------------------------------------------------------------
# Finalize & Reset Tests
# ---------------------------------------------------------------------------
class TestFinalizeAndReset:
    """Tests for _finalize_and_reset."""

    def test_finalize_emits_final_segment(self) -> None:
        """Finalize emits a non-partial segment."""
        # Arrange
        on_transcript = MagicMock()
        t = StreamingTranscriber(on_transcript=on_transcript)
        t._last_text = "Segmento final."

        # Act
        t._finalize_and_reset()

        # Assert
        on_transcript.assert_called_once()
        segment: TranscriptSegment = on_transcript.call_args[0][0]
        assert segment.is_partial is False
        assert segment.text == "Segmento final."
        assert t._last_text == ""

    def test_finalize_no_text_skips_callback(self) -> None:
        """Finalize with empty text does not call callback."""
        # Arrange
        on_transcript = MagicMock()
        t = StreamingTranscriber(on_transcript=on_transcript)
        t._last_text = ""

        # Act
        t._finalize_and_reset()

        # Assert
        on_transcript.assert_not_called()

    def test_finalize_without_callback(self) -> None:
        """Finalize without on_transcript does not crash."""
        # Arrange
        t = StreamingTranscriber(on_transcript=None)
        t._last_text = "Text without callback."

        # Act — should not raise
        t._finalize_and_reset()

        # Assert
        assert t._last_text == ""


# ---------------------------------------------------------------------------
# Transcribe Buffer — Additional Edge Cases
# ---------------------------------------------------------------------------
class TestTranscribeEdgeCases:
    """Additional edge cases for _transcribe_buffer."""

    @patch("meetmind.providers.qwen_stt._get_model")
    def test_unknown_result_type_skipped(self, mock_get_model: MagicMock) -> None:
        """Unknown result types become str via fallback."""
        # Arrange
        model = MagicMock()
        model.transcribe.return_value = [42]  # unexpected type in list
        mock_get_model.return_value = model
        on_transcript = MagicMock()

        t = StreamingTranscriber(on_transcript=on_transcript)
        min_samples = int(SAMPLE_RATE * MIN_AUDIO_SECONDS) + 100
        audio = np.random.randn(min_samples).astype(np.float32)
        t.feed_audio(audio.tobytes())

        # Act
        t._transcribe_buffer(finalize=False)

        # Assert — gets converted to "42" via str()
        on_transcript.assert_called_once()
        segment: TranscriptSegment = on_transcript.call_args[0][0]
        assert segment.text == "42"

    def test_transcribe_buffer_too_short(self) -> None:
        """Buffer shorter than min samples returns early."""
        # Arrange
        on_transcript = MagicMock()
        t = StreamingTranscriber(on_transcript=on_transcript)
        short_audio = np.zeros(100, dtype=np.float32)
        t.feed_audio(short_audio.tobytes())

        # Act
        t._transcribe_buffer(finalize=False)

        # Assert
        on_transcript.assert_not_called()
