"""Server-side Whisper STT for Chrome Extension audio.

Uses faster-whisper (CTranslate2) to transcribe audio chunks
received as binary WebSocket frames from the Chrome Extension.
"""

import io
import subprocess
import tempfile
from pathlib import Path

import structlog

logger = structlog.get_logger(__name__)

# Lazy-loaded model instance
_model: object | None = None
_model_size: str = "base"


def _get_model() -> object:
    """Get or initialize the Whisper model (lazy singleton).

    Returns:
        WhisperModel instance.
    """
    global _model  # noqa: PLW0603
    if _model is None:
        from faster_whisper import WhisperModel  # type: ignore[import-untyped]

        logger.info("whisper_loading_model", size=_model_size)
        _model = WhisperModel(
            _model_size,
            device="cpu",
            compute_type="int8",
            cpu_threads=4,
        )
        logger.info("whisper_model_loaded", size=_model_size)
    return _model


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
        # Write webm to temp file
        with tempfile.NamedTemporaryFile(suffix=".webm", delete=False) as f:
            f.write(audio_bytes)
            webm_path = Path(f.name)

        # Convert webm → wav (16kHz mono) via ffmpeg
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
            return ""

        # Transcribe with Whisper (optimized for 5s chunks)
        model = _get_model()
        segments, info = model.transcribe(  # type: ignore[attr-defined]
            str(wav_path),
            language=None,  # auto-detect
            beam_size=1,  # greedy decode for speed
            vad_filter=True,
            vad_parameters={
                "min_silence_duration_ms": 300,
                "speech_pad_ms": 200,
            },
        )

        text = " ".join(segment.text.strip() for segment in segments)

        # Cleanup temp files
        webm_path.unlink(missing_ok=True)
        wav_path.unlink(missing_ok=True)

        return text.strip()

    except Exception as e:
        logger.error("whisper_transcription_error", error=str(e))
        return ""
