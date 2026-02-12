"""MeetMind FastAPI application entry point."""

from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

import structlog
from fastapi import FastAPI, WebSocket
from starlette.middleware.cors import CORSMiddleware

from meetmind.api.websocket import manager, websocket_transcription
from meetmind.config.logging import setup_logging
from meetmind.config.settings import settings

logger = structlog.get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Application lifespan — setup logging and AI agents on startup."""
    setup_logging()

    # Initialize AI agents (graceful fallback if no AWS credentials)
    try:
        manager.init_agents()
        logger.info("ai_agents_ready")
    except Exception as e:
        logger.warning("ai_agents_failed", error=str(e))

    yield


app = FastAPI(
    title="MeetMind API",
    description="AI-powered meeting assistant backend",
    version="0.1.0",
    debug=settings.debug,
    lifespan=lifespan,
)


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health_check() -> dict[str, str]:
    """Health check endpoint."""
    return {"status": "healthy", "environment": settings.environment}


@app.websocket("/ws/transcription")
async def ws_transcription(websocket: WebSocket) -> None:
    """WebSocket endpoint for real-time meeting transcription."""
    await websocket_transcription(websocket)


@app.websocket("/ws")
async def ws_alias(websocket: WebSocket) -> None:
    """WebSocket alias for Chrome Extension compatibility."""
    await websocket_transcription(websocket)
