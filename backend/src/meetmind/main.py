"""Aura Meet FastAPI application entry point."""

from __future__ import annotations

import asyncio
import uuid
from contextlib import asynccontextmanager
from typing import TYPE_CHECKING, Any

import structlog
from fastapi import Depends, FastAPI, HTTPException, Request, WebSocket
from pydantic import BaseModel, EmailStr, field_validator
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address
from starlette.middleware.cors import CORSMiddleware

if TYPE_CHECKING:
    from collections.abc import AsyncGenerator

from meetmind.api.websocket import manager, websocket_transcription
from meetmind.config.logging import setup_logging
from meetmind.config.settings import settings
from meetmind.core import storage
from meetmind.core.auth import (
    create_access_token,
    create_refresh_token,
    create_reset_token,
    decode_token,
    get_current_user,
    hash_password,
    verify_apple_token,
    verify_google_token,
    verify_password,
)

logger = structlog.get_logger(__name__)


# ─── Request / Response Models ───────────────────────────────────


class AuthLoginRequest(BaseModel):
    """OAuth login request — exchange provider id_token for our JWT."""

    provider: str  # "google" | "apple"
    id_token: str
    name: str | None = None  # Apple sends name only on first login


class AuthTokenResponse(BaseModel):
    """JWT token pair response."""

    access_token: str
    refresh_token: str
    token_type: str = "bearer"  # noqa: S105
    user: dict[str, Any]


# Module-level dependency to satisfy B008 (no function calls in defaults)
_auth_dep = Depends(get_current_user)


class RefreshRequest(BaseModel):
    """Token refresh request."""

    refresh_token: str


class EmailRegisterRequest(BaseModel):
    """Email registration request."""

    email: EmailStr
    password: str
    name: str | None = None

    @field_validator("password")
    @classmethod
    def password_min_length(cls, v: str) -> str:
        """Enforce minimum password length."""
        if len(v) < 8:
            msg = "Password must be at least 8 characters"
            raise ValueError(msg)
        return v


class EmailLoginRequest(BaseModel):
    """Email login request."""

    email: EmailStr
    password: str


# ─── Lifespan ────────────────────────────────────────────────────


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Application lifespan — setup logging, DB, and AI agents on startup."""
    setup_logging()

    # Initialize PostgreSQL + pgvector
    try:
        await asyncio.wait_for(storage.init_db(), timeout=10)
        logger.info("database_ready")
    except TimeoutError:
        logger.warning("database_init_failed", error="connection timeout (10s)")
    except Exception as e:
        logger.warning("database_init_failed", error=str(e))

    # Initialize AI agents (graceful fallback if no credentials)
    try:
        manager.init_agents()
        logger.info("ai_agents_ready")
    except Exception as e:
        logger.warning("ai_agents_failed", error=str(e))

    yield

    # Cleanup
    await storage.close_db()


# ─── Rate Limiter ────────────────────────────────────────────────

limiter = Limiter(key_func=get_remote_address)

app = FastAPI(
    title="Aura Meet API",
    description="AI-powered meeting assistant backend",
    version="0.5.0",
    debug=settings.debug,
    lifespan=lifespan,
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)  # type: ignore[arg-type]

app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in settings.cors_origins.split(",")],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=[
        "Authorization",
        "Content-Type",
        "Accept",
        "Origin",
        "X-Requested-With",
    ],
)


# ─── Health ──────────────────────────────────────────────────────


@app.get("/health")
async def health_check() -> dict[str, object]:
    """Health check endpoint with database connectivity verification."""
    result: dict[str, object] = {
        "status": "healthy",
        "environment": settings.environment,
    }
    try:
        pool = await storage.get_pool()
        async with pool.acquire() as conn:
            await conn.fetchval("SELECT 1")
        result["database"] = "connected"
    except Exception as e:
        result["status"] = "degraded"
        result["database"] = f"error: {e!s}"
        logger.warning("health_check_db_error", error=str(e))
    return result


# ─── Auth ────────────────────────────────────────────────────────


@app.post("/api/auth/login")
@limiter.limit("5/minute")
async def auth_login(request: Request, body: AuthLoginRequest) -> AuthTokenResponse:
    """Exchange a Google/Apple id_token for our JWT tokens.

    Args:
        body: Provider name and id_token from OAuth flow.

    Returns:
        Access + refresh tokens and user profile.
    """
    if body.provider == "google":
        provider_user = await verify_google_token(body.id_token)
    elif body.provider == "apple":
        provider_user = await verify_apple_token(body.id_token)
    else:
        raise HTTPException(status_code=400, detail="Unsupported provider")

    # Check if user already exists
    existing = await storage.get_user_by_provider(
        provider=body.provider,
        provider_id=provider_user["sub"],
    )

    user_id = existing["id"] if existing else str(uuid.uuid4())
    user_name = body.name or provider_user.get("name", "")

    user = await storage.upsert_user(
        user_id=user_id,
        email=provider_user["email"],
        name=user_name or None,
        avatar_url=provider_user.get("picture") or None,
        provider=body.provider,
        provider_id=provider_user["sub"],
    )

    logger.info(
        "auth_login_success",
        user_id=user_id,
        provider=body.provider,
        is_new=existing is None,
    )

    return AuthTokenResponse(
        access_token=create_access_token(user_id, user["email"]),
        refresh_token=create_refresh_token(user_id),
        user={
            "id": user["id"],
            "email": user["email"],
            "name": user.get("name", ""),
            "avatar_url": user.get("avatar_url", ""),
        },
    )


@app.post("/api/auth/register")
@limiter.limit("3/minute")
async def auth_register(request: Request, body: EmailRegisterRequest) -> AuthTokenResponse:
    """Register a new user with email and password."""
    existing = await storage.get_user_by_email(body.email)
    if existing:
        raise HTTPException(status_code=409, detail="Email already registered")

    user_id = str(uuid.uuid4())
    password_hash = hash_password(body.password)

    user = await storage.upsert_user(
        user_id=user_id,
        email=body.email,
        name=body.name or body.email.split("@")[0],
        avatar_url=None,
        provider="email",
        provider_id=body.email,
    )

    # Store the password hash
    pool = await storage.get_pool()
    async with pool.acquire() as conn:
        await conn.execute(
            "UPDATE users SET password_hash = $1 WHERE id = $2",
            password_hash,
            user_id,
        )

    logger.info("auth_register_success", user_id=user_id)

    return AuthTokenResponse(
        access_token=create_access_token(user_id, user["email"]),
        refresh_token=create_refresh_token(user_id),
        user={
            "id": user["id"],
            "email": user["email"],
            "name": user.get("name", ""),
            "avatar_url": user.get("avatar_url", ""),
        },
    )


@app.post("/api/auth/email-login")
@limiter.limit("5/minute")
async def auth_email_login(request: Request, body: EmailLoginRequest) -> AuthTokenResponse:
    """Login with email and password."""
    user = await storage.get_user_by_email(body.email)
    if not user or not user.get("password_hash"):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    if not verify_password(body.password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    # Update last_login
    pool = await storage.get_pool()
    async with pool.acquire() as conn:
        await conn.execute(
            "UPDATE users SET last_login = NOW() WHERE id = $1",
            user["id"],
        )

    logger.info("auth_email_login_success", user_id=user["id"])

    return AuthTokenResponse(
        access_token=create_access_token(user["id"], user["email"]),
        refresh_token=create_refresh_token(user["id"]),
        user={
            "id": user["id"],
            "email": user["email"],
            "name": user.get("name", ""),
            "avatar_url": user.get("avatar_url", ""),
        },
    )


@app.post("/api/auth/refresh")
@limiter.limit("10/minute")
async def auth_refresh(request: Request, body: RefreshRequest) -> dict[str, str]:
    """Get new access + refresh tokens using a refresh token (rotation).

    Args:
        body: Refresh token.

    Returns:
        New access and refresh tokens.
    """
    payload = decode_token(body.refresh_token)
    if payload.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    user = await storage.get_user(payload["sub"])
    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    return {
        "access_token": create_access_token(user["id"], user["email"]),
        "refresh_token": create_refresh_token(user["id"]),
        "token_type": "bearer",
    }


@app.get("/api/auth/me")
@limiter.limit("30/minute")
async def auth_me(
    request: Request,
    current_user: dict[str, Any] = _auth_dep,
) -> dict[str, Any]:
    """Get the current authenticated user profile.

    Returns:
        User profile data.
    """
    user = await storage.get_user(current_user["user_id"])
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return {
        "id": user["id"],
        "email": user["email"],
        "name": user.get("name", ""),
        "avatar_url": user.get("avatar_url", ""),
        "provider": user["provider"],
        "created_at": str(user["created_at"]),
    }


@app.delete("/api/auth/account")
@limiter.limit("3/minute")
async def auth_delete_account(
    request: Request,
    current_user: dict[str, Any] = _auth_dep,
) -> dict[str, str]:
    """Delete the current user account and ALL associated data.

    Apple App Store requirement: users must be able to delete their account.
    Cascading delete removes all meetings, transcripts, insights, summaries.

    Returns:
        Confirmation message.
    """
    deleted = await storage.delete_user_account(current_user["user_id"])
    if not deleted:
        raise HTTPException(status_code=404, detail="Account not found")
    return {"status": "deleted", "message": "Account and all data permanently removed"}


# ─── Meetings REST API (Protected) ──────────────────────────────


@app.get("/api/meetings")
@limiter.limit("30/minute")
async def list_meetings(
    request: Request,
    limit: int = 50,
    offset: int = 0,
    current_user: dict[str, Any] = _auth_dep,
) -> dict[str, Any]:
    """List meetings for the authenticated user, most recent first.

    Args:
        limit: Maximum number of meetings to return.
        offset: Pagination offset.
        current_user: Injected by auth dependency.

    Returns:
        Dict with meetings list and pagination info.
    """
    meetings = await storage.list_meetings(
        limit=limit,
        offset=offset,
        user_id=current_user["user_id"],
    )
    return {"meetings": meetings, "limit": limit, "offset": offset}


@app.get("/api/meetings/{meeting_id}")
@limiter.limit("30/minute")
async def get_meeting(
    request: Request,
    meeting_id: str,
    current_user: dict[str, Any] = _auth_dep,
) -> dict[str, Any]:
    """Get a single meeting with transcript, insights, and summary.

    Args:
        meeting_id: The unique meeting identifier.
        current_user: Injected by auth dependency.

    Returns:
        Complete meeting data.

    Raises:
        HTTPException: If meeting not found or not owned by user.
    """
    meeting = await storage.get_meeting(meeting_id)
    if not meeting:
        raise HTTPException(status_code=404, detail="Meeting not found")
    if meeting.get("user_id") and meeting["user_id"] != current_user["user_id"]:
        raise HTTPException(status_code=404, detail="Meeting not found")
    return meeting


@app.delete("/api/meetings/{meeting_id}")
@limiter.limit("10/minute")
async def delete_meeting(
    request: Request,
    meeting_id: str,
    current_user: dict[str, Any] = _auth_dep,
) -> dict[str, str]:
    """Delete a meeting and all related data.

    Args:
        meeting_id: The unique meeting identifier.
        current_user: Injected by auth dependency.

    Returns:
        Confirmation message.

    Raises:
        HTTPException: If meeting not found or not owned by user.
    """
    # Verify ownership before deleting
    meeting = await storage.get_meeting(meeting_id)
    if not meeting:
        raise HTTPException(status_code=404, detail="Meeting not found")
    if meeting.get("user_id") and meeting["user_id"] != current_user["user_id"]:
        raise HTTPException(status_code=404, detail="Meeting not found")
    deleted = await storage.delete_meeting(meeting_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Meeting not found")
    return {"status": "deleted", "meeting_id": meeting_id}


@app.post("/api/meetings/{meeting_id}/end")
@limiter.limit("10/minute")
async def end_meeting_endpoint(
    request: Request,
    meeting_id: str,
    title: str | None = None,
    duration_secs: int | None = None,
    current_user: dict[str, Any] = _auth_dep,
) -> dict[str, Any]:
    """End a meeting and finalize its metadata.

    Idempotent — returns existing data if already ended.

    Args:
        meeting_id: The unique meeting identifier.
        title: Optional title for the meeting.
        duration_secs: Meeting duration in seconds.
        current_user: Injected by auth dependency.

    Returns:
        Final meeting data with stats.

    Raises:
        HTTPException: If meeting not found.
    """
    # Check meeting exists and verify ownership
    meeting = await storage.get_meeting(meeting_id)
    if not meeting:
        raise HTTPException(status_code=404, detail="Meeting not found")
    if meeting.get("user_id") and meeting["user_id"] != current_user["user_id"]:
        raise HTTPException(status_code=404, detail="Meeting not found")

    # Already ended — idempotent
    if meeting.get("status") == "completed":
        return {"status": "already_completed", "meeting": meeting}

    result = await storage.end_meeting(
        meeting_id,
        title=title,
        duration_secs=duration_secs,
    )
    return {"status": "completed", "meeting": result}


# ─── Password Reset ─────────────────────────────────────────────


class ForgotPasswordRequest(BaseModel):
    """Forgot password request."""

    email: EmailStr


class ResetPasswordRequest(BaseModel):
    """Reset password request."""

    token: str
    new_password: str


@app.post("/api/auth/forgot-password")
@limiter.limit("3/minute")
async def forgot_password(request: Request, body: ForgotPasswordRequest) -> dict[str, str]:
    """Request a password reset email.

    Args:
        body: Email address to send reset link to.

    Returns:
        Confirmation message (always 200 to prevent email enumeration).
    """
    user = await storage.get_user_by_email(body.email)
    if user:
        # Generate reset token (30 min expiry)
        reset_token = create_reset_token(user_id=user["id"])
        logger.info(
            "password_reset_requested",
            email=body.email,
            token=reset_token[:8] + "...",
        )
        # TODO: Send email with reset_token via SES/SendGrid

    # Always return 200 to prevent email enumeration attacks
    return {"message": "If an account exists, a reset email has been sent."}


@app.post("/api/auth/reset-password")
@limiter.limit("3/minute")
async def reset_password(request: Request, body: ResetPasswordRequest) -> dict[str, str]:
    """Reset password using a valid reset token.

    Args:
        body: Reset token and new password.

    Returns:
        Confirmation message.

    Raises:
        HTTPException: If token is invalid or expired.
    """
    try:
        payload = decode_token(body.token)
    except HTTPException:
        raise HTTPException(status_code=400, detail="Invalid or expired reset token") from None

    if payload.get("purpose") != "password_reset":
        raise HTTPException(status_code=400, detail="Invalid token purpose")

    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=400, detail="Invalid token")

    # Update password
    hashed = hash_password(body.new_password)
    pool = await storage.get_pool()
    async with pool.acquire() as conn:
        await conn.execute(
            "UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2",
            hashed,
            user_id,
        )

    logger.info("password_reset_completed", user_id=user_id)
    return {"message": "Password has been reset successfully."}


# ─── Action Items ────────────────────────────────────────────────


@app.get("/api/action-items")
@limiter.limit("30/minute")
async def get_pending_actions(
    request: Request,
    limit: int = 50,
    current_user: dict[str, Any] = _auth_dep,
) -> dict[str, Any]:
    """Get all pending action items across meetings.

    Args:
        limit: Maximum number of items to return.
        current_user: Injected by auth dependency.

    Returns:
        List of pending action items.
    """
    items = await storage.get_pending_action_items(
        limit=limit,
        user_id=current_user["user_id"],
    )
    return {"action_items": items, "count": len(items)}


@app.patch("/api/action-items/{item_id}")
@limiter.limit("30/minute")
async def update_action_item(
    request: Request,
    item_id: int,
    status: str = "done",
    current_user: dict[str, Any] = _auth_dep,
) -> dict[str, Any]:
    """Update an action item's status.

    Args:
        item_id: The action item ID.
        status: New status ('pending' or 'done').
        current_user: Injected by auth dependency.

    Returns:
        Updated status.
    """
    updated = await storage.update_action_item(item_id, status)
    if not updated:
        raise HTTPException(status_code=404, detail="Action item not found")
    return {"id": item_id, "status": status}


# ─── Dashboard Stats ────────────────────────────────────────────


@app.get("/api/stats")
@limiter.limit("30/minute")
async def get_stats(
    request: Request,
    current_user: dict[str, Any] = _auth_dep,
) -> dict[str, Any]:
    """Get dashboard statistics for the authenticated user.

    Returns:
        Aggregated stats for the home dashboard.
    """
    return await storage.get_stats(user_id=current_user["user_id"])


# ─── WebSocket ───────────────────────────────────────────────────


@app.websocket("/ws/transcription")
async def ws_transcription(websocket: WebSocket) -> None:
    """WebSocket endpoint for real-time meeting transcription."""
    await websocket_transcription(websocket)


@app.websocket("/ws")
async def ws_alias(websocket: WebSocket) -> None:
    """WebSocket alias for Chrome Extension compatibility."""
    await websocket_transcription(websocket)
