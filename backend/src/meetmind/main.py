"""MeetMind FastAPI application entry point."""

from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager
from typing import Any

import structlog
from fastapi import FastAPI, HTTPException, WebSocket
from starlette.middleware.cors import CORSMiddleware

from meetmind.api.websocket import manager, websocket_transcription
from meetmind.config.logging import setup_logging
from meetmind.config.settings import settings
from meetmind.core import storage

logger = structlog.get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Application lifespan — setup logging, DB, and AI agents on startup."""
    setup_logging()

    # Initialize PostgreSQL + pgvector
    try:
        await storage.init_db()
        logger.info("database_ready")
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


app = FastAPI(
    title="MeetMind API",
    description="AI-powered meeting assistant backend",
    version="0.2.0",
    debug=settings.debug,
    lifespan=lifespan,
)


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ─── Health ───────────────────────────────────────────────────────


@app.get("/health")
async def health_check() -> dict[str, str]:
    """Health check endpoint."""
    return {"status": "healthy", "environment": settings.environment}


# ─── Meetings REST API ───────────────────────────────────────────


@app.get("/api/meetings")
async def list_meetings(
    limit: int = 50,
    offset: int = 0,
) -> dict[str, Any]:
    """List all meetings, most recent first.

    Args:
        limit: Maximum number of meetings to return.
        offset: Pagination offset.

    Returns:
        Dict with meetings list and pagination info.
    """
    meetings = await storage.list_meetings(limit=limit, offset=offset)
    return {"meetings": meetings, "limit": limit, "offset": offset}


@app.get("/api/meetings/{meeting_id}")
async def get_meeting(meeting_id: str) -> dict[str, Any]:
    """Get a single meeting with transcript, insights, and summary.

    Args:
        meeting_id: The unique meeting identifier.

    Returns:
        Complete meeting data.

    Raises:
        HTTPException: If meeting not found.
    """
    meeting = await storage.get_meeting(meeting_id)
    if not meeting:
        raise HTTPException(status_code=404, detail="Meeting not found")
    return meeting


@app.delete("/api/meetings/{meeting_id}")
async def delete_meeting(meeting_id: str) -> dict[str, str]:
    """Delete a meeting and all related data.

    Args:
        meeting_id: The unique meeting identifier.

    Returns:
        Confirmation message.

    Raises:
        HTTPException: If meeting not found.
    """
    deleted = await storage.delete_meeting(meeting_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Meeting not found")
    return {"status": "deleted", "meeting_id": meeting_id}


# ─── Action Items ────────────────────────────────────────────────


@app.get("/api/action-items")
async def get_pending_actions(limit: int = 50) -> dict[str, Any]:
    """Get all pending action items across meetings.

    Args:
        limit: Maximum number of items to return.

    Returns:
        List of pending action items.
    """
    items = await storage.get_pending_action_items(limit=limit)
    return {"action_items": items, "count": len(items)}


@app.patch("/api/action-items/{item_id}")
async def update_action_item(
    item_id: int,
    status: str = "done",
) -> dict[str, Any]:
    """Update an action item's status.

    Args:
        item_id: The action item ID.
        status: New status ('pending' or 'done').

    Returns:
        Updated status.
    """
    updated = await storage.update_action_item(item_id, status)
    if not updated:
        raise HTTPException(status_code=404, detail="Action item not found")
    return {"id": item_id, "status": status}


# ─── Dashboard Stats ─────────────────────────────────────────────


@app.get("/api/stats")
async def get_stats() -> dict[str, Any]:
    """Get dashboard statistics.

    Returns:
        Aggregated stats for the home dashboard.
    """
    return await storage.get_stats()


# ─── WebSocket ───────────────────────────────────────────────────


@app.websocket("/ws/transcription")
async def ws_transcription(websocket: WebSocket) -> None:
    """WebSocket endpoint for real-time meeting transcription."""
    await websocket_transcription(websocket)


@app.websocket("/ws")
async def ws_alias(websocket: WebSocket) -> None:
    """WebSocket alias for Chrome Extension compatibility."""
    await websocket_transcription(websocket)
