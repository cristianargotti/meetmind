"""Async PostgreSQL storage — meetings, transcripts, insights, summaries.

Uses asyncpg (fastest async PG driver, written in C) for maximum throughput.
Designed for PostgreSQL 17 + pgvector extension for future vector search (RAG).

Schema supports:
  - Meeting sessions with auto-generated titles
  - Transcript segments with speaker attribution
  - AI insights (screening + analysis)
  - Structured summaries with action items
  - Vector embeddings for future "Ask Aura" RAG (pgvector ready)
"""

from __future__ import annotations

import json
import time
from typing import Any

import asyncpg  # type: ignore[import-untyped]
import structlog

from meetmind.config.settings import settings

logger = structlog.get_logger(__name__)

# ─── Connection Pool ──────────────────────────────────────────────

_pool: asyncpg.Pool | None = None


async def init_db() -> None:
    """Initialize connection pool and create schema."""
    global _pool
    dsn = settings.database_url
    _pool = await asyncpg.create_pool(
        dsn,
        min_size=2,
        max_size=10,
        command_timeout=30,
        timeout=5,  # fail fast if DB unreachable (prevents lifespan hang)
    )
    logger.info("db_pool_created", dsn=dsn.split("@")[-1])  # log host only

    async with _pool.acquire() as conn:
        await _create_schema(conn)
    logger.info("db_schema_ready")


async def close_db() -> None:
    """Close the connection pool."""
    global _pool
    if _pool:
        await _pool.close()
        _pool = None
        logger.info("db_pool_closed")


async def get_pool() -> asyncpg.Pool:
    """Get the connection pool, initializing if needed."""
    if _pool is None:
        await init_db()
    return _pool


# ─── Schema ───────────────────────────────────────────────────────


async def _create_schema(conn: asyncpg.Connection) -> None:
    """Create tables if they don't exist."""
    await conn.execute("""
        CREATE EXTENSION IF NOT EXISTS vector;

        CREATE TABLE IF NOT EXISTS users (
            id              TEXT PRIMARY KEY,
            email           TEXT UNIQUE NOT NULL,
            name            TEXT,
            avatar_url      TEXT,
            provider        TEXT NOT NULL,
            provider_id     TEXT UNIQUE NOT NULL,
            created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            last_login      TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );

        -- Add password_hash column for email/password auth (idempotent)
        ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash TEXT;

        CREATE TABLE IF NOT EXISTS meetings (
            id              TEXT PRIMARY KEY,
            user_id         TEXT REFERENCES users(id) ON DELETE CASCADE,
            title           TEXT NOT NULL DEFAULT 'Untitled Meeting',
            language        TEXT NOT NULL DEFAULT 'es',
            status          TEXT NOT NULL DEFAULT 'active',
            started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            ended_at        TIMESTAMPTZ,
            duration_secs   INTEGER,
            total_segments  INTEGER DEFAULT 0,
            total_insights  INTEGER DEFAULT 0,
            cost_usd        REAL DEFAULT 0.0,
            metadata        JSONB DEFAULT '{}',
            created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );

        CREATE TABLE IF NOT EXISTS transcript_segments (
            id              BIGSERIAL PRIMARY KEY,
            meeting_id      TEXT NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
            speaker         TEXT NOT NULL DEFAULT 'unknown',
            text            TEXT NOT NULL,
            timestamp_unix  DOUBLE PRECISION NOT NULL,
            segment_index   INTEGER NOT NULL,
            created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );

        CREATE TABLE IF NOT EXISTS insights (
            id              BIGSERIAL PRIMARY KEY,
            meeting_id      TEXT NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
            insight_type    TEXT NOT NULL,
            title           TEXT NOT NULL,
            content         TEXT NOT NULL,
            category        TEXT,
            importance      TEXT DEFAULT 'medium',
            timestamp_unix  DOUBLE PRECISION NOT NULL,
            metadata        JSONB DEFAULT '{}',
            created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );

        CREATE TABLE IF NOT EXISTS summaries (
            id              BIGSERIAL PRIMARY KEY,
            meeting_id      TEXT NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
            title           TEXT,
            overview        TEXT,
            key_points      JSONB DEFAULT '[]',
            action_items    JSONB DEFAULT '[]',
            decisions       JSONB DEFAULT '[]',
            follow_ups      JSONB DEFAULT '[]',
            sentiment       TEXT,
            full_markdown   TEXT,
            model_used      TEXT,
            created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );

        CREATE TABLE IF NOT EXISTS action_items (
            id              BIGSERIAL PRIMARY KEY,
            meeting_id      TEXT NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
            summary_id      BIGINT REFERENCES summaries(id) ON DELETE CASCADE,
            assignee        TEXT,
            task            TEXT NOT NULL,
            deadline        TEXT,
            priority        TEXT DEFAULT 'medium',
            status          TEXT DEFAULT 'pending',
            created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );

        -- Indexes for fast queries
        CREATE INDEX IF NOT EXISTS idx_segments_meeting
            ON transcript_segments(meeting_id, segment_index);

        CREATE INDEX IF NOT EXISTS idx_insights_meeting
            ON insights(meeting_id, created_at);

        CREATE INDEX IF NOT EXISTS idx_meetings_started
            ON meetings(started_at DESC);

        CREATE INDEX IF NOT EXISTS idx_action_items_meeting
            ON action_items(meeting_id, status);

        CREATE INDEX IF NOT EXISTS idx_meetings_user
            ON meetings(user_id, started_at DESC);

        -- Migration: add user_id to existing meetings if not present
        DO $$ BEGIN
            ALTER TABLE meetings ADD COLUMN IF NOT EXISTS
                user_id TEXT REFERENCES users(id) ON DELETE CASCADE;
        EXCEPTION WHEN duplicate_column THEN NULL;
        END $$;
    """)


# ─── Meetings CRUD ───────────────────────────────────────────────


async def create_meeting(
    meeting_id: str,
    language: str = "es",
    user_id: str | None = None,
) -> dict[str, Any]:
    """Create a new meeting session."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            """
            INSERT INTO meetings (id, language, status, user_id)
            VALUES ($1, $2, 'active', $3)
            RETURNING *
            """,
            meeting_id,
            language,
            user_id,
        )
    logger.info("meeting_created", meeting_id=meeting_id, user_id=user_id)
    return dict(row) if row else {}


async def end_meeting(
    meeting_id: str,
    *,
    title: str | None = None,
    duration_secs: int | None = None,
    cost_usd: float | None = None,
) -> dict[str, Any]:
    """End a meeting and update its metadata."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        # Count segments and insights
        seg_count = await conn.fetchval(
            "SELECT COUNT(*) FROM transcript_segments WHERE meeting_id = $1",
            meeting_id,
        )
        insight_count = await conn.fetchval(
            "SELECT COUNT(*) FROM insights WHERE meeting_id = $1",
            meeting_id,
        )

        row = await conn.fetchrow(
            """
            UPDATE meetings
            SET status = 'completed',
                ended_at = NOW(),
                title = COALESCE($2, title),
                duration_secs = COALESCE($3, duration_secs),
                cost_usd = COALESCE($4, cost_usd),
                total_segments = $5,
                total_insights = $6,
                updated_at = NOW()
            WHERE id = $1
            RETURNING *
            """,
            meeting_id,
            title,
            duration_secs,
            cost_usd,
            seg_count,
            insight_count,
        )
    logger.info("meeting_ended", meeting_id=meeting_id, segments=seg_count)
    return dict(row) if row else {}


async def list_meetings(
    limit: int = 50,
    offset: int = 0,
    user_id: str | None = None,
) -> list[dict[str, Any]]:
    """List meetings ordered by most recent, optionally filtered by user."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        if user_id:
            rows = await conn.fetch(
                """
                SELECT id, title, language, status, started_at, ended_at,
                       duration_secs, total_segments, total_insights, cost_usd
                FROM meetings
                WHERE user_id = $3
                ORDER BY started_at DESC
                LIMIT $1 OFFSET $2
                """,
                limit,
                offset,
                user_id,
            )
        else:
            rows = await conn.fetch(
                """
                SELECT id, title, language, status, started_at, ended_at,
                       duration_secs, total_segments, total_insights, cost_usd
                FROM meetings
                ORDER BY started_at DESC
                LIMIT $1 OFFSET $2
                """,
                limit,
                offset,
            )
    return [dict(r) for r in rows]


async def get_meeting(meeting_id: str) -> dict[str, Any] | None:
    """Get a single meeting with all its data."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        meeting = await conn.fetchrow(
            "SELECT * FROM meetings WHERE id = $1",
            meeting_id,
        )
        if not meeting:
            return None

        segments = await conn.fetch(
            """
            SELECT speaker, text, timestamp_unix, segment_index
            FROM transcript_segments
            WHERE meeting_id = $1
            ORDER BY segment_index
            """,
            meeting_id,
        )

        insights_rows = await conn.fetch(
            """
            SELECT insight_type, title, content, category,
                   importance, timestamp_unix
            FROM insights
            WHERE meeting_id = $1
            ORDER BY created_at
            """,
            meeting_id,
        )

        summary = await conn.fetchrow(
            """
            SELECT title, overview, key_points, action_items,
                   decisions, follow_ups, sentiment, full_markdown
            FROM summaries
            WHERE meeting_id = $1
            ORDER BY created_at DESC
            LIMIT 1
            """,
            meeting_id,
        )

        action_rows = await conn.fetch(
            """
            SELECT id, assignee, task, deadline, priority, status
            FROM action_items
            WHERE meeting_id = $1
            ORDER BY created_at
            """,
            meeting_id,
        )

    result = dict(meeting)
    result["segments"] = [dict(s) for s in segments]
    result["insights"] = [dict(i) for i in insights_rows]
    result["summary"] = dict(summary) if summary else None
    result["action_items"] = [dict(a) for a in action_rows]
    return result


async def delete_meeting(meeting_id: str) -> bool:
    """Delete a meeting and all related data (cascades)."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        result = await conn.execute(
            "DELETE FROM meetings WHERE id = $1",
            meeting_id,
        )
    deleted: bool = result == "DELETE 1"
    if deleted:
        logger.info("meeting_deleted", meeting_id=meeting_id)
    return deleted


# ─── Transcript Segments ─────────────────────────────────────────


async def save_segments(
    meeting_id: str,
    segments: list[dict[str, Any]],
) -> int:
    """Bulk-insert transcript segments for a meeting."""
    if not segments:
        return 0

    pool = await get_pool()
    async with pool.acquire() as conn:
        records = [
            (
                meeting_id,
                seg.get("speaker", "unknown"),
                seg["text"],
                seg.get("timestamp", time.time()),
                idx,
            )
            for idx, seg in enumerate(segments)
        ]
        await conn.executemany(
            """
            INSERT INTO transcript_segments
                (meeting_id, speaker, text, timestamp_unix, segment_index)
            VALUES ($1, $2, $3, $4, $5)
            ON CONFLICT DO NOTHING
            """,
            records,
        )
    logger.info("segments_saved", meeting_id=meeting_id, count=len(segments))
    return len(segments)


# ─── Insights ────────────────────────────────────────────────────


async def save_insight(
    meeting_id: str,
    insight: dict[str, Any],
) -> int:
    """Save a single AI insight."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            """
            INSERT INTO insights
                (meeting_id, insight_type, title, content, category,
                 importance, timestamp_unix, metadata)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            RETURNING id
            """,
            meeting_id,
            insight.get("type", "analysis"),
            insight.get("title", ""),
            insight.get("content", ""),
            insight.get("category"),
            insight.get("importance", "medium"),
            insight.get("timestamp", time.time()),
            json.dumps(insight.get("metadata", {})),
        )
    return int(row["id"]) if row else 0


# ─── Summaries ───────────────────────────────────────────────────


async def save_summary(
    meeting_id: str,
    summary: dict[str, Any],
) -> int:
    """Save a meeting summary with action items."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            """
            INSERT INTO summaries
                (meeting_id, title, overview, key_points, action_items,
                 decisions, follow_ups, sentiment, full_markdown, model_used)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
            RETURNING id
            """,
            meeting_id,
            summary.get("title"),
            summary.get("overview"),
            json.dumps(summary.get("key_points", [])),
            json.dumps(summary.get("action_items", [])),
            json.dumps(summary.get("decisions", [])),
            json.dumps(summary.get("follow_ups", [])),
            summary.get("sentiment"),
            summary.get("full_markdown"),
            summary.get("model_used"),
        )
        summary_id = int(row["id"]) if row else 0

        # Save action items as separate records
        action_items = summary.get("action_items", [])
        if action_items and isinstance(action_items, list):
            for item in action_items:
                if isinstance(item, dict):
                    await conn.execute(
                        """
                        INSERT INTO action_items
                            (meeting_id, summary_id, assignee, task,
                             deadline, priority)
                        VALUES ($1, $2, $3, $4, $5, $6)
                        """,
                        meeting_id,
                        summary_id,
                        item.get("assignee"),
                        item.get("task", str(item)),
                        item.get("deadline"),
                        item.get("priority", "medium"),
                    )

    logger.info(
        "summary_saved",
        meeting_id=meeting_id,
        action_items=len(action_items) if isinstance(action_items, list) else 0,
    )
    return summary_id


# ─── Action Items ────────────────────────────────────────────────


async def update_action_item(
    item_id: int,
    status: str,
) -> bool:
    """Update an action item's status (pending/done)."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        result = await conn.execute(
            """
            UPDATE action_items
            SET status = $2, updated_at = NOW()
            WHERE id = $1
            """,
            item_id,
            status,
        )
    return bool(result == "UPDATE 1")


async def get_pending_action_items(
    limit: int = 50,
    user_id: str | None = None,
) -> list[dict[str, Any]]:
    """Get pending action items, optionally scoped to a user."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        if user_id:
            rows = await conn.fetch(
                """
                SELECT ai.id, ai.assignee, ai.task, ai.deadline, ai.priority,
                       ai.status, m.title as meeting_title, m.started_at
                FROM action_items ai
                JOIN meetings m ON m.id = ai.meeting_id
                WHERE ai.status = 'pending' AND m.user_id = $2
                ORDER BY ai.created_at DESC
                LIMIT $1
                """,
                limit,
                user_id,
            )
        else:
            rows = await conn.fetch(
                """
                SELECT ai.id, ai.assignee, ai.task, ai.deadline, ai.priority,
                       ai.status, m.title as meeting_title, m.started_at
                FROM action_items ai
                JOIN meetings m ON m.id = ai.meeting_id
                WHERE ai.status = 'pending'
                ORDER BY ai.created_at DESC
                LIMIT $1
                """,
                limit,
            )
    return [dict(r) for r in rows]


# ─── Stats ───────────────────────────────────────────────────────


async def get_stats(user_id: str | None = None) -> dict[str, Any]:
    """Get dashboard stats, scoped to a user if provided."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        if user_id:
            total_meetings = await conn.fetchval(
                "SELECT COUNT(*) FROM meetings WHERE status = 'completed' AND user_id = $1",
                user_id,
            )
            total_duration = await conn.fetchval(
                """
                SELECT COALESCE(SUM(duration_secs), 0) FROM meetings
                WHERE status = 'completed' AND user_id = $1
                """,
                user_id,
            )
            total_insights = await conn.fetchval(
                """
                SELECT COUNT(*) FROM insights i
                JOIN meetings m ON m.id = i.meeting_id
                WHERE m.user_id = $1
                """,
                user_id,
            )
            pending_actions = await conn.fetchval(
                """
                SELECT COUNT(*) FROM action_items ai
                JOIN meetings m ON m.id = ai.meeting_id
                WHERE ai.status = 'pending' AND m.user_id = $1
                """,
                user_id,
            )
            meetings_today = await conn.fetchval(
                """
                SELECT COUNT(*) FROM meetings
                WHERE started_at >= CURRENT_DATE AND status = 'completed' AND user_id = $1
                """,
                user_id,
            )
            meetings_this_week = await conn.fetchval(
                """
                SELECT COUNT(*) FROM meetings
                WHERE started_at >= DATE_TRUNC('week', CURRENT_DATE)
                      AND status = 'completed' AND user_id = $1
                """,
                user_id,
            )
        else:
            total_meetings = await conn.fetchval(
                "SELECT COUNT(*) FROM meetings WHERE status = 'completed'"
            )
            total_duration = await conn.fetchval(
                "SELECT COALESCE(SUM(duration_secs), 0) FROM meetings WHERE status = 'completed'"
            )
            total_insights = await conn.fetchval("SELECT COUNT(*) FROM insights")
            pending_actions = await conn.fetchval(
                "SELECT COUNT(*) FROM action_items WHERE status = 'pending'"
            )
            meetings_today = await conn.fetchval(
                """
                SELECT COUNT(*) FROM meetings
                WHERE started_at >= CURRENT_DATE AND status = 'completed'
                """
            )
            meetings_this_week = await conn.fetchval(
                """
                SELECT COUNT(*) FROM meetings
                WHERE started_at >= DATE_TRUNC('week', CURRENT_DATE)
                      AND status = 'completed'
                """
            )

    return {
        "total_meetings": total_meetings or 0,
        "total_hours": round((total_duration or 0) / 3600, 1),
        "total_insights": total_insights or 0,
        "pending_actions": pending_actions or 0,
        "meetings_today": meetings_today or 0,
        "meetings_this_week": meetings_this_week or 0,
    }


# ─── Users CRUD ──────────────────────────────────────────────────


async def upsert_user(
    *,
    user_id: str,
    email: str,
    name: str | None = None,
    avatar_url: str | None = None,
    provider: str,
    provider_id: str,
) -> dict[str, Any]:
    """Create or update a user on login (upsert by provider_id)."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            """
            INSERT INTO users (id, email, name, avatar_url, provider, provider_id)
            VALUES ($1, $2, $3, $4, $5, $6)
            ON CONFLICT (provider_id) DO UPDATE SET
                email = EXCLUDED.email,
                name = COALESCE(EXCLUDED.name, users.name),
                avatar_url = COALESCE(EXCLUDED.avatar_url, users.avatar_url),
                last_login = NOW()
            RETURNING *
            """,
            user_id,
            email,
            name,
            avatar_url,
            provider,
            provider_id,
        )
    logger.info("user_upserted", user_id=user_id, provider=provider)
    return dict(row) if row else {}


async def get_user(user_id: str) -> dict[str, Any] | None:
    """Get a user by ID."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT * FROM users WHERE id = $1",
            user_id,
        )
    return dict(row) if row else None


async def get_user_by_provider(provider: str, provider_id: str) -> dict[str, Any] | None:
    """Get a user by OAuth provider ID."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT * FROM users WHERE provider = $1 AND provider_id = $2",
            provider,
            provider_id,
        )
    return dict(row) if row else None


async def get_user_by_email(email: str) -> dict[str, Any] | None:
    """Get a user by email address."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT * FROM users WHERE email = $1",
            email,
        )
    return dict(row) if row else None


async def delete_user_account(user_id: str) -> bool:
    """Delete a user and ALL their data — Apple App Store compliance.

    Cascading delete removes: meetings → segments, insights, summaries, action_items.
    """
    pool = await get_pool()
    async with pool.acquire() as conn:
        result = await conn.execute(
            "DELETE FROM users WHERE id = $1",
            user_id,
        )
    deleted: bool = result == "DELETE 1"
    if deleted:
        logger.info("user_account_deleted", user_id=user_id)
    return deleted
