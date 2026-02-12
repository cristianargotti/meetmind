"""MeetMind FastAPI application entry point."""

from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from fastapi import FastAPI, WebSocket

from meetmind.api.websocket import websocket_transcription
from meetmind.config.logging import setup_logging
from meetmind.config.settings import settings


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Application lifespan — setup logging on startup."""
    setup_logging()
    yield


app = FastAPI(
    title="MeetMind API",
    description="AI-powered meeting assistant backend",
    version="0.1.0",
    debug=settings.debug,
    lifespan=lifespan,
)


@app.get("/health")
async def health_check() -> dict[str, str]:
    """Health check endpoint."""
    return {"status": "healthy", "environment": settings.environment}


@app.websocket("/ws/transcription")
async def ws_transcription(websocket: WebSocket) -> None:
    """WebSocket endpoint for real-time meeting transcription."""
    await websocket_transcription(websocket)
