"""Tests for email/password authentication flow."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from meetmind.core.auth import hash_password, verify_password


@pytest.fixture
def client() -> TestClient:
    """Create a test client without triggering lifespan."""
    from meetmind.main import app

    return TestClient(app, raise_server_exceptions=False)


# ─── Password Hashing Tests ─────────────────────────────────────


def test_password_hashing():
    """Verify password hashing and verification logic."""
    password = "secure_password_123"  # noqa: S105
    hashed = hash_password(password)

    # Should not be plain text
    assert password not in hashed
    # Should contain salt separator
    assert "$" in hashed

    # Verification success
    assert verify_password(password, hashed) is True
    # Verification failure
    assert verify_password("wrong_password", hashed) is False
    # Verification with bad hash format
    assert verify_password("password", "bad_hash_format") is False


# ─── Registration Endpoint Tests ────────────────────────────────


@patch("meetmind.main.storage")
def test_register_success(mock_storage: AsyncMock, client: TestClient):
    """Test successful user registration."""
    # Mock no existing user
    mock_storage.get_user_by_email = AsyncMock(return_value=None)

    # Mock upsert returning user
    mock_storage.upsert_user = AsyncMock(
        return_value={
            "id": "new-user-id",
            "email": "test@example.com",
            "name": "test",
            "avatar_url": None,
        }
    )

    # Mock pool acquire for password hash update
    mock_pool = MagicMock()
    mock_conn = AsyncMock()
    mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
    mock_storage.get_pool = AsyncMock(return_value=mock_pool)

    response = client.post(
        "/api/auth/register",
        json={"email": "test@example.com", "password": "password123", "name": "Test User"},
    )

    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["user"]["email"] == "test@example.com"

    # Verify storage calls
    mock_storage.get_user_by_email.assert_awaited_once_with("test@example.com")
    mock_storage.upsert_user.assert_awaited_once()
    # verify password hash update
    mock_conn.execute.assert_awaited_once()


@patch("meetmind.main.storage")
def test_register_existing_email(mock_storage: AsyncMock, client: TestClient):
    """Test registration with existing email fails."""
    # Mock existing user
    mock_storage.get_user_by_email = AsyncMock(return_value={"id": "existing-id"})

    response = client.post(
        "/api/auth/register", json={"email": "existing@example.com", "password": "password123"}
    )

    assert response.status_code == 409
    assert "already registered" in response.json()["detail"]


# ─── Login Endpoint Tests ───────────────────────────────────────


@patch("meetmind.main.storage")
def test_email_login_success(mock_storage: AsyncMock, client: TestClient):
    """Test successful email login."""
    password = "password123"  # noqa: S105
    hashed = hash_password(password)

    # Mock existing user with password hash
    mock_storage.get_user_by_email = AsyncMock(
        return_value={
            "id": "user-id",
            "email": "test@example.com",
            "password_hash": hashed,
            "name": "Test User",
            "avatar_url": None,
        }
    )

    # Mock pool for last_login update
    mock_pool = MagicMock()
    mock_conn = AsyncMock()
    mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
    mock_storage.get_pool = AsyncMock(return_value=mock_pool)

    response = client.post(
        "/api/auth/email-login", json={"email": "test@example.com", "password": password}
    )

    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data

    # Verify last_login update
    mock_conn.execute.assert_awaited_once()


@patch("meetmind.main.storage")
def test_email_login_wrong_password(mock_storage: AsyncMock, client: TestClient):
    """Test login with wrong password fails."""
    hashed = hash_password("correct_password")

    mock_storage.get_user_by_email = AsyncMock(
        return_value={
            "id": "user-id",
            "email": "test@example.com",
            "password_hash": hashed,
        }
    )

    response = client.post(
        "/api/auth/email-login", json={"email": "test@example.com", "password": "wrong_password"}
    )

    assert response.status_code == 401
    assert "Invalid email or password" in response.json()["detail"]


@patch("meetmind.main.storage")
def test_email_login_no_user(mock_storage: AsyncMock, client: TestClient):
    """Test login with non-existent email fails."""
    mock_storage.get_user_by_email = AsyncMock(return_value=None)

    response = client.post(
        "/api/auth/email-login",
        json={"email": "nonexistent@example.com", "password": "password123"},
    )

    assert response.status_code == 401
