"""WebSocket endpoint for real-time audio transcription streaming.

Handles WebSocket connections for:
  - Receiving audio chunks (PCM 16kHz mono)
  - Sending transcription results
  - Triggering AI screening pipeline
"""

import asyncio
import json
import uuid

import structlog
from fastapi import WebSocket, WebSocketDisconnect

from meetmind.agents.analysis_agent import AnalysisAgent
from meetmind.agents.screening_agent import ScreeningAgent
from meetmind.core.transcript import TranscriptManager
from meetmind.providers.bedrock import BedrockProvider
from meetmind.providers.whisper_stt import transcribe_audio_bytes
from meetmind.config.settings import settings

logger = structlog.get_logger(__name__)


class ConnectionManager:
    """Manages active WebSocket connections."""

    def __init__(self) -> None:
        """Initialize the connection manager."""
        self._active: dict[str, WebSocket] = {}
        self._transcripts: dict[str, TranscriptManager] = {}
        self._bedrock: BedrockProvider | None = None
        self._screening_agent: ScreeningAgent | None = None
        self._analysis_agent: AnalysisAgent | None = None

    def init_agents(self) -> None:
        """Initialize Bedrock provider and AI agents.

        Call during FastAPI lifespan startup.
        """
        self._bedrock = BedrockProvider()
        self._screening_agent = ScreeningAgent(self._bedrock)
        self._analysis_agent = AnalysisAgent(self._bedrock)
        logger.info("agents_initialized")

    @property
    def agents_ready(self) -> bool:
        """Check if AI agents are initialized."""
        return self._screening_agent is not None

    async def connect(self, websocket: WebSocket) -> str:
        """Accept a WebSocket connection and assign an ID.

        Args:
            websocket: The WebSocket connection to accept.

        Returns:
            Unique connection ID.
        """
        await websocket.accept()
        connection_id = str(uuid.uuid4())
        self._active[connection_id] = websocket

        transcript = TranscriptManager(
            screening_interval=settings.screening_interval_seconds,
        )
        transcript.set_meeting_id(connection_id)
        self._transcripts[connection_id] = transcript

        logger.info(
            "ws_connected",
            connection_id=connection_id,
            active_connections=len(self._active),
        )
        return connection_id

    def disconnect(self, connection_id: str) -> None:
        """Remove a disconnected WebSocket.

        Args:
            connection_id: ID of the connection to remove.
        """
        self._active.pop(connection_id, None)
        self._transcripts.pop(connection_id, None)
        logger.info(
            "ws_disconnected",
            connection_id=connection_id,
            active_connections=len(self._active),
        )

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
        """Run the AI screening + analysis pipeline as a background task.

        Args:
            connection_id: WebSocket connection to send results to.
            screening_text: Text buffer to screen.
            full_context: Full meeting transcript for analysis context.
        """
        if not self._screening_agent or not self._analysis_agent:
            await self.send_json(
                connection_id,
                {
                    "type": "screening",
                    "relevant": False,
                    "reason": "Agents not initialized (no AWS credentials)",
                },
            )
            return

        # Step 1: Screening (Haiku — fast, cheap)
        screening_result = await self._screening_agent.screen(screening_text)
        await self.send_json(
            connection_id,
            {
                "type": "screening",
                **screening_result.to_dict(),
            },
        )

        # Step 2: Analysis (Sonnet — only if relevant)
        if screening_result.relevant:
            insight = await self._analysis_agent.analyze(
                segment=screening_text,
                context=full_context,
                screening_reason=screening_result.reason,
            )

            if insight:
                await self.send_json(
                    connection_id,
                    {
                        "type": "analysis",
                        "insight": insight.to_dict(),
                    },
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

    Args:
        websocket: The WebSocket connection.
    """
    connection_id = await manager.connect(websocket)

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

        # Audio buffer for binary frames (Chrome Extension)
        audio_buffer = bytearray()
        audio_buffer_threshold = 32000  # ~2s at 16kHz mono

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
                                },
                            )

                            if transcript.should_screen():
                                screening_text = transcript.get_screening_text()
                                full_context = transcript.get_full_transcript()
                                asyncio.create_task(
                                    manager.run_screening_pipeline(
                                        connection_id,
                                        screening_text,
                                        full_context,
                                    )
                                )

                    elif msg_type == "ping":
                        await manager.send_json(connection_id, {"type": "pong"})

                    else:
                        logger.warning(
                            "ws_unknown_message",
                            connection_id=connection_id,
                            msg_type=msg_type,
                        )

                elif "bytes" in raw and raw["bytes"]:
                    # Complete webm blob from Chrome Extension
                    # Each blob is a full 5s recording with headers
                    audio_data = raw["bytes"]
                    logger.info(
                        "ws_audio_received",
                        connection_id=connection_id,
                        size=len(audio_data),
                    )

                    text = await asyncio.to_thread(transcribe_audio_bytes, audio_data)

                    if text:
                        transcript = manager.get_transcript(connection_id)
                        if transcript:
                            transcript.add_chunk(text, speaker="user")

                        try:
                            await manager.send_json(
                                connection_id,
                                {
                                    "type": "transcript_ack",
                                    "text": text,
                                    "partial": False,
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
                            asyncio.create_task(
                                manager.run_screening_pipeline(
                                    connection_id,
                                    screening_text,
                                    full_context,
                                )
                            )

            elif msg_type_ws == "websocket.disconnect":
                break

    except WebSocketDisconnect:
        manager.disconnect(connection_id)
    except json.JSONDecodeError as e:
        logger.error("ws_invalid_json", connection_id=connection_id, error=str(e))
        manager.disconnect(connection_id)
