"""Authentication — Google + Apple OAuth verification and JWT token management.

Zero-cost auth system:
  - Google/Apple OAuth id_tokens verified against provider public keys
  - Our own HS256 JWTs issued for API access
  - Minimal data: email, name, avatar — Apple App Store compliant
"""

from __future__ import annotations

import secrets
from datetime import UTC, datetime, timedelta
from typing import Any

import httpx
import jwt
import structlog
from fastapi import Depends, HTTPException, WebSocket, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from meetmind.config.settings import settings

logger = structlog.get_logger(__name__)

# ─── Security Scheme ────────────────────────────────────────────

_bearer_scheme = HTTPBearer(auto_error=False)

# ─── JWT Secret ─────────────────────────────────────────────────

_jwt_secret: str | None = None


def _get_jwt_secret() -> str:
    """Get or generate the JWT secret key."""
    global _jwt_secret
    if _jwt_secret:
        return _jwt_secret
    if settings.jwt_secret_key:
        _jwt_secret = settings.jwt_secret_key
    else:
        _jwt_secret = secrets.token_hex(32)
        logger.warning("jwt_secret_auto_generated", hint="Set MEETMIND_JWT_SECRET_KEY in .env")
    return _jwt_secret


# ─── Token Creation ─────────────────────────────────────────────


def create_access_token(user_id: str, email: str) -> str:
    """Create a short-lived access token (15 min)."""
    payload = {
        "sub": user_id,
        "email": email,
        "type": "access",
        "iat": datetime.now(UTC),
        "exp": datetime.now(UTC) + timedelta(minutes=settings.jwt_access_minutes),
    }
    return jwt.encode(payload, _get_jwt_secret(), algorithm="HS256")


def create_refresh_token(user_id: str) -> str:
    """Create a long-lived refresh token (30 days)."""
    payload = {
        "sub": user_id,
        "type": "refresh",
        "iat": datetime.now(UTC),
        "exp": datetime.now(UTC) + timedelta(days=settings.jwt_refresh_days),
    }
    return jwt.encode(payload, _get_jwt_secret(), algorithm="HS256")


def decode_token(token: str) -> dict[str, Any]:
    """Decode and validate a JWT token."""
    try:
        return jwt.decode(token, _get_jwt_secret(), algorithms=["HS256"])
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token expired",
        ) from None
    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
        ) from None


# ─── Google Token Verification ──────────────────────────────────

_google_certs_cache: dict[str, Any] = {}
_google_certs_expiry: datetime | None = None

GOOGLE_CERTS_URL = "https://www.googleapis.com/oauth2/v3/certs"
GOOGLE_ISSUERS = ("https://accounts.google.com", "accounts.google.com")


async def _get_google_public_keys() -> dict[str, Any]:
    """Fetch and cache Google's public keys (JWKS)."""
    global _google_certs_cache, _google_certs_expiry
    now = datetime.now(UTC)
    if _google_certs_cache and _google_certs_expiry and now < _google_certs_expiry:
        return _google_certs_cache

    async with httpx.AsyncClient() as client:
        resp = await client.get(GOOGLE_CERTS_URL)
        resp.raise_for_status()
        _google_certs_cache = resp.json()
        # Cache for 6 hours
        _google_certs_expiry = now + timedelta(hours=6)

    return _google_certs_cache


async def verify_google_token(id_token: str) -> dict[str, Any]:
    """Verify a Google id_token and return user info.

    Returns:
        Dict with: sub, email, name, picture
    """
    jwks = await _get_google_public_keys()

    try:
        # Decode header to get key ID
        header = jwt.get_unverified_header(id_token)
        kid = header.get("kid")

        # Find matching key
        key_data = None
        for key in jwks.get("keys", []):
            if key.get("kid") == kid:
                key_data = key
                break

        if not key_data:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Google token key not found",
            )

        # Build public key and verify
        from jwt.algorithms import RSAAlgorithm  # type: ignore[import-untyped]

        public_key = RSAAlgorithm.from_jwk(key_data)

        payload = jwt.decode(
            id_token,
            public_key,  # type: ignore[arg-type]
            algorithms=["RS256"],
            audience=settings.google_client_id,
            issuer=GOOGLE_ISSUERS,
        )

        return {
            "sub": payload["sub"],
            "email": payload.get("email", ""),
            "name": payload.get("name", ""),
            "picture": payload.get("picture", ""),
        }

    except jwt.InvalidTokenError as e:
        logger.warning("google_token_invalid", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid Google token: {e}",
        ) from None


# ─── Apple Token Verification ───────────────────────────────────

_apple_certs_cache: dict[str, Any] = {}
_apple_certs_expiry: datetime | None = None

APPLE_KEYS_URL = "https://appleid.apple.com/auth/keys"
APPLE_ISSUER = "https://appleid.apple.com"


async def _get_apple_public_keys() -> dict[str, Any]:
    """Fetch and cache Apple's public keys (JWKS)."""
    global _apple_certs_cache, _apple_certs_expiry
    now = datetime.now(UTC)
    if _apple_certs_cache and _apple_certs_expiry and now < _apple_certs_expiry:
        return _apple_certs_cache

    async with httpx.AsyncClient() as client:
        resp = await client.get(APPLE_KEYS_URL)
        resp.raise_for_status()
        _apple_certs_cache = resp.json()
        _apple_certs_expiry = now + timedelta(hours=6)

    return _apple_certs_cache


async def verify_apple_token(id_token: str) -> dict[str, Any]:
    """Verify an Apple id_token and return user info.

    Returns:
        Dict with: sub, email, name (may be empty for Apple)
    """
    jwks = await _get_apple_public_keys()

    try:
        header = jwt.get_unverified_header(id_token)
        kid = header.get("kid")

        key_data = None
        for key in jwks.get("keys", []):
            if key.get("kid") == kid:
                key_data = key
                break

        if not key_data:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Apple token key not found",
            )

        from jwt.algorithms import RSAAlgorithm  # type: ignore[import-untyped]

        public_key = RSAAlgorithm.from_jwk(key_data)

        # Apple uses bundle_id as audience
        audience = settings.apple_bundle_id or settings.apple_service_id

        payload = jwt.decode(
            id_token,
            public_key,  # type: ignore[arg-type]
            algorithms=["RS256"],
            audience=audience,
            issuer=APPLE_ISSUER,
        )

        return {
            "sub": payload["sub"],
            "email": payload.get("email", ""),
            "name": "",  # Apple sends name only on first login (handled in client)
            "picture": "",
        }

    except jwt.InvalidTokenError as e:
        logger.warning("apple_token_invalid", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid Apple token: {e}",
        ) from None


# ─── FastAPI Dependencies ───────────────────────────────────────


_current_user_dep = Depends(_bearer_scheme)


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = _current_user_dep,
) -> dict[str, Any]:
    """Require authentication — returns user payload or raises 401."""
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
            headers={"WWW-Authenticate": "Bearer"},
        )

    payload = decode_token(credentials.credentials)
    if payload.get("type") != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token type",
        )

    return {"user_id": payload["sub"], "email": payload.get("email", "")}


async def get_optional_user(
    credentials: HTTPAuthorizationCredentials | None = _current_user_dep,
) -> dict[str, Any] | None:
    """Optional authentication — returns user payload or None."""
    if not credentials:
        return None
    try:
        payload = decode_token(credentials.credentials)
        if payload.get("type") != "access":
            return None
        return {"user_id": payload["sub"], "email": payload.get("email", "")}
    except HTTPException:
        return None


async def get_ws_user(websocket: WebSocket) -> dict[str, Any] | None:
    """Extract user from WebSocket query param ?token=xxx."""
    token = websocket.query_params.get("token")
    if not token:
        return None
    try:
        payload = decode_token(token)
        return {"user_id": payload["sub"], "email": payload.get("email", "")}
    except HTTPException:
        return None
