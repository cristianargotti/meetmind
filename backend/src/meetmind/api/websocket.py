"""WebSocket endpoint for real-time audio transcription streaming.

Handles WebSocket connections for:
  - Receiving audio chunks (PCM 16kHz mono)
  - Sending transcription results (streaming or chunked mode)
  - Triggering AI screening pipeline
  - Secret Copilot chat (user queries with meeting context)
  - Post-meeting summary generation
  - Real-time cost tracking and budget enforcement
  - Speaker diarization with consistent session-wide IDs
"""

import asyncio
import json
import time
import uuid
from typing import TYPE_CHECKING, Any

import structlog
from fastapi import WebSocket, WebSocketDisconnect

if TYPE_CHECKING:
    from collections.abc import Callable

    from meetmind.providers.base import LLMProvider

from meetmind.agents.analysis_agent import AnalysisAgent
from meetmind.agents.copilot_agent import CopilotAgent
from meetmind.agents.screening_agent import ScreeningAgent
from meetmind.agents.summary_agent import SummaryAgent
from meetmind.api import handlers
from meetmind.config.settings import settings
from meetmind.core import storage
from meetmind.core.auth import decode_token
from meetmind.core.speaker_tracker import SpeakerTracker
from meetmind.core.transcript import TranscriptManager
from meetmind.providers.factory import create_llm_provider
from meetmind.providers.streaming_stt import StreamingTranscriber as WhisperTranscriber
from meetmind.providers.whisper_stt import transcribe_with_speaker
from meetmind.utils.cost_tracker import CostTracker
from meetmind.utils.response_cache import ResponseCache

logger = structlog.get_logger(__name__)


class ConnectionManager:
    """Manages active WebSocket connections."""

    def __init__(self) -> None:
        """Initialize the connection manager."""
        self._active: dict[str, WebSocket] = {}
        self._transcripts: dict[str, TranscriptManager] = {}
        self._cost_trackers: dict[str, CostTracker] = {}
        self._languages: dict[str, str] = {}
        self._speaker_trackers: dict[str, SpeakerTracker] = {}
        self._streaming_transcribers: dict[str, Any] = {}
        self._start_times: dict[str, float] = {}
        self._response_cache: ResponseCache = ResponseCache()
        self._event_loop: asyncio.AbstractEventLoop | None = None
        self._provider: LLMProvider | None = None
        self._screening_agent: ScreeningAgent | None = None
        self._analysis_agent: AnalysisAgent | None = None
        self._copilot_agent: CopilotAgent | None = None
        self._summary_agent: SummaryAgent | None = None

    def init_agents(self) -> None:
        """Initialize LLM provider and AI agents.

        Call during FastAPI lifespan startup.
        Uses settings.llm_provider to select bedrock or openai.
        """
        provider = create_llm_provider()
        self._provider = provider
        self._screening_agent = ScreeningAgent(provider)
        self._analysis_agent = AnalysisAgent(provider)
        self._copilot_agent = CopilotAgent(provider)
        self._summary_agent = SummaryAgent(provider)
        logger.info("agents_initialized", provider=settings.llm_provider)

    @property
    def agents_ready(self) -> bool:
        """Check if AI agents are initialized."""
        return self._screening_agent is not None

    async def connect(
        self, websocket: WebSocket, *, language: str = "", user_id: str | None = None
    ) -> str:
        """Accept a WebSocket connection and assign an ID.

        Args:
            websocket: The WebSocket connection to accept.
            language: Optional language code from client (e.g., 'es', 'en', 'pt').
                     Falls back to server default if empty or 'auto'.
            user_id: Authenticated user ID from JWT token.

        Returns:
            Unique connection ID.
        """
        await websocket.accept()
        connection_id = str(uuid.uuid4())
        self._active[connection_id] = websocket

        # Store event loop reference for thread→async bridging
        if self._event_loop is None:
            self._event_loop = asyncio.get_running_loop()

        transcript = TranscriptManager(
            screening_interval=settings.screening_interval_seconds,
        )
        transcript.set_meeting_id(connection_id)
        self._transcripts[connection_id] = transcript
        self._start_times[connection_id] = time.monotonic()

        # Resolve language: client preference → server default
        language_code = language if language and language != "auto" else settings.moonshine_language
        stt_language = language if language and language != "auto" else settings.whisper_language

        # Persist meeting in DB (non-blocking, graceful fallback)
        try:
            await storage.create_meeting(
                meeting_id=connection_id,
                language=language_code,
                user_id=user_id,
            )
        except Exception as e:
            logger.warning("db_create_meeting_failed", error=str(e))

        # Resolve language code to natural name for AI prompts
        lang_map = {
            "es": "español",
            "en": "english",
            "pt": "português",
            "fr": "français",
            "de": "deutsch",
            "it": "italiano",
            "ja": "日本語",
            "ko": "한국어",
            "zh": "中文",
        }
        self._languages[connection_id] = lang_map.get(
            language_code,
            language_code,
        )

        # Per-connection cost tracking
        self._cost_trackers[connection_id] = CostTracker(
            budget_usd=settings.session_budget_usd,
        )

        # Per-connection speaker tracking
        self._speaker_trackers[connection_id] = SpeakerTracker()

        # Streaming STT (real-time mode)
        if settings.stt_mode == "streaming":
            streamer: Any = None
            if settings.stt_engine == "moonshine":
                from meetmind.providers.moonshine_stt import (
                    MoonshineTranscriber,
                )

                streamer = MoonshineTranscriber(
                    language=stt_language,
                    on_transcript=self._make_stream_callback(connection_id),
                )
            elif settings.stt_engine == "qwen":
                from meetmind.providers.qwen_stt import (
                    StreamingTranscriber as QwenTranscriber,
                )

                streamer = QwenTranscriber(
                    language=stt_language,
                    on_transcript=self._make_stream_callback(connection_id),
                    min_transcribe_interval=0.3,
                )
            elif settings.stt_engine == "parakeet":
                from meetmind.providers.parakeet_stt import (
                    StreamingTranscriber as ParakeetTranscriber,
                )

                streamer = ParakeetTranscriber(
                    language=stt_language,
                    on_transcript=self._make_stream_callback(connection_id),
                    min_transcribe_interval=0.1,
                )
            else:
                streamer = WhisperTranscriber(
                    language=stt_language,
                    on_transcript=self._make_stream_callback(connection_id),
                    min_transcribe_interval=0.5,
                )
            self._streaming_transcribers[connection_id] = streamer
            streamer.start()

        logger.info(
            "ws_connected",
            connection_id=connection_id,
            stt_mode=settings.stt_mode,
            language=language_code,
            active_connections=len(self._active),
        )
        return connection_id

    async def disconnect(self, connection_id: str) -> None:
        """Remove a disconnected WebSocket and persist meeting data.

        Saves transcript segments and meeting metadata to PostgreSQL
        before cleaning up connection state.

        Args:
            connection_id: ID of the connection to remove.
        """
        # Persist meeting data before cleanup
        transcript = self._transcripts.get(connection_id)
        tracker = self._cost_trackers.get(connection_id)
        start_time = self._start_times.pop(connection_id, None)

        if transcript and transcript.segment_count > 0:
            try:
                # Save all transcript segments
                segments = transcript.get_segments()
                await storage.save_segments(connection_id, segments)

                # Calculate duration
                duration_secs = None
                if start_time:
                    duration_secs = int(time.monotonic() - start_time)

                # Calculate total cost
                cost_usd = None
                if tracker:
                    cost_usd = tracker.total_cost_usd

                # End meeting in DB
                await storage.end_meeting(
                    connection_id,
                    duration_secs=duration_secs,
                    cost_usd=cost_usd,
                )
                logger.info(
                    "meeting_persisted",
                    meeting_id=connection_id,
                    segments=len(segments),
                    duration_secs=duration_secs,
                )
            except Exception as e:
                logger.error(
                    "meeting_persist_failed",
                    meeting_id=connection_id,
                    error=str(e),
                )

        # Cleanup connection state
        self._active.pop(connection_id, None)
        self._transcripts.pop(connection_id, None)
        self._cost_trackers.pop(connection_id, None)
        self._languages.pop(connection_id, None)
        self._speaker_trackers.pop(connection_id, None)

        # Stop streaming transcriber
        streamer = self._streaming_transcribers.pop(connection_id, None)
        if streamer:
            streamer.stop()
        logger.info(
            "ws_disconnected",
            connection_id=connection_id,
            active_connections=len(self._active),
        )

    def _make_stream_callback(
        self,
        connection_id: str,
    ) -> "Callable[[Any], None]":
        """Create a callback for streaming transcriber → WebSocket.

        The callback runs in the transcriber's background thread,
        so it uses run_coroutine_threadsafe to bridge to async.
        """

        def callback(segment: Any) -> None:
            if self._event_loop is None:
                return

            async def _send() -> None:
                # Send transcript to extension
                await self.send_json(
                    connection_id,
                    {
                        "type": "transcript_ack",
                        "text": segment.text,
                        "partial": segment.is_partial,
                        "speaker": "Speaker A",
                        "speaker_color": "#60a5fa",
                    },
                )

                # Add finalized text to transcript manager (for Copilot/Summary)
                if not segment.is_partial:
                    transcript = self._transcripts.get(connection_id)
                    if transcript:
                        transcript.add_chunk(segment.text, speaker="Speaker A")

                        # Trigger screening if due
                        if transcript.should_screen():
                            screening_text = transcript.get_screening_text()
                            full_context = transcript.get_full_transcript()
                            await self.run_screening_pipeline(
                                connection_id,
                                screening_text,
                                full_context,
                            )

            asyncio.run_coroutine_threadsafe(_send(), self._event_loop)

        return callback

    async def send_json(self, connection_id: str, data: dict[str, object]) -> None:
        """Send JSON data to a specific connection.

        Args:
            connection_id: Target connection ID.
            data: Dictionary to send as JSON.
        """
        websocket = self._active.get(connection_id)
        if websocket:
            try:
                await websocket.send_json(data)
            except Exception:
                logger.warning(
                    "ws_send_failed",
                    connection_id=connection_id,
                )

    def get_transcript(self, connection_id: str) -> TranscriptManager | None:
        """Get the transcript manager for a connection.

        Args:
            connection_id: Connection ID.

        Returns:
            TranscriptManager or None if not found.
        """
        return self._transcripts.get(connection_id)

    async def run_screening_pipeline(
        self,
        connection_id: str,
        screening_text: str,
        full_context: str,
    ) -> None:
        """Run the AI screening + analysis pipeline.

        Delegates to handlers module.
        """
        await handlers.run_screening_pipeline(
            send_fn=self.send_json,
            connection_id=connection_id,
            screening_text=screening_text,
            full_context=full_context,
            screening_agent=self._screening_agent,
            analysis_agent=self._analysis_agent,
            tracker=self._cost_trackers.get(connection_id),
            language=self._languages.get(connection_id, "español"),
        )

    async def run_copilot(
        self,
        connection_id: str,
        question: str,
        transcript_context: str,
    ) -> None:
        """Run the copilot agent. Delegates to handlers module."""
        await handlers.run_copilot(
            send_fn=self.send_json,
            connection_id=connection_id,
            question=question,
            transcript_context=transcript_context,
            copilot_agent=self._copilot_agent,
            tracker=self._cost_trackers.get(connection_id),
        )

    async def run_summary(
        self,
        connection_id: str,
        full_transcript: str,
    ) -> None:
        """Generate a post-meeting summary. Delegates to handlers module."""
        await handlers.run_summary(
            send_fn=self.send_json,
            connection_id=connection_id,
            full_transcript=full_transcript,
            summary_agent=self._summary_agent,
            tracker=self._cost_trackers.get(connection_id),
            language=self._languages.get(connection_id, "español"),
        )

    @property
    def active_count(self) -> int:
        """Return number of active connections."""
        return len(self._active)


# Global connection manager instance
manager = ConnectionManager()


async def websocket_transcription(websocket: WebSocket) -> None:
    """Handle a WebSocket connection for real-time transcription.

    Protocol:
      Client → Server: {"type": "audio", "data": "<base64_pcm>", "speaker": "user"}
      Client → Server: {"type": "transcript", "text": "hello world", "speaker": "user"}
      Server → Client: {"type": "transcript_ack", "segments": N, "buffer_size": N}
      Server → Client: {"type": "screening", "relevant": true, "reason": "..."}
      Server → Client: {"type": "analysis", "insight": {...}}

    Requires:
        ?token=<JWT> query parameter for authentication.

    Args:
        websocket: The WebSocket connection.
    """
    # ─── Authenticate before accepting ───────────────────────────
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=4401, reason="Authentication required")
        logger.warning("ws_rejected", reason="no_token")
        return

    try:
        payload = decode_token(token)
        if payload.get("type") != "access":
            await websocket.close(code=4401, reason="Invalid token type")
            logger.warning("ws_rejected", reason="invalid_token_type")
            return
        ws_user_id = payload.get("sub", "anonymous")
    except Exception:
        await websocket.close(code=4401, reason="Invalid or expired token")
        logger.warning("ws_rejected", reason="invalid_token")
        return

    logger.info("ws_authenticated", user_id=ws_user_id)

    connection_id = await manager.connect(
        websocket,
        language=websocket.query_params.get("lang", ""),
        user_id=ws_user_id,
    )

    try:
        # Send welcome message
        await manager.send_json(
            connection_id,
            {
                "type": "connected",
                "connection_id": connection_id,
                "agents_ready": manager.agents_ready,
                "message": "MeetMind connected. Send transcript chunks to begin.",
            },
        )

        # Report STT status to client (after welcome, so Flutter sees correct order)
        streamer = manager._streaming_transcribers.get(connection_id)
        if streamer is not None:
            if streamer.is_running:
                await manager.send_json(connection_id, {"type": "stt_status", "ready": True})
            else:
                error_msg = streamer.model_error or "STT engine failed to start"
                logger.error(
                    "stt_start_failed",
                    connection_id=connection_id,
                    error=error_msg,
                )
                await manager.send_json(
                    connection_id,
                    {"type": "stt_status", "ready": False, "error": error_msg},
                )

        # Track background tasks to prevent garbage collection
        background_tasks: set[asyncio.Task[None]] = set()

        while True:
            raw = await websocket.receive()
            msg_type_ws = raw.get("type", "")

            if msg_type_ws == "websocket.receive":
                # Check if text or binary
                if "text" in raw:
                    message = json.loads(raw["text"])
                    msg_type = message.get("type", "")

                    if msg_type == "transcript":
                        text = message.get("text", "")
                        speaker = message.get("speaker", "unknown")

                        transcript = manager.get_transcript(connection_id)
                        if transcript:
                            transcript.add_chunk(text, speaker=speaker)

                            await manager.send_json(
                                connection_id,
                                {
                                    "type": "transcript_ack",
                                    "segments": transcript.segment_count,
                                    "buffer_size": transcript.buffer_size,
                                    "speaker": speaker,
                                },
                            )

                            if transcript.should_screen():
                                screening_text = transcript.get_screening_text()
                                full_context = transcript.get_full_transcript()
                                task = asyncio.create_task(
                                    manager.run_screening_pipeline(
                                        connection_id,
                                        screening_text,
                                        full_context,
                                    )
                                )
                                background_tasks.add(task)
                                task.add_done_callback(background_tasks.discard)

                    elif msg_type == "copilot_query":
                        question = message.get("question", "")
                        if question.strip():
                            transcript = manager.get_transcript(connection_id)
                            context = transcript.get_full_transcript() if transcript else ""
                            task = asyncio.create_task(
                                manager.run_copilot(connection_id, question, context)
                            )
                            background_tasks.add(task)
                            task.add_done_callback(background_tasks.discard)

                    elif msg_type == "generate_summary":
                        transcript = manager.get_transcript(connection_id)
                        if transcript:
                            full_text = transcript.get_full_transcript()
                            task = asyncio.create_task(
                                manager.run_summary(connection_id, full_text)
                            )
                            background_tasks.add(task)
                            task.add_done_callback(background_tasks.discard)

                    elif msg_type == "ping":
                        await manager.send_json(connection_id, {"type": "pong"})

                    else:
                        logger.warning(
                            "ws_unknown_message",
                            connection_id=connection_id,
                            msg_type=msg_type,
                        )

                elif raw.get("bytes"):
                    audio_data = raw["bytes"]
                    logger.debug(
                        "ws_audio_received",
                        connection_id=connection_id,
                        size=len(audio_data),
                    )

                    if settings.stt_mode == "streaming":
                        # Streaming mode: feed audio to StreamingTranscriber
                        # (background thread handles Whisper + callbacks)
                        streamer = manager._streaming_transcribers.get(connection_id)
                        if streamer:
                            await asyncio.to_thread(streamer.feed_audio, audio_data)
                    else:
                        # Legacy chunked mode
                        result = await asyncio.to_thread(
                            transcribe_with_speaker,
                            audio_data,
                        )

                        if result.text:
                            tracker = manager._speaker_trackers.get(connection_id)
                            speaker = "unknown"
                            speaker_color = "#6B7280"
                            if tracker:
                                speaker = tracker.map_speaker(result.speaker)
                                speaker_color = tracker.get_color(speaker)

                            transcript = manager.get_transcript(connection_id)
                            if transcript:
                                transcript.add_chunk(result.text, speaker=speaker)

                            try:
                                await manager.send_json(
                                    connection_id,
                                    {
                                        "type": "transcript_ack",
                                        "text": result.text,
                                        "partial": False,
                                        "speaker": speaker,
                                        "speaker_color": speaker_color,
                                    },
                                )
                            except Exception:
                                logger.warning(
                                    "ws_send_after_disconnect",
                                    connection_id=connection_id,
                                )
                                break

                            if transcript and transcript.should_screen():
                                screening_text = transcript.get_screening_text()
                                full_context = transcript.get_full_transcript()
                                task = asyncio.create_task(
                                    manager.run_screening_pipeline(
                                        connection_id,
                                        screening_text,
                                        full_context,
                                    )
                                )
                                background_tasks.add(task)
                                task.add_done_callback(background_tasks.discard)

            elif msg_type_ws == "websocket.disconnect":
                break

    except WebSocketDisconnect:
        await manager.disconnect(connection_id)
    except json.JSONDecodeError as e:
        logger.error("ws_invalid_json", connection_id=connection_id, error=str(e))
        await manager.disconnect(connection_id)
