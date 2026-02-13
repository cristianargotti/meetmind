"""Tests for the screening agent."""

from unittest.mock import AsyncMock

import pytest

from meetmind.agents.screening_agent import ScreeningAgent, ScreeningResult
from meetmind.providers.bedrock import BedrockProvider


class TestScreeningResult:
    """Tests for ScreeningResult."""

    def test_to_dict(self) -> None:
        """Test dictionary conversion."""
        result = ScreeningResult(relevant=True, reason="Decision made", text_length=100)
        assert result.to_dict() == {
            "relevant": True,
            "reason": "Decision made",
            "text_length": 100,
        }

    def test_to_dict_not_relevant(self) -> None:
        """Test dictionary conversion for non-relevant result."""
        result = ScreeningResult(relevant=False, reason="Small talk", text_length=50)
        assert result.relevant is False
        assert result.reason == "Small talk"


class TestScreeningAgent:
    """Tests for ScreeningAgent."""

    @pytest.fixture
    def mock_provider(self) -> AsyncMock:
        """Create a mock Bedrock provider."""
        provider = AsyncMock(spec=BedrockProvider)
        return provider

    @pytest.fixture
    def agent(self, mock_provider: AsyncMock) -> ScreeningAgent:
        """Create a screening agent with mock provider."""
        return ScreeningAgent(mock_provider)

    @pytest.mark.anyio
    async def test_screen_relevant(self, agent: ScreeningAgent, mock_provider: AsyncMock) -> None:
        """Test screening that finds relevant content."""
        mock_provider.invoke_screening.return_value = {
            "content": '{"relevant": true, "reason": "Technical decision being made"}',
            "latency_ms": 150.0,
        }

        result = await agent.screen("We need to migrate to Kubernetes by Q2")

        assert result.relevant is True
        assert "decision" in result.reason.lower()
        assert result.text_length > 0
        mock_provider.invoke_screening.assert_called_once()

    @pytest.mark.anyio
    async def test_screen_not_relevant(
        self, agent: ScreeningAgent, mock_provider: AsyncMock
    ) -> None:
        """Test screening that finds no relevant content."""
        mock_provider.invoke_screening.return_value = {
            "content": '{"relevant": false, "reason": "General greeting"}',
            "latency_ms": 120.0,
        }

        result = await agent.screen("Good morning everyone")

        assert result.relevant is False
        assert result.text_length > 0

    @pytest.mark.anyio
    async def test_screen_empty_text(self, agent: ScreeningAgent) -> None:
        """Test screening with empty text returns not relevant."""
        result = await agent.screen("")

        assert result.relevant is False
        assert result.reason == "Empty text"
        assert result.text_length == 0

    @pytest.mark.anyio
    async def test_screen_json_parse_error(
        self, agent: ScreeningAgent, mock_provider: AsyncMock
    ) -> None:
        """Test screening with invalid JSON defaults to relevant (safe fallback)."""
        mock_provider.invoke_screening.return_value = {
            "content": "I think this is relevant because...",
            "latency_ms": 200.0,
        }

        result = await agent.screen("Some important text")

        assert result.relevant is True
        assert "parse" in result.reason.lower()

    @pytest.mark.anyio
    async def test_screen_provider_error(
        self, agent: ScreeningAgent, mock_provider: AsyncMock
    ) -> None:
        """Test screening when provider raises exception."""
        mock_provider.invoke_screening.side_effect = RuntimeError("AWS connection failed")

        result = await agent.screen("Some text")

        assert result.relevant is False
        assert "error" in result.reason.lower()
