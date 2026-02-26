"""Tests for Ask Aura RAG pipeline — embeddings + semantic search."""

from __future__ import annotations

from typing import Any
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from meetmind.core.embeddings import EmbeddingService


class TestEmbeddingService:
    """Tests for EmbeddingService."""

    @pytest.fixture
    def mock_openai_client(self) -> MagicMock:
        """Create a mock OpenAI client for embeddings."""
        client = MagicMock()
        client.embeddings = MagicMock()
        return client

    @pytest.fixture
    def service(self, mock_openai_client: MagicMock) -> EmbeddingService:
        """Create an EmbeddingService with mocked OpenAI client."""
        with patch("meetmind.core.embeddings.settings") as mock_settings:
            mock_settings.embedding_api_key = "test-key"
            mock_settings.openai_api_key = "test-key"
            mock_settings.embedding_base_url = "https://api.openai.com/v1"
            mock_settings.embedding_model = "text-embedding-3-small"
            mock_settings.embedding_dimensions = 1536
            mock_settings.rag_top_k = 10
            svc = EmbeddingService()

        svc._client = mock_openai_client
        return svc

    @pytest.mark.anyio
    async def test_embed_texts_empty(self, service: EmbeddingService) -> None:
        """Test embedding empty list returns empty."""
        result = await service.embed_texts([])
        assert result == []

    @pytest.mark.anyio
    async def test_embed_texts(
        self,
        service: EmbeddingService,
        mock_openai_client: MagicMock,
    ) -> None:
        """Test embedding generates vectors for each text."""
        mock_item_1 = MagicMock()
        mock_item_1.embedding = [0.1, 0.2, 0.3]
        mock_item_2 = MagicMock()
        mock_item_2.embedding = [0.4, 0.5, 0.6]

        mock_response = MagicMock()
        mock_response.data = [mock_item_1, mock_item_2]

        mock_openai_client.embeddings.create = AsyncMock(return_value=mock_response)

        result = await service.embed_texts(["hello", "world"])

        assert len(result) == 2
        assert result[0] == [0.1, 0.2, 0.3]
        assert result[1] == [0.4, 0.5, 0.6]
        mock_openai_client.embeddings.create.assert_called_once()

    @pytest.mark.anyio
    async def test_embed_and_store(
        self,
        service: EmbeddingService,
        mock_openai_client: MagicMock,
    ) -> None:
        """Test embed_and_store generates and persists embeddings."""
        mock_item = MagicMock()
        mock_item.embedding = [0.1, 0.2, 0.3]
        mock_response = MagicMock()
        mock_response.data = [mock_item]
        mock_openai_client.embeddings.create = AsyncMock(return_value=mock_response)

        segments = [{"text": "Hello world", "speaker": "John"}]

        with patch("meetmind.core.embeddings.storage") as mock_storage:
            mock_storage.save_segment_embeddings = AsyncMock(return_value=1)
            count = await service.embed_and_store("meeting-1", "user-1", segments)

        assert count == 1
        mock_storage.save_segment_embeddings.assert_called_once()
        call_args = mock_storage.save_segment_embeddings.call_args
        chunks = call_args[0][2]
        assert len(chunks) == 1
        assert chunks[0]["text"] == "Hello world"
        assert chunks[0]["speaker"] == "John"
        assert chunks[0]["embedding"].startswith("[")

    @pytest.mark.anyio
    async def test_embed_and_store_skips_empty(
        self,
        service: EmbeddingService,
    ) -> None:
        """Test embed_and_store skips segments with empty text."""
        segments = [{"text": "", "speaker": "John"}, {"text": "   ", "speaker": "Jane"}]
        count = await service.embed_and_store("meeting-1", "user-1", segments)
        assert count == 0

    @pytest.mark.anyio
    async def test_search(
        self,
        service: EmbeddingService,
        mock_openai_client: MagicMock,
    ) -> None:
        """Test search embeds the query and calls semantic_search."""
        mock_item = MagicMock()
        mock_item.embedding = [0.1, 0.2, 0.3]
        mock_response = MagicMock()
        mock_response.data = [mock_item]
        mock_openai_client.embeddings.create = AsyncMock(return_value=mock_response)

        mock_results: list[dict[str, Any]] = [
            {
                "chunk_text": "Redis discussion",
                "speaker": "Juan",
                "meeting_id": "m1",
                "meeting_title": "Tech Review",
                "started_at": "2024-01-15",
                "similarity": 0.92,
            }
        ]

        with patch("meetmind.core.embeddings.storage") as mock_storage:
            mock_storage.semantic_search = AsyncMock(return_value=mock_results)
            results = await service.search("What about Redis?", "user-1")

        assert len(results) == 1
        assert results[0]["chunk_text"] == "Redis discussion"
        assert results[0]["similarity"] == 0.92

    def test_build_rag_context_empty(self, service: EmbeddingService) -> None:
        """Test build_rag_context returns empty string for no results."""
        assert service.build_rag_context([]) == ""

    def test_build_rag_context_groups_by_meeting(self, service: EmbeddingService) -> None:
        """Test build_rag_context groups segments by meeting."""
        results: list[dict[str, Any]] = [
            {
                "meeting_id": "m1",
                "meeting_title": "Sprint Planning",
                "started_at": "2024-01-15 10:00",
                "chunk_text": "We need to migrate to Redis",
                "speaker": "Juan",
                "similarity": 0.95,
            },
            {
                "meeting_id": "m1",
                "meeting_title": "Sprint Planning",
                "started_at": "2024-01-15 10:00",
                "chunk_text": "Redis cluster setup is critical",
                "speaker": "Maria",
                "similarity": 0.88,
            },
            {
                "meeting_id": "m2",
                "meeting_title": "Architecture Review",
                "started_at": "2024-01-20 14:00",
                "chunk_text": "Consider Redis Sentinel for HA",
                "speaker": "Carlos",
                "similarity": 0.85,
            },
        ]

        context = service.build_rag_context(results)

        assert "Sprint Planning" in context
        assert "Architecture Review" in context
        assert "2024-01-15" in context
        assert "2024-01-20" in context
        assert "[Juan]" in context
        assert "[Maria]" in context
        assert "[Carlos]" in context
        assert "relevance: 0.95" in context


class TestAskAuraEndpoint:
    """Tests for the ask_aura method on MeetingManager."""

    @pytest.mark.anyio
    async def test_ask_aura_no_embedding_service(self) -> None:
        """Test ask_aura returns error when embedding service unavailable."""
        from meetmind.api.meeting_api import MeetingManager

        manager = MeetingManager()
        result = await manager.ask_aura("What happened?", "user-1")

        assert result["error"] is True
        assert "embedding" in result["answer"].lower()

    @pytest.mark.anyio
    async def test_ask_aura_no_copilot_agent(self) -> None:
        """Test ask_aura returns error when copilot not initialized."""
        from meetmind.api.meeting_api import MeetingManager

        manager = MeetingManager()
        manager._embedding_service = MagicMock(spec=EmbeddingService)
        result = await manager.ask_aura("What happened?", "user-1")

        assert result["error"] is True
        assert "agents" in result["answer"].lower() or "initialized" in result["answer"].lower()

    @pytest.mark.anyio
    async def test_ask_aura_no_results(self) -> None:
        """Test ask_aura handles no search results gracefully."""
        from meetmind.api.meeting_api import MeetingManager

        manager = MeetingManager()
        mock_embedding = MagicMock(spec=EmbeddingService)
        mock_embedding.search = AsyncMock(return_value=[])
        manager._embedding_service = mock_embedding
        manager._copilot_agent = MagicMock()

        result = await manager.ask_aura("What happened?", "user-1")

        assert result["error"] is False
        assert "no relevant" in result["answer"].lower()
        assert result["sources"] == []

    @pytest.mark.anyio
    async def test_ask_aura_with_results(self) -> None:
        """Test ask_aura full pipeline with mocked components."""
        from meetmind.agents.copilot_agent import CopilotResponse
        from meetmind.api.meeting_api import MeetingManager

        manager = MeetingManager()

        # Mock embedding service
        search_results: list[dict[str, Any]] = [
            {
                "chunk_text": "Migrar a Redis para mejorar latencia",
                "speaker": "Juan",
                "meeting_id": "m1",
                "meeting_title": "Sprint Planning",
                "started_at": "2024-01-15",
                "similarity": 0.92,
            }
        ]
        mock_embedding = MagicMock(spec=EmbeddingService)
        mock_embedding.search = AsyncMock(return_value=search_results)
        mock_embedding.build_rag_context.return_value = (
            "### Meeting: Sprint Planning (2024-01-15)\n"
            "[Juan] Migrar a Redis para mejorar latencia  (relevance: 0.92)"
        )
        manager._embedding_service = mock_embedding

        # Mock copilot agent
        mock_copilot = AsyncMock()
        mock_copilot.respond.return_value = CopilotResponse(
            answer="En el Sprint Planning del 15 de enero, Juan propuso migrar a Redis.",
            latency_ms=1500.0,
            input_tokens=300,
            output_tokens=50,
            model_tier="sonnet",
        )
        manager._copilot_agent = mock_copilot

        result = await manager.ask_aura("What about Redis?", "user-1")

        assert result["error"] is False
        assert "Redis" in result["answer"]
        assert result["model_tier"] == "sonnet"
        assert len(result["sources"]) == 1
        assert result["sources"][0]["meeting_id"] == "m1"
        assert result["sources"][0]["title"] == "Sprint Planning"
        assert "latency_ms" in result

    @pytest.mark.anyio
    async def test_ask_aura_search_error(self) -> None:
        """Test ask_aura handles search failures gracefully."""
        from meetmind.api.meeting_api import MeetingManager

        manager = MeetingManager()
        mock_embedding = MagicMock(spec=EmbeddingService)
        mock_embedding.search = AsyncMock(side_effect=RuntimeError("DB connection lost"))
        manager._embedding_service = mock_embedding
        manager._copilot_agent = MagicMock()

        result = await manager.ask_aura("What happened?", "user-1")

        assert result["error"] is True
        assert "Search failed" in result["answer"]

    @pytest.mark.anyio
    async def test_ask_aura_deduplicates_sources(self) -> None:
        """Test ask_aura deduplicates meeting sources."""
        from meetmind.agents.copilot_agent import CopilotResponse
        from meetmind.api.meeting_api import MeetingManager

        manager = MeetingManager()

        # Two segments from the same meeting
        search_results: list[dict[str, Any]] = [
            {
                "chunk_text": "Segment 1",
                "speaker": "A",
                "meeting_id": "m1",
                "meeting_title": "Meeting X",
                "started_at": "2024-01-15",
                "similarity": 0.9,
            },
            {
                "chunk_text": "Segment 2",
                "speaker": "B",
                "meeting_id": "m1",
                "meeting_title": "Meeting X",
                "started_at": "2024-01-15",
                "similarity": 0.85,
            },
        ]
        mock_embedding = MagicMock(spec=EmbeddingService)
        mock_embedding.search = AsyncMock(return_value=search_results)
        mock_embedding.build_rag_context.return_value = "context"
        manager._embedding_service = mock_embedding

        mock_copilot = AsyncMock()
        mock_copilot.respond.return_value = CopilotResponse(
            answer="Answer",
            latency_ms=100.0,
            input_tokens=10,
            output_tokens=5,
        )
        manager._copilot_agent = mock_copilot

        result = await manager.ask_aura("Question?", "user-1")

        # Should have only 1 source even though 2 segments from same meeting
        assert len(result["sources"]) == 1
        assert result["sources"][0]["meeting_id"] == "m1"
