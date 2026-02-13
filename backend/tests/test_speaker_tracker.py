"""Tests for the speaker tracker."""

from meetmind.core.speaker_tracker import (
    SPEAKER_COLORS,
    SPEAKER_NAMES,
    SpeakerProfile,
    SpeakerTracker,
)


class TestSpeakerProfile:
    """Tests for the SpeakerProfile dataclass."""

    def test_create_profile(self) -> None:
        """Profile has expected defaults."""
        profile = SpeakerProfile(session_id="Speaker A", color="#3B82F6")
        assert profile.session_id == "Speaker A"
        assert profile.color == "#3B82F6"
        assert profile.chunk_labels == set()
        assert profile.total_duration_ms == 0.0


class TestSpeakerTracker:
    """Tests for the SpeakerTracker class."""

    def test_first_speaker_gets_name_a(self) -> None:
        """First speaker detected is named Speaker A."""
        tracker = SpeakerTracker()
        result = tracker.map_speaker("SPEAKER_00")
        assert result == "Speaker A"

    def test_second_speaker_gets_name_b(self) -> None:
        """Second unique speaker is named Speaker B."""
        tracker = SpeakerTracker()
        tracker.map_speaker("SPEAKER_00")
        result = tracker.map_speaker("SPEAKER_01")
        assert result == "Speaker B"

    def test_same_label_returns_same_id(self) -> None:
        """Repeated pyannote label returns consistent session ID."""
        tracker = SpeakerTracker()
        id1 = tracker.map_speaker("SPEAKER_00")
        id2 = tracker.map_speaker("SPEAKER_00")
        assert id1 == id2

    def test_speaker_count(self) -> None:
        """Speaker count tracks unique speakers."""
        tracker = SpeakerTracker()
        assert tracker.speaker_count == 0
        tracker.map_speaker("SPEAKER_00")
        assert tracker.speaker_count == 1
        tracker.map_speaker("SPEAKER_01")
        assert tracker.speaker_count == 2
        tracker.map_speaker("SPEAKER_00")  # repeat
        assert tracker.speaker_count == 2

    def test_max_speakers_limit(self) -> None:
        """Excess speakers get mapped to last known speaker."""
        tracker = SpeakerTracker(max_speakers=2)
        tracker.map_speaker("SPEAKER_00")  # Speaker A
        tracker.map_speaker("SPEAKER_01")  # Speaker B
        result = tracker.map_speaker("SPEAKER_02")  # overflow
        assert result == "Speaker B"
        assert tracker.speaker_count == 2

    def test_get_color(self) -> None:
        """Speaker colors are assigned correctly."""
        tracker = SpeakerTracker()
        tracker.map_speaker("SPEAKER_00")
        assert tracker.get_color("Speaker A") == SPEAKER_COLORS[0]

    def test_get_color_unknown(self) -> None:
        """Unknown speaker returns default gray."""
        tracker = SpeakerTracker()
        assert tracker.get_color("unknown") == "#6B7280"

    def test_record_duration(self) -> None:
        """Duration is accumulated correctly."""
        tracker = SpeakerTracker()
        tracker.map_speaker("SPEAKER_00")
        tracker.record_duration("Speaker A", 1500.0)
        tracker.record_duration("Speaker A", 2000.0)
        profile = tracker.get_profile("Speaker A")
        assert profile is not None
        assert profile.total_duration_ms == 3500.0

    def test_get_profile_none(self) -> None:
        """Returns None for unknown speaker."""
        tracker = SpeakerTracker()
        assert tracker.get_profile("Speaker Z") is None

    def test_to_dict(self) -> None:
        """Serialization includes all speaker data."""
        tracker = SpeakerTracker()
        tracker.map_speaker("SPEAKER_00")
        tracker.record_duration("Speaker A", 5000.0)
        tracker.map_speaker("SPEAKER_01")
        tracker.record_duration("Speaker B", 3000.0)

        data = tracker.to_dict()
        assert data["total_speakers"] == 2
        speakers = data["speakers"]
        assert isinstance(speakers, list)
        assert len(speakers) == 2
        assert speakers[0]["id"] == "Speaker A"
        assert speakers[0]["total_duration_ms"] == 5000
        assert speakers[1]["id"] == "Speaker B"

    def test_all_eight_speakers(self) -> None:
        """All 8 speaker slots can be assigned."""
        tracker = SpeakerTracker()
        for i in range(8):
            result = tracker.map_speaker(f"SPEAKER_{i:02d}")
            assert result == SPEAKER_NAMES[i]
        assert tracker.speaker_count == 8

    def test_empty_tracker_to_dict(self) -> None:
        """Empty tracker serializes cleanly."""
        tracker = SpeakerTracker()
        data = tracker.to_dict()
        assert data == {"speakers": [], "total_speakers": 0}

    def test_label_map_persistence(self) -> None:
        """Different pyannote labels from different chunks map consistently."""
        tracker = SpeakerTracker()
        # Chunk 1: pyannote assigns SPEAKER_00
        id1 = tracker.map_speaker("SPEAKER_00")
        # Chunk 2: pyannote might assign SPEAKER_01 for same physical person
        # but without embedding matching, it gets a new ID
        id2 = tracker.map_speaker("SPEAKER_01")
        assert id1 != id2
        # Chunk 3: pyannote re-uses SPEAKER_00
        id3 = tracker.map_speaker("SPEAKER_00")
        assert id3 == id1
