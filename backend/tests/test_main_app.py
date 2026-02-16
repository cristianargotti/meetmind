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


# ─── Health ──────────────────────────────────────────────────────


def test_health_check(client: TestClient) -> None:
    """Health endpoint returns healthy status."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"


# ─── Meetings ───────────────────────────────────────────────────


@patch("meetmind.main.storage")
def test_list_meetings(mock_storage: AsyncMock, client: TestClient) -> None:
    """List meetings returns paginated results."""
    mock_storage.list_meetings = AsyncMock(
        return_value=[
            {"id": "m1", "title": "Test Meeting"},
        ]
    )
    response = client.get("/api/meetings?limit=10&offset=0")
    assert response.status_code == 200
    data = response.json()
    assert "meetings" in data
    assert data["limit"] == 10
    assert data["offset"] == 0


@patch("meetmind.main.storage")
def test_get_meeting_found(mock_storage: AsyncMock, client: TestClient) -> None:
    """Get meeting returns data when found."""
    mock_storage.get_meeting = AsyncMock(
        return_value={
            "id": "m1",
            "title": "Test Meeting",
            "segments": [],
        }
    )
    response = client.get("/api/meetings/m1")
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == "m1"


@patch("meetmind.main.storage")
def test_get_meeting_not_found(mock_storage: AsyncMock, client: TestClient) -> None:
    """Get meeting returns 404 when not found."""
    mock_storage.get_meeting = AsyncMock(return_value=None)
    response = client.get("/api/meetings/nonexistent")
    assert response.status_code == 404


@patch("meetmind.main.storage")
def test_delete_meeting_success(mock_storage: AsyncMock, client: TestClient) -> None:
    """Delete meeting returns confirmation."""
    mock_storage.delete_meeting = AsyncMock(return_value=True)
    response = client.delete("/api/meetings/m1")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "deleted"


@patch("meetmind.main.storage")
def test_delete_meeting_not_found(mock_storage: AsyncMock, client: TestClient) -> None:
    """Delete meeting returns 404 when not found."""
    mock_storage.delete_meeting = AsyncMock(return_value=False)
    response = client.delete("/api/meetings/nonexistent")
    assert response.status_code == 404


# ─── Action Items ────────────────────────────────────────────────


@patch("meetmind.main.storage")
def test_get_pending_actions(mock_storage: AsyncMock, client: TestClient) -> None:
    """Get pending action items returns list."""
    mock_storage.get_pending_action_items = AsyncMock(
        return_value=[
            {"id": 1, "text": "Follow up", "status": "pending"},
        ]
    )
    response = client.get("/api/action-items?limit=10")
    assert response.status_code == 200
    data = response.json()
    assert data["count"] == 1


@patch("meetmind.main.storage")
def test_update_action_item_success(mock_storage: AsyncMock, client: TestClient) -> None:
    """Update action item returns new status."""
    mock_storage.update_action_item = AsyncMock(return_value=True)
    response = client.patch("/api/action-items/1?status=done")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "done"


@patch("meetmind.main.storage")
def test_update_action_item_not_found(mock_storage: AsyncMock, client: TestClient) -> None:
    """Update action item returns 404 when not found."""
    mock_storage.update_action_item = AsyncMock(return_value=False)
    response = client.patch("/api/action-items/999?status=done")
    assert response.status_code == 404


# ─── Stats ───────────────────────────────────────────────────────


@patch("meetmind.main.storage")
def test_get_stats(mock_storage: AsyncMock, client: TestClient) -> None:
    """Get stats returns dashboard data."""
    mock_storage.get_stats = AsyncMock(
        return_value={
            "total_meetings": 5,
            "total_insights": 12,
            "total_cost_usd": 0.50,
        }
    )
    response = client.get("/api/stats")
    assert response.status_code == 200
    data = response.json()
    assert "total_meetings" in data
