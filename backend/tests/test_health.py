"""Tests for MeetMind health check endpoint."""

from unittest.mock import AsyncMock, MagicMock, patch

from fastapi.testclient import TestClient

from meetmind.main import app


@patch("meetmind.main.storage")
def test_health_check(mock_storage: AsyncMock) -> None:
    """Health check returns healthy status when DB is connected."""
    # Mock the asyncpg pool → acquire() → conn chain
    conn_mock = AsyncMock()
    conn_mock.fetchval = AsyncMock(return_value=1)
    ctx_mock = MagicMock()
    ctx_mock.__aenter__ = AsyncMock(return_value=conn_mock)
    ctx_mock.__aexit__ = AsyncMock(return_value=False)
    pool_mock = MagicMock()
    pool_mock.acquire.return_value = ctx_mock
    mock_storage.get_pool = AsyncMock(return_value=pool_mock)

    client = TestClient(app)
    response = client.get("/health")

    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["database"] == "connected"
    assert "environment" in data


@patch("meetmind.main.storage")
def test_health_check_db_down(mock_storage: AsyncMock) -> None:
    """Health check returns degraded status when DB is unreachable."""
    mock_storage.get_pool = AsyncMock(
        side_effect=ConnectionError("Connection refused")
    )

    client = TestClient(app)
    response = client.get("/health")

    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "degraded"
    assert "error" in data["database"]
