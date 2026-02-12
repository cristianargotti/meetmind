"""Tests for TranscriptManager — core domain logic."""

from meetmind.core.transcript import TranscriptManager


def test_add_chunk_stores_segment() -> None:
    """Adding a transcript chunk creates a segment."""
    # Arrange
    manager = TranscriptManager(screening_interval=30)

    # Act
    manager.add_chunk("hello world", speaker="user1")

    # Assert
    assert manager.segment_count == 1
    assert manager.buffer_size == 1


def test_add_empty_chunk_is_ignored() -> None:
    """Empty or whitespace-only chunks are ignored."""
    # Arrange
    manager = TranscriptManager()

    # Act
    manager.add_chunk("")
    manager.add_chunk("   ")

    # Assert
    assert manager.segment_count == 0
    assert manager.buffer_size == 0


def test_should_screen_after_interval() -> None:
    """Screening triggers after the configured interval."""
    # Arrange — use 0 seconds for immediate screening
    manager = TranscriptManager(screening_interval=0)
    manager.add_chunk("important discussion")

    # Act
    result = manager.should_screen()

    # Assert
    assert result is True


def test_should_screen_no_content() -> None:
    """Screening does not trigger when buffer is empty."""
    # Arrange
    manager = TranscriptManager(screening_interval=0)

    # Act — no chunks added
    result = manager.should_screen()

    # Assert
    assert result is False


def test_get_screening_text_clears_buffer() -> None:
    """Getting screening text clears the buffer but keeps segments."""
    # Arrange
    manager = TranscriptManager(screening_interval=0)
    manager.add_chunk("first chunk")
    manager.add_chunk("second chunk")

    # Act
    text = manager.get_screening_text()

    # Assert
    assert "first chunk" in text
    assert "second chunk" in text
    assert manager.buffer_size == 0
    assert manager.segment_count == 2  # segments preserved


def test_get_full_transcript() -> None:
    """Full transcript returns all segments concatenated."""
    # Arrange
    manager = TranscriptManager()
    manager.add_chunk("hello")
    manager.add_chunk("world")

    # Act
    full = manager.get_full_transcript()

    # Assert
    assert full == "hello world"


def test_get_segments_returns_dicts() -> None:
    """Segments are returned as serializable dictionaries."""
    # Arrange
    manager = TranscriptManager()
    manager.add_chunk("test", speaker="speaker1")

    # Act
    segments = manager.get_segments()

    # Assert
    assert len(segments) == 1
    assert segments[0]["text"] == "test"
    assert segments[0]["speaker"] == "speaker1"
    assert "timestamp" in segments[0]


def test_set_meeting_id() -> None:
    """Meeting ID is stored correctly."""
    # Arrange
    manager = TranscriptManager()

    # Act
    manager.set_meeting_id("meeting-123")

    # Assert
    assert manager._meeting_id == "meeting-123"
