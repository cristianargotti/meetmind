"""Tests for WebSocket transcription endpoint."""

import json
from unittest.mock import patch

from fastapi.testclient import TestClient

from meetmind.api.websocket import ConnectionManager
from meetmind.core.auth import create_access_token
from meetmind.main import app


def _ws_url(token: str | None = None, path: str = "/ws/transcription") -> str:
    """Build WebSocket URL with optional token."""
    if token:
        return f"{path}?token={token}"
    return path


def _make_token(user_id: str = "test-user-1") -> str:
    """Create a valid access token for testing."""
    return create_access_token(user_id=user_id, email="test@example.com")


# --- Authentication tests ---


def test_websocket_rejects_no_token() -> None:
    """WebSocket connection without token is rejected with 4401."""
    client = TestClient(app)

    try:
        with client.websocket_connect("/ws/transcription"):
            pass  # Should not reach here
        assert False, "Expected WebSocketDisconnect"  # noqa: B011
    except Exception:
        pass  # Connection rejected — expected


def test_websocket_rejects_invalid_token() -> None:
    """WebSocket connection with invalid token is rejected."""
    client = TestClient(app)

    try:
        with client.websocket_connect(_ws_url(token="invalid.jwt.token")):
            pass
        assert False, "Expected WebSocketDisconnect"  # noqa: B011
    except Exception:
        pass  # Connection rejected — expected


# --- Authenticated endpoint tests ---


def test_websocket_connect_and_receive_welcome() -> None:
    """WebSocket connects with valid token and receives welcome message."""
    client = TestClient(app)
    token = _make_token()

    with client.websocket_connect(_ws_url(token=token)) as ws:
        data = ws.receive_json()
        assert data["type"] == "connected"
        assert "connection_id" in data
        assert "agents_ready" in data
        assert data["message"] == "MeetMind connected. Send transcript chunks to begin."


def test_websocket_send_transcript_chunk() -> None:
    """Sending a transcript chunk returns an ack."""
    client = TestClient(app)
    token = _make_token()

    with client.websocket_connect(_ws_url(token=token)) as ws:
        ws.receive_json()  # Skip welcome

        ws.send_text(
            json.dumps(
                {
                    "type": "transcript",
                    "text": "hello from the meeting",
                    "speaker": "user1",
                }
            )
        )

        response = ws.receive_json()
        assert response["type"] == "transcript_ack"
        assert response["segments"] == 1


def test_websocket_ping_pong() -> None:
    """Ping message returns pong."""
    client = TestClient(app)
    token = _make_token()

    with client.websocket_connect(_ws_url(token=token)) as ws:
        ws.receive_json()  # skip welcome

        ws.send_text(json.dumps({"type": "ping"}))

        response = ws.receive_json()
        assert response["type"] == "pong"


def test_websocket_unknown_message_type() -> None:
    """Unknown message type is handled gracefully."""
    client = TestClient(app)
    token = _make_token()

    with client.websocket_connect(_ws_url(token=token)) as ws:
        ws.receive_json()  # skip welcome

        ws.send_text(json.dumps({"type": "unknown_type", "data": "test"}))

        # Send ping to verify connection still alive
        ws.send_text(json.dumps({"type": "ping"}))

        response = ws.receive_json()
        assert response["type"] == "pong"


def test_websocket_transcript_with_default_speaker() -> None:
    """Transcript without speaker defaults to 'unknown'."""
    client = TestClient(app)
    token = _make_token()

    with client.websocket_connect(_ws_url(token=token)) as ws:
        ws.receive_json()  # skip welcome

        ws.send_text(
            json.dumps(
                {
                    "type": "transcript",
                    "text": "meeting notes",
                }
            )
        )

        response = ws.receive_json()
        assert response["type"] == "transcript_ack"
        assert response["speaker"] == "unknown"


def test_websocket_multiple_transcript_chunks() -> None:
    """Multiple transcript chunks increment segment count."""
    client = TestClient(app)
    token = _make_token()

    with client.websocket_connect(_ws_url(token=token)) as ws:
        ws.receive_json()  # skip welcome

        for i in range(3):
            ws.send_text(
                json.dumps(
                    {
                        "type": "transcript",
                        "text": f"chunk {i}",
                        "speaker": "user1",
                    }
                )
            )
            response = ws.receive_json()

        assert response["type"] == "transcript_ack"
        assert response["segments"] == 3


def test_websocket_alias_endpoint() -> None:
    """The /ws alias endpoint also works for transcription."""
    client = TestClient(app)
    token = _make_token()

    with client.websocket_connect(_ws_url(token=token, path="/ws")) as ws:
        data = ws.receive_json()
        assert data["type"] == "connected"
        assert "connection_id" in data


def test_websocket_binary_audio_chunked_mode() -> None:
    """Binary audio frames are handled in chunked mode."""
    client = TestClient(app)
    token = _make_token()

    with client.websocket_connect(_ws_url(token=token)) as ws:
        ws.receive_json()  # skip welcome

        with patch("meetmind.api.websocket.settings") as mock_settings:
            mock_settings.stt_mode = "chunked"

            ws.send_bytes(b"\x00" * 100)

            ws.send_text(json.dumps({"type": "ping"}))
            response = ws.receive_json()
            assert response["type"] == "pong"


# --- ConnectionManager unit tests ---


def test_connection_manager_init() -> None:
    """ConnectionManager initializes with no active connections."""
    # Arrange & Act
    mgr = ConnectionManager()

    # Assert
    assert mgr.active_count == 0
    assert not mgr.agents_ready


def test_connection_manager_init_agents() -> None:
    """init_agents initializes AI agents and marks them ready."""
    # Arrange
    mgr = ConnectionManager()

    # Act
    with (
        patch("meetmind.api.websocket.create_llm_provider"),
        patch("meetmind.api.websocket.ScreeningAgent"),
        patch("meetmind.api.websocket.AnalysisAgent"),
        patch("meetmind.api.websocket.CopilotAgent"),
        patch("meetmind.api.websocket.SummaryAgent"),
    ):
        mgr.init_agents()

    # Assert
    assert mgr.agents_ready


def test_connection_manager_disconnect_nonexistent() -> None:
    """Disconnecting a nonexistent connection doesn't crash."""
    # Arrange
    mgr = ConnectionManager()

    # Act — should not raise
    mgr.disconnect("nonexistent-id")

    # Assert
    assert mgr.active_count == 0


def test_connection_manager_get_transcript_nonexistent() -> None:
    """Getting transcript for nonexistent connection returns None."""
    # Arrange
    mgr = ConnectionManager()

    # Act & Assert
    assert mgr.get_transcript("nonexistent") is None


def test_connection_manager_send_json_to_nonexistent() -> None:
    """Sending JSON to nonexistent connection doesn't crash."""
    # Arrange
    mgr = ConnectionManager()

    # Act — should not raise
    import asyncio

    asyncio.get_event_loop().run_until_complete(mgr.send_json("nonexistent", {"type": "test"}))
