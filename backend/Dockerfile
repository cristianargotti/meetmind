# =============================================================================
# MeetMind Backend — Production Dockerfile
# AI-powered Meeting Assistant with faster-whisper STT
#
# Follows Astral's official uv multi-stage Docker best practices (2026)
# Pattern from: DARA (Dafiti Automated Response Agent)
# =============================================================================

# =============================================================================
# BUILDER: Build the application with uv
# =============================================================================
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim AS builder

# Compile bytecode for faster startup
ENV UV_COMPILE_BYTECODE=1

# Copy files instead of linking (required for multi-stage builds)
ENV UV_LINK_MODE=copy

# Omit development dependencies in production
ENV UV_NO_DEV=1

# Use system Python interpreter (must match runner image)
ENV UV_PYTHON_DOWNLOADS=0

WORKDIR /app

# Install dependencies first (better layer caching)
# Using --mount for efficient caching of uv downloads
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project

# Copy project source and install (separate layer for optimal caching)
COPY . /app
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked

# =============================================================================
# RUNNER: Production-ready minimal image
# =============================================================================
# IMPORTANT: Must match the Python version in builder (3.12-bookworm-slim)
FROM python:3.12-slim-bookworm AS runner

# Install curl for health checks and system audio libs
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

# Setup non-root user (security best practice)
RUN groupadd --system --gid 999 meetmind \
    && useradd --system --gid 999 --uid 999 --create-home meetmind

# Copy the application from builder with correct ownership
COPY --from=builder --chown=meetmind:meetmind /app /app

# Place executables in the environment at the front of the path
ENV PATH="/app/.venv/bin:$PATH"

# Set PYTHONPATH for source imports
ENV PYTHONPATH=/app/src

# Disable Python output buffering for real-time logs
ENV PYTHONUNBUFFERED=1

# Production defaults (secrets injected via env vars at runtime)
ENV MEETMIND_ENVIRONMENT=production
ENV MEETMIND_STT_ENGINE=parakeet
ENV MEETMIND_LLM_PROVIDER=openai
ENV MEETMIND_DEBUG=false

# Use non-root user
USER meetmind

# Set working directory
WORKDIR /app

# Metadata labels
LABEL maintainer="Cris <cris@meetmind.ai>" \
    application="meetmind-backend" \
    description="AI-powered Meeting Assistant — real-time STT + AI copilot"

# Health check for Docker Compose / monitoring
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -sf http://localhost:8000/health || exit 1

EXPOSE 8000

# Run the MeetMind backend (production — single worker for WebSocket state)
CMD ["uvicorn", "meetmind.main:app", "--host", "0.0.0.0", "--port", "8000"]
