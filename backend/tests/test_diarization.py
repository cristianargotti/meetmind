"""Tests for the speaker diarization provider."""

from unittest.mock import MagicMock, patch

import pytest

from meetmind.providers.diarization import (
    SpeakerSegment,
    diarize_wav,
    get_dominant_speaker,
)


class TestSpeakerSegment:
    """Tests for the SpeakerSegment dataclass."""

    def test_create_segment(self) -> None:
        """Segment stores start, end, and speaker."""
        seg = SpeakerSegment(start_ms=0.0, end_ms=1500.0, speaker="SPEAKER_00")
        assert seg.start_ms == 0.0
        assert seg.end_ms == 1500.0
        assert seg.speaker == "SPEAKER_00"

    def test_segment_is_frozen(self) -> None:
        """Segments are immutable."""
        seg = SpeakerSegment(start_ms=0.0, end_ms=1000.0, speaker="SPEAKER_00")
        with pytest.raises(AttributeError):
            seg.speaker = "SPEAKER_01"  # type: ignore[misc]


class TestGetDominantSpeaker:
    """Tests for dominant speaker detection."""

    def test_single_speaker(self) -> None:
        """Returns the only speaker."""
        segments = [SpeakerSegment(0, 5000, "SPEAKER_00")]
        assert get_dominant_speaker(segments) == "SPEAKER_00"

    def test_multiple_speakers(self) -> None:
        """Returns speaker with most total time."""
        segments = [
            SpeakerSegment(0, 1000, "SPEAKER_00"),  # 1s
            SpeakerSegment(1000, 4000, "SPEAKER_01"),  # 3s
            SpeakerSegment(4000, 5000, "SPEAKER_00"),  # 1s
        ]
        assert get_dominant_speaker(segments) == "SPEAKER_01"

    def test_empty_segments(self) -> None:
        """Returns 'unknown' for empty list."""
        assert get_dominant_speaker([]) == "unknown"

    def test_equal_duration_picks_first(self) -> None:
        """With equal durations, returns the first one found."""
        segments = [
            SpeakerSegment(0, 2500, "SPEAKER_00"),
            SpeakerSegment(2500, 5000, "SPEAKER_01"),
        ]
        result = get_dominant_speaker(segments)
        assert result in ("SPEAKER_00", "SPEAKER_01")


class TestDiarizeWav:
    """Tests for the diarize_wav function."""

    @patch("meetmind.providers.diarization.settings")
    def test_disabled_returns_empty(self, mock_settings: MagicMock) -> None:
        """Returns empty when diarization is disabled."""
        mock_settings.enable_diarization = False
        result = diarize_wav("test.wav")
        assert result == []

    @patch("meetmind.providers.diarization.settings")
    @patch("meetmind.providers.diarization._get_pipeline")
    def test_pipeline_returns_segments(
        self,
        mock_get_pipeline: MagicMock,
        mock_settings: MagicMock,
    ) -> None:
        """Converts pipeline output to SpeakerSegments."""
        mock_settings.enable_diarization = True

        # Mock pyannote Turn object
        mock_turn = MagicMock()
        mock_turn.start = 0.0
        mock_turn.end = 2.5

        # Mock pipeline result
        mock_diarization = MagicMock()
        mock_diarization.itertracks.return_value = [
            (mock_turn, None, "SPEAKER_00"),
        ]
        mock_pipeline = MagicMock(return_value=mock_diarization)
        mock_get_pipeline.return_value = mock_pipeline

        result = diarize_wav("test.wav")
        assert len(result) == 1
        assert result[0].speaker == "SPEAKER_00"
        assert result[0].start_ms == 0.0
        assert result[0].end_ms == 2500.0

    @patch("meetmind.providers.diarization.settings")
    @patch("meetmind.providers.diarization._get_pipeline")
    def test_pipeline_error_returns_empty(
        self,
        mock_get_pipeline: MagicMock,
        mock_settings: MagicMock,
    ) -> None:
        """Returns empty list on pipeline error."""
        mock_settings.enable_diarization = True
        mock_pipeline = MagicMock(side_effect=RuntimeError("Model load failed"))
        mock_get_pipeline.return_value = mock_pipeline

        result = diarize_wav("test.wav")
        assert result == []

    @patch("meetmind.providers.diarization.settings")
    @patch("meetmind.providers.diarization._get_pipeline")
    def test_multiple_speakers_detected(
        self,
        mock_get_pipeline: MagicMock,
        mock_settings: MagicMock,
    ) -> None:
        """Handles multiple speakers in one chunk."""
        mock_settings.enable_diarization = True

        test_data = [
            (0, 1.5, "SPEAKER_00"),
            (1.5, 3.0, "SPEAKER_01"),
            (3.0, 5.0, "SPEAKER_00"),
        ]
        turns = []
        for start, end, spk in test_data:
            t = MagicMock()
            t.start = start
            t.end = end
            turns.append((t, None, spk))

        mock_diarization = MagicMock()
        mock_diarization.itertracks.return_value = turns
        mock_pipeline = MagicMock(return_value=mock_diarization)
        mock_get_pipeline.return_value = mock_pipeline

        result = diarize_wav("test.wav")
        assert len(result) == 3
        speakers = {s.speaker for s in result}
        assert speakers == {"SPEAKER_00", "SPEAKER_01"}
