"""Tests for the copilot agent."""

from unittest.mock import AsyncMock

import pytest

from meetmind.agents.copilot_agent import (
    CRIS_PERSONA,
    CopilotAgent,
    CopilotResponse,
)
from meetmind.providers.bedrock import BedrockProvider


class TestCopilotResponse:
    """Tests for CopilotResponse."""

    def test_fields(self) -> None:
        """Test response fields are correctly set."""
        response = CopilotResponse(
            answer="Use dual-write strategy",
            latency_ms=1500.0,
            input_tokens=200,
            output_tokens=50,
        )
        assert response.answer == "Use dual-write strategy"
        assert response.latency_ms == 1500.0
        assert response.input_tokens == 200
        assert response.output_tokens == 50

    def test_frozen(self) -> None:
        """Test response is immutable."""
        response = CopilotResponse(
            answer="test", latency_ms=100.0, input_tokens=10, output_tokens=5
        )
        with pytest.raises(AttributeError):
            response.answer = "changed"  # type: ignore[misc]


class TestCrisPersona:
    """Tests for the Cris Persona system prompt."""

    def test_contains_identity(self) -> None:
        """Test persona defines identity."""
        assert "Digital Cris" in CRIS_PERSONA
        assert "SRE Senior" in CRIS_PERSONA

    def test_contains_expertise(self) -> None:
        """Test persona includes technical expertise."""
        assert "AWS" in CRIS_PERSONA
        assert "Kubernetes" in CRIS_PERSONA
        assert "Datadog" in CRIS_PERSONA

    def test_contains_rules(self) -> None:
        """Test persona defines response rules."""
        assert "2-5 lines" in CRIS_PERSONA
        assert "actionable" in CRIS_PERSONA


class TestCopilotAgent:
    """Tests for CopilotAgent."""

    @pytest.fixture
    def mock_provider(self) -> AsyncMock:
        """Create a mock Bedrock provider."""
        provider = AsyncMock(spec=BedrockProvider)
        return provider

    @pytest.fixture
    def agent(self, mock_provider: AsyncMock) -> CopilotAgent:
        """Create a copilot agent with mock provider."""
        return CopilotAgent(mock_provider)

    @pytest.mark.anyio
    async def test_respond_with_context(
        self, agent: CopilotAgent, mock_provider: AsyncMock
    ) -> None:
        """Test copilot responds with meeting context."""
        mock_provider.invoke_copilot.return_value = {
            "content": "Redis es buena opción pero revisa el connection pooling 🔥",
            "latency_ms": 2000.0,
            "input_tokens": 300,
            "output_tokens": 30,
        }

        result = await agent.respond(
            question="¿Qué opinas de migrar a Redis?",
            transcript_context="Juan: Deberíamos migrar el cache a Redis.",
        )

        assert "Redis" in result.answer
        assert result.latency_ms == 2000.0
        assert result.input_tokens == 300
        assert result.output_tokens == 30
        mock_provider.invoke_copilot.assert_called_once()

    @pytest.mark.anyio
    async def test_respond_without_context(
        self, agent: CopilotAgent, mock_provider: AsyncMock
    ) -> None:
        """Test copilot responds even without transcript context."""
        mock_provider.invoke_copilot.return_value = {
            "content": "El meeting acaba de empezar. Escuchemos primero.",
            "latency_ms": 1000.0,
            "input_tokens": 50,
            "output_tokens": 15,
        }

        result = await agent.respond(
            question="¿De qué va este meeting?",
            transcript_context="",
        )

        assert result.answer != ""
        assert result.latency_ms == 1000.0

    @pytest.mark.anyio
    async def test_respond_builds_prompt_with_context(
        self, agent: CopilotAgent, mock_provider: AsyncMock
    ) -> None:
        """Test prompt includes transcript context."""
        mock_response = {
            "content": "Test response",
            "latency_ms": 100.0,
            "input_tokens": 10,
            "output_tokens": 5,
        }
        # Mock both routes (smart routing may pick either)
        mock_provider.invoke_copilot.return_value = mock_response
        mock_provider.invoke_screening.return_value = mock_response

        await agent.respond(
            question="Explain the architecture decision here",
            transcript_context="Some meeting transcript",
        )

        # Complex query → invoke_copilot
        call_args = mock_provider.invoke_copilot.call_args[0][0]
        assert "Some meeting transcript" in call_args
        assert "Explain" in call_args

    @pytest.mark.anyio
    async def test_respond_builds_prompt_without_context(
        self, agent: CopilotAgent, mock_provider: AsyncMock
    ) -> None:
        """Test prompt mentions no transcript when context is empty."""
        mock_response = {
            "content": "Test response",
            "latency_ms": 100.0,
            "input_tokens": 10,
            "output_tokens": 5,
        }
        mock_provider.invoke_copilot.return_value = mock_response
        mock_provider.invoke_screening.return_value = mock_response

        await agent.respond(
            question="Explain what is happening in this meeting",
            transcript_context="",
        )

        call_args = mock_provider.invoke_copilot.call_args[0][0]
        assert "no transcript" in call_args.lower()
        assert "Explain" in call_args

    @pytest.mark.anyio
    async def test_respond_provider_error(
        self, agent: CopilotAgent, mock_provider: AsyncMock
    ) -> None:
        """Test copilot handles provider errors gracefully."""
        mock_provider.invoke_copilot.side_effect = RuntimeError("AWS timeout")
        mock_provider.invoke_screening.side_effect = RuntimeError("AWS timeout")

        result = await agent.respond(
            question="Explain why the deployment failed",
            transcript_context="Some context",
        )

        assert "⚠️" in result.answer
        assert "AWS timeout" in result.answer
        assert result.input_tokens == 0

    @pytest.mark.anyio
    async def test_respond_strips_whitespace(
        self, agent: CopilotAgent, mock_provider: AsyncMock
    ) -> None:
        """Test response content is stripped."""
        mock_response = {
            "content": "  Respuesta con espacios  \n",
            "latency_ms": 100.0,
            "input_tokens": 10,
            "output_tokens": 5,
        }
        mock_provider.invoke_copilot.return_value = mock_response
        mock_provider.invoke_screening.return_value = mock_response

        result = await agent.respond("Explain the situation", "Context")

        assert result.answer == "Respuesta con espacios"
