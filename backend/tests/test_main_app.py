"""Tests for main FastAPI application REST endpoints."""

from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient


@pytest.fixture
def client() -> TestClient:
    """Create a test client without triggering lifespan."""
    from meetmind.main import app

    return TestClient(app, raise_server_exceptions=False)


@pytest.fixture
def auth_headers() -> dict[str, str]:
    """Create valid JWT auth headers for testing."""
    from meetmind.core.auth import create_access_token

    token = create_access_token("test-user-id", "test@example.com")
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def authed_client(client: TestClient, auth_headers: dict[str, str]) -> TestClient:
    """Test client with auth headers pre-set."""
    client.headers.update(auth_headers)
    return client


# ─── Health ──────────────────────────────────────────────────────


@patch("meetmind.main.storage")
def test_health_check(mock_storage: AsyncMock, client: TestClient) -> None:
    """Health endpoint returns healthy status when DB is connected."""
    # Mock the asyncpg pool → acquire() → conn chain
    from unittest.mock import MagicMock

    conn_mock = AsyncMock()
    conn_mock.fetchval = AsyncMock(return_value=1)
    ctx_mock = MagicMock()
    ctx_mock.__aenter__ = AsyncMock(return_value=conn_mock)
    ctx_mock.__aexit__ = AsyncMock(return_value=False)
    pool_mock = MagicMock()
    pool_mock.acquire.return_value = ctx_mock
    mock_storage.get_pool = AsyncMock(return_value=pool_mock)

    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["database"] == "connected"


# ─── Meetings ───────────────────────────────────────────────────


@patch("meetmind.main.storage")
def test_list_meetings(mock_storage: AsyncMock, authed_client: TestClient) -> None:
    """List meetings returns paginated results."""
    mock_storage.list_meetings = AsyncMock(
        return_value=[
            {"id": "m1", "title": "Test Meeting"},
        ]
    )
    response = authed_client.get("/api/meetings?limit=10&offset=0")
    assert response.status_code == 200
    data = response.json()
    assert "meetings" in data
    assert data["limit"] == 10
    assert data["offset"] == 0


@patch("meetmind.main.storage")
def test_get_meeting_found(mock_storage: AsyncMock, authed_client: TestClient) -> None:
    """Get meeting returns data when found."""
    mock_storage.get_meeting = AsyncMock(
        return_value={
            "id": "m1",
            "title": "Test Meeting",
            "segments": [],
        }
    )
    response = authed_client.get("/api/meetings/m1")
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == "m1"


@patch("meetmind.main.storage")
def test_get_meeting_not_found(mock_storage: AsyncMock, authed_client: TestClient) -> None:
    """Get meeting returns 404 when not found."""
    mock_storage.get_meeting = AsyncMock(return_value=None)
    response = authed_client.get("/api/meetings/nonexistent")
    assert response.status_code == 404


@patch("meetmind.main.storage")
def test_delete_meeting_success(mock_storage: AsyncMock, authed_client: TestClient) -> None:
    """Delete meeting returns confirmation."""
    mock_storage.get_meeting = AsyncMock(
        return_value={"id": "m1", "title": "Test", "user_id": "test-user-id"}
    )
    mock_storage.delete_meeting = AsyncMock(return_value=True)
    response = authed_client.delete("/api/meetings/m1")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "deleted"


@patch("meetmind.main.storage")
def test_delete_meeting_not_found(mock_storage: AsyncMock, authed_client: TestClient) -> None:
    """Delete meeting returns 404 when not found."""
    mock_storage.get_meeting = AsyncMock(return_value=None)
    response = authed_client.delete("/api/meetings/nonexistent")
    assert response.status_code == 404


# ─── Action Items ────────────────────────────────────────────────


@patch("meetmind.main.storage")
def test_get_pending_actions(mock_storage: AsyncMock, authed_client: TestClient) -> None:
    """Get pending action items returns list."""
    mock_storage.get_pending_action_items = AsyncMock(
        return_value=[
            {"id": 1, "text": "Follow up", "status": "pending"},
        ]
    )
    response = authed_client.get("/api/action-items?limit=10")
    assert response.status_code == 200
    data = response.json()
    assert data["count"] == 1


@patch("meetmind.main.storage")
def test_update_action_item_success(mock_storage: AsyncMock, authed_client: TestClient) -> None:
    """Update action item returns new status."""
    mock_storage.update_action_item = AsyncMock(return_value=True)
    response = authed_client.patch("/api/action-items/1?status=done")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "done"


@patch("meetmind.main.storage")
def test_update_action_item_not_found(mock_storage: AsyncMock, authed_client: TestClient) -> None:
    """Update action item returns 404 when not found."""
    mock_storage.update_action_item = AsyncMock(return_value=False)
    response = authed_client.patch("/api/action-items/999?status=done")
    assert response.status_code == 404


# ─── Stats ───────────────────────────────────────────────────────


@patch("meetmind.main.storage")
def test_get_stats(mock_storage: AsyncMock, authed_client: TestClient) -> None:
    """Get stats returns dashboard data."""
    mock_storage.get_stats = AsyncMock(
        return_value={
            "total_meetings": 5,
            "total_insights": 12,
            "total_cost_usd": 0.50,
        }
    )
    response = authed_client.get("/api/stats")
    assert response.status_code == 200
    data = response.json()
    assert "total_meetings" in data


# ─── End Meeting ─────────────────────────────────────────────────


@patch("meetmind.main.storage")
def test_end_meeting_success(mock_storage: AsyncMock, authed_client: TestClient) -> None:
    """End meeting returns completed status."""
    mock_storage.get_meeting = AsyncMock(
        return_value={"id": "m1", "title": "Test", "status": "recording"}
    )
    mock_storage.end_meeting = AsyncMock(
        return_value={"id": "m1", "title": "Test", "status": "completed"}
    )
    response = authed_client.post("/api/meetings/m1/end")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "completed"


@patch("meetmind.main.storage")
def test_end_meeting_not_found(mock_storage: AsyncMock, authed_client: TestClient) -> None:
    """End meeting returns 404 when meeting not found."""
    mock_storage.get_meeting = AsyncMock(return_value=None)
    response = authed_client.post("/api/meetings/nonexistent/end")
    assert response.status_code == 404


@patch("meetmind.main.storage")
def test_end_meeting_idempotent(mock_storage: AsyncMock, authed_client: TestClient) -> None:
    """End meeting returns already_completed for ended meetings."""
    mock_storage.get_meeting = AsyncMock(
        return_value={"id": "m1", "title": "Test", "status": "completed"}
    )
    response = authed_client.post("/api/meetings/m1/end")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "already_completed"


# ─── Password Reset ─────────────────────────────────────────────


@patch("meetmind.main.storage")
def test_forgot_password_existing_email(mock_storage: AsyncMock, client: TestClient) -> None:
    """Forgot password returns 200 for existing email."""
    mock_storage.get_user_by_email = AsyncMock(
        return_value={"id": "user-123", "email": "test@example.com"}
    )
    response = client.post(
        "/api/auth/forgot-password",
        json={"email": "test@example.com"},
    )
    assert response.status_code == 200
    assert "reset email" in response.json()["message"].lower()


@patch("meetmind.main.storage")
def test_forgot_password_nonexistent_email(mock_storage: AsyncMock, client: TestClient) -> None:
    """Forgot password returns 200 even for nonexistent email (anti-enumeration)."""
    mock_storage.get_user_by_email = AsyncMock(return_value=None)
    response = client.post(
        "/api/auth/forgot-password",
        json={"email": "nobody@example.com"},
    )
    assert response.status_code == 200


@patch("meetmind.main.storage")
def test_reset_password_success(mock_storage: AsyncMock, client: TestClient) -> None:
    """Reset password works with valid reset token."""
    from unittest.mock import MagicMock

    from meetmind.core.auth import create_reset_token

    token = create_reset_token(user_id="user-123")

    # Mock the asyncpg pool → acquire() → conn chain
    conn_mock = AsyncMock()
    ctx_mock = MagicMock()
    ctx_mock.__aenter__ = AsyncMock(return_value=conn_mock)
    ctx_mock.__aexit__ = AsyncMock(return_value=False)
    pool_mock = MagicMock()
    pool_mock.acquire.return_value = ctx_mock
    mock_storage.get_pool = AsyncMock(return_value=pool_mock)

    response = client.post(
        "/api/auth/reset-password",
        json={"token": token, "new_password": "newpass123"},
    )
    assert response.status_code == 200
    assert "reset successfully" in response.json()["message"].lower()


def test_reset_password_invalid_token(client: TestClient) -> None:
    """Reset password returns 400 for invalid token."""
    response = client.post(
        "/api/auth/reset-password",
        json={"token": "invalid-token", "new_password": "newpass123"},
    )
    assert response.status_code == 400


@patch("meetmind.main.storage")
def test_reset_password_wrong_purpose(mock_storage: AsyncMock, client: TestClient) -> None:
    """Reset password rejects tokens without password_reset purpose."""
    from meetmind.core.auth import create_access_token

    # Regular access token — wrong purpose
    token = create_access_token(user_id="user-123", email="test@example.com")
    response = client.post(
        "/api/auth/reset-password",
        json={"token": token, "new_password": "newpass123"},
    )
    assert response.status_code == 400
