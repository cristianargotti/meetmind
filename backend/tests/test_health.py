"""Tests for MeetMind health check endpoint."""

from fastapi.testclient import TestClient

from meetmind.main import app


def test_health_check() -> None:
    """Health check returns healthy status."""
    # Arrange
    client = TestClient(app)

    # Act
    response = client.get("/health")

    # Assert
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "environment" in data
