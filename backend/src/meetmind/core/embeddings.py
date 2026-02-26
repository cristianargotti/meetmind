"""Embedding service for RAG — Ask Aura cross-meeting search.

Uses OpenAI-compatible embeddings API (text-embedding-3-small by default).
Generates vector embeddings for transcript segments and queries,
then performs semantic search via pgvector.
"""

from __future__ import annotations

import time
from typing import Any

import structlog
from openai import AsyncOpenAI

from meetmind.config.settings import settings
from meetmind.core import storage

logger = structlog.get_logger(__name__)


class EmbeddingService:
    """Generates embeddings and performs RAG semantic search."""

    def __init__(self) -> None:
        """Initialize embedding client.

        Uses a separate API key/base URL from the chat provider,
        since Groq doesn't support embeddings but OpenAI does.
        """
        api_key = settings.embedding_api_key or settings.openai_api_key
        if not api_key:
            raise ValueError(
                "MEETMIND_EMBEDDING_API_KEY (or MEETMIND_OPENAI_API_KEY) is required for RAG"
            )

        self._client = AsyncOpenAI(
            api_key=api_key,
            base_url=settings.embedding_base_url,
        )
        self._model = settings.embedding_model
        self._dimensions = settings.embedding_dimensions
        self._top_k = settings.rag_top_k

    async def embed_texts(self, texts: list[str]) -> list[list[float]]:
        """Generate embeddings for a batch of texts.

        Args:
            texts: List of text strings to embed.

        Returns:
            List of embedding vectors (list of floats).
        """
        if not texts:
            return []

        start = time.monotonic()
        response = await self._client.embeddings.create(
            model=self._model,
            input=texts,
            dimensions=self._dimensions,
        )
        latency_ms = (time.monotonic() - start) * 1000

        embeddings = [item.embedding for item in response.data]

        logger.info(
            "embeddings_generated",
            count=len(texts),
            model=self._model,
            latency_ms=round(latency_ms, 1),
        )
        return embeddings

    async def embed_and_store(
        self,
        meeting_id: str,
        user_id: str | None,
        segments: list[dict[str, str]],
    ) -> int:
        """Embed transcript segments and store in pgvector.

        Args:
            meeting_id: The meeting these segments belong to.
            user_id: Owner's user ID for scoped search.
            segments: List of dicts with 'text' and optional 'speaker'.

        Returns:
            Number of embeddings stored.
        """
        texts = [seg["text"] for seg in segments if seg.get("text", "").strip()]
        if not texts:
            return 0

        embeddings = await self.embed_texts(texts)

        chunks: list[dict[str, Any]] = []
        text_idx = 0
        for seg in segments:
            if seg.get("text", "").strip():
                # Convert embedding list to pgvector string format
                vec_str = "[" + ",".join(str(v) for v in embeddings[text_idx]) + "]"
                chunks.append(
                    {
                        "text": seg["text"],
                        "speaker": seg.get("speaker"),
                        "embedding": vec_str,
                    }
                )
                text_idx += 1

        return await storage.save_segment_embeddings(meeting_id, user_id, chunks)

    async def search(
        self,
        query: str,
        user_id: str,
        *,
        top_k: int | None = None,
    ) -> list[dict[str, Any]]:
        """Semantic search across all user's meeting transcripts.

        Args:
            query: The user's question to search for.
            user_id: Scope to this user's meetings.
            top_k: Number of results (defaults to settings.rag_top_k).

        Returns:
            List of matching segments with meeting context and similarity scores.
        """
        k = top_k or self._top_k
        embeddings = await self.embed_texts([query])
        if not embeddings:
            return []

        query_vec = "[" + ",".join(str(v) for v in embeddings[0]) + "]"
        return await storage.semantic_search(query_vec, user_id, top_k=k)

    def build_rag_context(self, results: list[dict[str, Any]]) -> str:
        """Build a readable context string from search results.

        Groups results by meeting and formats them for the LLM prompt.

        Args:
            results: List of semantic search results.

        Returns:
            Formatted context string for the copilot prompt.
        """
        if not results:
            return ""

        # Group by meeting
        meetings: dict[str, list[dict[str, Any]]] = {}
        for r in results:
            mid = r["meeting_id"]
            if mid not in meetings:
                meetings[mid] = []
            meetings[mid].append(r)

        parts: list[str] = []
        for _mid, segments in meetings.items():
            title = segments[0].get("meeting_title") or "Untitled"
            date = segments[0].get("started_at", "")
            date_str = str(date)[:10] if date else "unknown date"
            header = f"### Meeting: {title} ({date_str})"
            lines = []
            for seg in segments:
                speaker = seg.get("speaker") or "Unknown"
                text = seg.get("chunk_text", "")
                sim = seg.get("similarity", 0)
                lines.append(f"[{speaker}] {text}  (relevance: {sim:.2f})")
            parts.append(header + "\n" + "\n".join(lines))

        return "\n\n".join(parts)
