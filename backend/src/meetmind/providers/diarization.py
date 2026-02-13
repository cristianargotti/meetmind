"""Speaker diarization provider using pyannote.audio 3.1.

Detects WHO is speaking in each audio chunk. Runs server-side
on 16kHz mono WAV files (same as Whisper pipeline).
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import TYPE_CHECKING

import structlog

if TYPE_CHECKING:
    from pathlib import Path

from meetmind.config.settings import settings

logger = structlog.get_logger(__name__)

# Lazy-loaded pipeline instance
_pipeline: object | None = None

# Cache pyannote availability check (None = not checked yet)
_pyannote_available: bool | None = None


@dataclass(frozen=True)
class SpeakerSegment:
    """A segment of audio attributed to a specific speaker.

    Attributes:
        start_ms: Start time in milliseconds.
        end_ms: End time in milliseconds.
        speaker: Speaker label (e.g. 'SPEAKER_00').
    """

    start_ms: float
    end_ms: float
    speaker: str


def _get_pipeline() -> object:
    """Get or initialize the pyannote diarization pipeline (lazy singleton).

    Returns:
        Pyannote Pipeline instance.

    Raises:
        RuntimeError: If the pipeline cannot be loaded.
    """
    global _pipeline, _pyannote_available
    if _pipeline is None:
        if not settings.huggingface_token:
            msg = "MEETMIND_HUGGINGFACE_TOKEN is required for speaker diarization"
            raise RuntimeError(msg)

        try:
            from pyannote.audio import Pipeline  # type: ignore[import-not-found]
        except ImportError:
            _pyannote_available = False
            msg = "pyannote.audio is not installed — run: pip install pyannote.audio"
            raise RuntimeError(msg)  # noqa: B904

        _pyannote_available = True

        logger.info(
            "diarization_loading_pipeline",
            model=settings.diarization_model,
        )
        _pipeline = Pipeline.from_pretrained(
            settings.diarization_model,
            use_auth_token=settings.huggingface_token,
        )
        logger.info("diarization_pipeline_loaded")
    return _pipeline


def diarize_wav(wav_path: str | Path) -> list[SpeakerSegment]:
    """Run speaker diarization on a WAV file.

    Args:
        wav_path: Path to 16kHz mono WAV file.

    Returns:
        List of SpeakerSegment with start/end times and speaker labels.
        Returns empty list on failure.
    """
    if not settings.enable_diarization:
        return []

    # Skip if pyannote is known to be unavailable
    if _pyannote_available is False:
        return []

    try:
        pipeline = _get_pipeline()
        diarization = pipeline(str(wav_path))  # type: ignore[operator]

        segments: list[SpeakerSegment] = []
        for turn, _, speaker in diarization.itertracks(yield_label=True):
            segments.append(
                SpeakerSegment(
                    start_ms=turn.start * 1000.0,
                    end_ms=turn.end * 1000.0,
                    speaker=str(speaker),
                ),
            )

        logger.debug(
            "diarization_complete",
            wav_path=str(wav_path),
            num_segments=len(segments),
            speakers=list({s.speaker for s in segments}),
        )
        return segments

    except Exception as e:
        logger.warning("diarization_error", error=str(e))
        return []


def get_dominant_speaker(segments: list[SpeakerSegment]) -> str:
    """Get the speaker with the most total speaking time.

    Args:
        segments: List of speaker segments from diarization.

    Returns:
        Speaker label with longest duration, or 'unknown' if empty.
    """
    if not segments:
        return "unknown"

    durations: dict[str, float] = {}
    for seg in segments:
        duration = seg.end_ms - seg.start_ms
        durations[seg.speaker] = durations.get(seg.speaker, 0.0) + duration

    return max(durations, key=durations.get)  # type: ignore[arg-type]
