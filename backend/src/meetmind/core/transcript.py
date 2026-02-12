"""Transcript manager — accumulates and segments meeting transcriptions.

Handles the real-time transcript buffer and segmentation for
the AI screening pipeline (every 30s → Haiku screening).
"""

import time

import structlog

logger = structlog.get_logger(__name__)

# Screening interval in seconds
SCREENING_INTERVAL_SECONDS = 30


class TranscriptSegment:
    """A segment of transcript text with metadata."""

    def __init__(self, text: str, timestamp: float, speaker: str = "unknown") -> None:
        """Initialize a transcript segment.

        Args:
            text: Transcribed text content.
            timestamp: Unix timestamp when the segment was created.
            speaker: Speaker identifier.
        """
        self.text = text
        self.timestamp = timestamp
        self.speaker = speaker

    def to_dict(self) -> dict[str, object]:
        """Convert segment to dictionary."""
        return {
            "text": self.text,
            "timestamp": self.timestamp,
            "speaker": self.speaker,
        }


class TranscriptManager:
    """Manages real-time transcript accumulation and segmentation.

    Accumulates transcript chunks and provides segments for AI screening
    at the configured interval (default: 30 seconds).
    """

    def __init__(self, screening_interval: int = SCREENING_INTERVAL_SECONDS) -> None:
        """Initialize the transcript manager.

        Args:
            screening_interval: Seconds between screening triggers.
        """
        self._segments: list[TranscriptSegment] = []
        self._buffer: list[str] = []
        self._screening_interval = screening_interval
        self._last_screening_time: float = time.monotonic()
        self._meeting_id: str = ""

    def set_meeting_id(self, meeting_id: str) -> None:
        """Set the current meeting identifier.

        Args:
            meeting_id: Unique meeting identifier.
        """
        self._meeting_id = meeting_id
        logger.info("transcript_manager_init", meeting_id=meeting_id)

    def add_chunk(self, text: str, speaker: str = "unknown") -> None:
        """Add a transcribed text chunk to the buffer.

        Args:
            text: Transcribed text to add.
            speaker: Speaker identifier.
        """
        if not text.strip():
            return

        segment = TranscriptSegment(
            text=text.strip(),
            timestamp=time.time(),
            speaker=speaker,
        )
        self._segments.append(segment)
        self._buffer.append(text.strip())

        logger.debug(
            "transcript_chunk_added",
            meeting_id=self._meeting_id,
            speaker=speaker,
            chunk_length=len(text),
            total_segments=len(self._segments),
        )

    def should_screen(self) -> bool:
        """Check if enough time has passed for a screening cycle.

        Returns:
            True if screening interval has elapsed and there's content.
        """
        elapsed = time.monotonic() - self._last_screening_time
        has_content = len(self._buffer) > 0
        return elapsed >= self._screening_interval and has_content

    def get_screening_text(self) -> str:
        """Get accumulated text for screening and reset the buffer.

        Returns:
            Concatenated text from the buffer since last screening.
        """
        text = " ".join(self._buffer)
        self._buffer.clear()
        self._last_screening_time = time.monotonic()

        logger.info(
            "screening_text_extracted",
            meeting_id=self._meeting_id,
            text_length=len(text),
        )
        return text

    def get_full_transcript(self) -> str:
        """Get the complete transcript as a single string.

        Returns:
            Full transcript text.
        """
        return " ".join(seg.text for seg in self._segments)

    def get_segments(self) -> list[dict[str, object]]:
        """Get all segments as a list of dictionaries.

        Returns:
            List of segment dictionaries.
        """
        return [seg.to_dict() for seg in self._segments]

    @property
    def segment_count(self) -> int:
        """Return total number of segments."""
        return len(self._segments)

    @property
    def buffer_size(self) -> int:
        """Return number of chunks in the current buffer."""
        return len(self._buffer)
