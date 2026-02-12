"""MeetMind FastAPI application entry point."""

from fastapi import FastAPI

from meetmind.config.settings import settings

app = FastAPI(
    title="MeetMind API",
    description="AI-powered meeting assistant backend",
    version="0.1.0",
    debug=settings.debug,
)


@app.get("/health")
async def health_check() -> dict[str, str]:
    """Health check endpoint."""
    return {"status": "healthy", "environment": settings.environment}
