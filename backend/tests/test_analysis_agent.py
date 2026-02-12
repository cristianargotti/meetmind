"""Tests for the analysis agent."""

from unittest.mock import AsyncMock

import pytest

from meetmind.agents.analysis_agent import AnalysisAgent, AnalysisInsight
from meetmind.providers.bedrock import BedrockProvider


class TestAnalysisInsight:
    """Tests for AnalysisInsight."""

    def test_to_dict(self) -> None:
        """Test dictionary conversion."""
        insight = AnalysisInsight(
            title="Migrate to EKS",
            analysis="The team discussed migrating from EC2 to EKS.",
            recommendation="Start with non-critical services first.",
            category="decision",
        )
        result = insight.to_dict()
        assert result["title"] == "Migrate to EKS"
        assert result["category"] == "decision"
        assert "recommendation" in result

    def test_to_dict_all_categories(self) -> None:
        """Test all valid categories."""
        for category in ("decision", "action", "risk", "idea"):
            insight = AnalysisInsight(
                title="Test",
                analysis="Analysis",
                recommendation="Recommendation",
                category=category,
            )
            assert insight.to_dict()["category"] == category


class TestAnalysisAgent:
    """Tests for AnalysisAgent."""

    @pytest.fixture
    def mock_provider(self) -> AsyncMock:
        """Create a mock Bedrock provider."""
        return AsyncMock(spec=BedrockProvider)

    @pytest.fixture
    def agent(self, mock_provider: AsyncMock) -> AnalysisAgent:
        """Create an analysis agent with mock provider."""
        return AnalysisAgent(mock_provider)

    @pytest.mark.anyio
    async def test_analyze_success(self, agent: AnalysisAgent, mock_provider: AsyncMock) -> None:
        """Test successful analysis generating an insight."""
        mock_provider.invoke_analysis.return_value = {
            "content": (
                '{"title": "Database Migration Risk", '
                '"analysis": "The team is planning a major DB migration.", '
                '"recommendation": "Set up a rollback plan before proceeding.", '
                '"category": "risk"}'
            ),
            "latency_ms": 500.0,
        }

        result = await agent.analyze(
            segment="We should migrate the DB next week",
            context="Full meeting context...",
            screening_reason="Risk mentioned",
        )

        assert result is not None
        assert result.title == "Database Migration Risk"
        assert result.category == "risk"
        assert "rollback" in result.recommendation.lower()
        mock_provider.invoke_analysis.assert_called_once()

    @pytest.mark.anyio
    async def test_analyze_json_error(self, agent: AnalysisAgent, mock_provider: AsyncMock) -> None:
        """Test analysis with invalid JSON returns None."""
        mock_provider.invoke_analysis.return_value = {
            "content": "Here is my analysis...",
            "latency_ms": 400.0,
        }

        result = await agent.analyze(
            segment="Some text",
            context="Context",
            screening_reason="Reason",
        )

        assert result is None

    @pytest.mark.anyio
    async def test_analyze_provider_error(
        self, agent: AnalysisAgent, mock_provider: AsyncMock
    ) -> None:
        """Test analysis when provider raises exception."""
        mock_provider.invoke_analysis.side_effect = RuntimeError("Bedrock timeout")

        result = await agent.analyze(
            segment="Some text",
            context="Context",
            screening_reason="Reason",
        )

        assert result is None

    @pytest.mark.anyio
    async def test_analyze_context_truncation(
        self, agent: AnalysisAgent, mock_provider: AsyncMock
    ) -> None:
        """Test that long context is truncated in the prompt."""
        mock_provider.invoke_analysis.return_value = {
            "content": '{"title": "T", "analysis": "A", "recommendation": "R", "category": "idea"}',
            "latency_ms": 300.0,
        }

        long_context = "x" * 10000
        result = await agent.analyze(
            segment="Short",
            context=long_context,
            screening_reason="Test",
        )

        assert result is not None
        # Verify the prompt sent to Bedrock has truncated context
        call_args = mock_provider.invoke_analysis.call_args
        prompt = call_args[0][0]
        assert len(prompt) < len(long_context)
