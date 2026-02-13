"""Server-side Whisper STT for Chrome Extension audio.

Uses faster-whisper (CTranslate2) to transcribe audio chunks
received as binary WebSocket frames from the Chrome Extension.
Optionally runs speaker diarization on the same WAV file.
"""

import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

import structlog

from meetmind.config.settings import settings

logger = structlog.get_logger(__name__)

# Lazy-loaded model instance
_model: object | None = None


@dataclass(frozen=True)
class TranscriptionResult:
    """Result of audio transcription with optional speaker detection.

    Attributes:
        text: Transcribed text.
        speaker: Detected speaker label (pyannote), or 'unknown'.
    """

    text: str
    speaker: str = "unknown"


def _get_model() -> object:
    """Get or initialize the Whisper model (lazy singleton).

    Returns:
        WhisperModel instance.
    """
    global _model
    if _model is None:
        from faster_whisper import WhisperModel  # type: ignore[import-untyped]

        logger.info("whisper_loading_model", size=settings.whisper_model)
        _model = WhisperModel(
            settings.whisper_model,
            device="cpu",
            compute_type="int8",
            cpu_threads=4,
        )
        logger.info("whisper_model_loaded", size=settings.whisper_model)
    return _model


def _convert_webm_to_wav(audio_bytes: bytes) -> tuple[Path, Path] | None:
    """Convert webm audio bytes to 16kHz mono WAV via ffmpeg.

    Args:
        audio_bytes: Raw audio data (webm/opus format).

    Returns:
        Tuple of (webm_path, wav_path) or None on failure.
    """
    with tempfile.NamedTemporaryFile(suffix=".webm", delete=False) as f:
        f.write(audio_bytes)
        webm_path = Path(f.name)

    wav_path = webm_path.with_suffix(".wav")
    result = subprocess.run(  # noqa: S603
        [  # noqa: S607
            "ffmpeg",
            "-y",
            "-i",
            str(webm_path),
            "-ar",
            "16000",
            "-ac",
            "1",
            "-f",
            "wav",
            str(wav_path),
        ],
        capture_output=True,
        timeout=10,
    )

    if result.returncode != 0:
        logger.warning(
            "ffmpeg_conversion_failed",
            stderr=result.stderr.decode()[:200],
        )
        webm_path.unlink(missing_ok=True)
        return None

    return webm_path, wav_path


def _run_whisper(wav_path: Path) -> str:
    """Run Whisper transcription on a WAV file.

    Args:
        wav_path: Path to 16kHz mono WAV file.

    Returns:
        Transcribed text string.
    """
    model = _get_model()
    lang = settings.whisper_language or None
    segments, _info = model.transcribe(  # type: ignore[attr-defined]
        str(wav_path),
        language=lang,
        beam_size=1,  # greedy decode for speed
        vad_filter=True,
        vad_parameters={
            "min_silence_duration_ms": 300,
            "speech_pad_ms": 200,
        },
    )
    return " ".join(segment.text.strip() for segment in segments).strip()


def transcribe_audio_bytes(audio_bytes: bytes) -> str:
    """Transcribe audio bytes (webm/opus) to text.

    Converts webm to wav via ffmpeg, then runs Whisper inference.

    Args:
        audio_bytes: Raw audio data (webm/opus format from MediaRecorder).

    Returns:
        Transcribed text string, or empty string on failure.
    """
    if len(audio_bytes) < 1000:
        return ""

    try:
        paths = _convert_webm_to_wav(audio_bytes)
        if paths is None:
            return ""
        webm_path, wav_path = paths

        text = _run_whisper(wav_path)

        webm_path.unlink(missing_ok=True)
        wav_path.unlink(missing_ok=True)
        return text

    except Exception as e:
        logger.error("whisper_transcription_error", error=str(e))
        return ""


def transcribe_with_speaker(audio_bytes: bytes) -> TranscriptionResult:
    """Transcribe audio bytes with speaker detection.

    Runs Whisper for transcription AND pyannote for speaker
    diarization on the same WAV file. Falls back gracefully
    if diarization fails or is disabled.

    Args:
        audio_bytes: Raw audio data (webm/opus format).

    Returns:
        TranscriptionResult with text and detected speaker label.
    """
    if len(audio_bytes) < 1000:
        return TranscriptionResult(text="")

    try:
        paths = _convert_webm_to_wav(audio_bytes)
        if paths is None:
            return TranscriptionResult(text="")
        webm_path, wav_path = paths

        # Run Whisper transcription
        text = _run_whisper(wav_path)

        # Run speaker diarization on the same WAV (reuse file!)
        speaker = "unknown"
        if text and settings.enable_diarization:
            from meetmind.providers.diarization import diarize_wav, get_dominant_speaker

            segments = diarize_wav(wav_path)
            speaker = get_dominant_speaker(segments)

        # Cleanup
        webm_path.unlink(missing_ok=True)
        wav_path.unlink(missing_ok=True)

        return TranscriptionResult(text=text, speaker=speaker)

    except Exception as e:
        logger.error("whisper_transcription_error", error=str(e))
        return TranscriptionResult(text="")
