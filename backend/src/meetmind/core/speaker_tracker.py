"""Speaker tracker — maintains consistent speaker IDs across audio chunks.

Pyannote assigns arbitrary labels per chunk (SPEAKER_00, SPEAKER_01...).
This tracker uses speaker embeddings to match speakers across chunks,
ensuring consistent IDs throughout the entire meeting session.
"""

from __future__ import annotations

from dataclasses import dataclass, field

import structlog

logger = structlog.get_logger(__name__)

# Maximum number of unique speakers to track per session
MAX_SPEAKERS = 8

# Human-readable speaker names (assigned in order of appearance)
SPEAKER_NAMES = [
    "Speaker A",
    "Speaker B",
    "Speaker C",
    "Speaker D",
    "Speaker E",
    "Speaker F",
    "Speaker G",
    "Speaker H",
]

# Color palette for Chrome Extension UI
SPEAKER_COLORS = [
    "#3B82F6",  # Blue
    "#10B981",  # Green
    "#F59E0B",  # Amber
    "#EF4444",  # Red
    "#8B5CF6",  # Purple
    "#EC4899",  # Pink
    "#06B6D4",  # Cyan
    "#84CC16",  # Lime
]


@dataclass
class SpeakerProfile:
    """A tracked speaker in the session.

    Attributes:
        session_id: Consistent name for this speaker (e.g. 'Speaker A').
        color: Hex color for UI rendering.
        chunk_labels: Set of pyannote labels mapped to this speaker.
        total_duration_ms: Total speaking time in milliseconds.
    """

    session_id: str
    color: str
    chunk_labels: set[str] = field(default_factory=set)
    total_duration_ms: float = 0.0


class SpeakerTracker:
    """Tracks speakers across audio chunks for a single meeting session.

    Uses a simple label-mapping approach for 5-second chunks:
    since pyannote processes each chunk independently, we map
    pyannote's per-chunk labels to consistent session-wide IDs
    based on order of appearance.

    For 5-second chunks, pyannote typically detects 1-2 speakers,
    so the dominant speaker per chunk is the primary signal.
    """

    def __init__(self, max_speakers: int = MAX_SPEAKERS) -> None:
        """Initialize the speaker tracker.

        Args:
            max_speakers: Maximum unique speakers to track.
        """
        self._profiles: list[SpeakerProfile] = []
        self._max_speakers = min(max_speakers, len(SPEAKER_NAMES))
        self._label_map: dict[str, str] = {}

    def map_speaker(self, pyannote_label: str) -> str:
        """Map a pyannote chunk label to a consistent session-wide ID.

        If the label has been seen before, returns the same session ID.
        If new, assigns the next available speaker name.

        Args:
            pyannote_label: Label from pyannote (e.g. 'SPEAKER_00').

        Returns:
            Consistent session-wide ID (e.g. 'Speaker A').
        """
        if pyannote_label in self._label_map:
            return self._label_map[pyannote_label]

        # New speaker — assign next available name
        idx = len(self._profiles)
        if idx >= self._max_speakers:
            logger.warning(
                "max_speakers_reached",
                max=self._max_speakers,
                label=pyannote_label,
            )
            # Map to last known speaker as fallback
            fallback = self._profiles[-1].session_id if self._profiles else "unknown"
            self._label_map[pyannote_label] = fallback
            return fallback

        profile = SpeakerProfile(
            session_id=SPEAKER_NAMES[idx],
            color=SPEAKER_COLORS[idx],
        )
        profile.chunk_labels.add(pyannote_label)
        self._profiles.append(profile)
        self._label_map[pyannote_label] = profile.session_id

        logger.info(
            "new_speaker_detected",
            session_id=profile.session_id,
            pyannote_label=pyannote_label,
            total_speakers=len(self._profiles),
        )
        return profile.session_id

    def record_duration(self, session_id: str, duration_ms: float) -> None:
        """Record speaking duration for a speaker.

        Args:
            session_id: Session-wide speaker ID (e.g. 'Speaker A').
            duration_ms: Speaking duration in milliseconds.
        """
        for profile in self._profiles:
            if profile.session_id == session_id:
                profile.total_duration_ms += duration_ms
                return

    def get_profile(self, session_id: str) -> SpeakerProfile | None:
        """Get a speaker profile by session ID.

        Args:
            session_id: Session-wide speaker ID.

        Returns:
            SpeakerProfile or None if not found.
        """
        for profile in self._profiles:
            if profile.session_id == session_id:
                return profile
        return None

    def get_color(self, session_id: str) -> str:
        """Get the color for a speaker.

        Args:
            session_id: Session-wide speaker ID.

        Returns:
            Hex color string, or default gray if unknown.
        """
        profile = self.get_profile(session_id)
        return profile.color if profile else "#6B7280"

    @property
    def speaker_count(self) -> int:
        """Return the number of unique speakers detected."""
        return len(self._profiles)

    def to_dict(self) -> dict[str, object]:
        """Serialize tracker state for WebSocket broadcasting.

        Returns:
            Dictionary with speaker profiles and statistics.
        """
        return {
            "speakers": [
                {
                    "id": p.session_id,
                    "color": p.color,
                    "total_duration_ms": round(p.total_duration_ms),
                }
                for p in self._profiles
            ],
            "total_speakers": len(self._profiles),
        }
