"""WebSocket endpoint for real-time audio transcription streaming.

Handles WebSocket connections for:
  - Receiving audio chunks (PCM 16kHz mono)
  - Sending transcription results
  - Triggering AI screening pipeline
"""

import json
import uuid

import structlog
from fastapi import WebSocket, WebSocketDisconnect

from meetmind.core.transcript import TranscriptManager

logger = structlog.get_logger(__name__)


class ConnectionManager:
    """Manages active WebSocket connections."""

    def __init__(self) -> None:
        """Initialize the connection manager."""
        self._active: dict[str, WebSocket] = {}
        self._transcripts: dict[str, TranscriptManager] = {}

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

        transcript = TranscriptManager()
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
            await websocket.send_json(data)

    def get_transcript(self, connection_id: str) -> TranscriptManager | None:
        """Get the transcript manager for a connection.

        Args:
            connection_id: Connection ID.

        Returns:
            TranscriptManager or None if not found.
        """
        return self._transcripts.get(connection_id)

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
      Server → Client: {"type": "transcript", "text": "...", "segments": [...]}
      Server → Client: {"type": "screening", "relevant": true, "reason": "..."}
      Server → Client: {"type": "analysis", "insights": {...}}

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
                "message": "MeetMind connected. Send transcript chunks to begin.",
            },
        )

        while True:
            raw = await websocket.receive_text()
            message = json.loads(raw)
            msg_type = message.get("type", "")

            if msg_type == "transcript":
                # Handle text transcript chunk
                text = message.get("text", "")
                speaker = message.get("speaker", "unknown")

                transcript = manager.get_transcript(connection_id)
                if transcript:
                    transcript.add_chunk(text, speaker=speaker)

                    # Send updated segment count
                    await manager.send_json(
                        connection_id,
                        {
                            "type": "transcript_ack",
                            "segments": transcript.segment_count,
                            "buffer_size": transcript.buffer_size,
                        },
                    )

                    # Check if screening is needed
                    if transcript.should_screen():
                        screening_text = transcript.get_screening_text()
                        # TODO: Wire to BedrockProvider.invoke_screening()
                        await manager.send_json(
                            connection_id,
                            {
                                "type": "screening_pending",
                                "text_length": len(screening_text),
                                "message": "Screening queued (Bedrock not yet wired)",
                            },
                        )

            elif msg_type == "ping":
                await manager.send_json(connection_id, {"type": "pong"})

            else:
                logger.warning(
                    "ws_unknown_message",
                    connection_id=connection_id,
                    msg_type=msg_type,
                )

    except WebSocketDisconnect:
        manager.disconnect(connection_id)
    except json.JSONDecodeError as e:
        logger.error("ws_invalid_json", connection_id=connection_id, error=str(e))
        manager.disconnect(connection_id)
