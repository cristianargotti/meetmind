"""Tests for WebSocket transcription endpoint."""

import json

from fastapi.testclient import TestClient

from meetmind.main import app


def test_websocket_connect_and_receive_welcome() -> None:
    """WebSocket connects and receives welcome message."""
    # Arrange
    client = TestClient(app)

    # Act & Assert
    with client.websocket_connect("/ws/transcription") as ws:
        data = ws.receive_json()
        assert data["type"] == "connected"
        assert "connection_id" in data


def test_websocket_send_transcript_chunk() -> None:
    """Sending a transcript chunk returns an ack."""
    # Arrange
    client = TestClient(app)

    with client.websocket_connect("/ws/transcription") as ws:
        # Skip welcome
        ws.receive_json()

        # Act
        ws.send_text(
            json.dumps(
                {
                    "type": "transcript",
                    "text": "hello from the meeting",
                    "speaker": "user1",
                }
            )
        )

        # Assert
        response = ws.receive_json()
        assert response["type"] == "transcript_ack"
        assert response["segments"] == 1


def test_websocket_ping_pong() -> None:
    """Ping message returns pong."""
    # Arrange
    client = TestClient(app)

    with client.websocket_connect("/ws/transcription") as ws:
        ws.receive_json()  # skip welcome

        # Act
        ws.send_text(json.dumps({"type": "ping"}))

        # Assert
        response = ws.receive_json()
        assert response["type"] == "pong"
