"""Tests for SummaryAgent — post-meeting summary generation."""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock

import pytest

from meetmind.agents.summary_agent import (
    MeetingSummary,
    SummaryAgent,
)


@pytest.fixture
def mock_provider() -> MagicMock:
    """Create a mock BedrockProvider."""
    provider = MagicMock()
    provider.invoke_summary = AsyncMock()
    return provider


@pytest.fixture
def agent(mock_provider: MagicMock) -> SummaryAgent:
    """Create a SummaryAgent with mock provider."""
    return SummaryAgent(mock_provider)


# ─── MeetingSummary Tests ───────────────────────────


class TestMeetingSummary:
    """Tests for MeetingSummary dataclass."""

    def test_to_dict(self) -> None:
        """Verify to_dict includes all fields."""
        summary = MeetingSummary(
            title="Sprint Planning",
            summary="Team discussed migration plan.",
            key_topics=["migration", "database"],
            decisions=[{"what": "Use PostgreSQL", "who": "Team"}],
            action_items=[{"task": "Audit SQL", "owner": "Carlos", "deadline": "Friday"}],
            risks=[{"description": "ORM raw queries", "severity": "high"}],
            next_steps=["Review PR by Friday"],
        )
        d = summary.to_dict()
        assert d["title"] == "Sprint Planning"
        assert len(d["decisions"]) == 1
        assert len(d["action_items"]) == 1
        assert len(d["risks"]) == 1
        assert d["key_topics"] == ["migration", "database"]

    def test_empty_summary_defaults(self) -> None:
        """Verify empty summary has safe defaults."""
        summary = MeetingSummary(title="Test", summary="Test summary")
        d = summary.to_dict()
        assert d["decisions"] == []
        assert d["action_items"] == []
        assert d["risks"] == []
        assert d["next_steps"] == []


# ─── SummaryAgent Tests ─────────────────────────────


class TestSummaryAgent:
    """Tests for SummaryAgent.summarize()."""

    @pytest.mark.asyncio
    async def test_summarize_success(self, agent: SummaryAgent, mock_provider: MagicMock) -> None:
        """Verify summarize returns structured MeetingSummary."""
        mock_provider.invoke_summary.return_value = {
            "content": (
                '{"title":"Sprint Planning"'
                ',"summary":"Team discussed migration."'
                ',"key_topics":["migration"]'
                ',"decisions":[{"what":"Use pgloader","who":"Team"}]'
                ',"action_items":[{"task":"Audit SQL"'
                ',"owner":"Carlos","deadline":"Friday"}]'
                ',"risks":[{"description":"Raw queries"'
                ',"severity":"high"}]'
                ',"next_steps":["Review PR"]}'
            ),
            "latency_ms": 1500.0,
            "input_tokens": 500,
            "output_tokens": 100,
        }

        result = await agent.summarize("Team discussed migration plan...")
        assert result.title == "Sprint Planning"
        assert len(result.decisions) == 1
        assert result.decisions[0]["what"] == "Use pgloader"
        assert len(result.action_items) == 1
        assert result.action_items[0]["owner"] == "Carlos"
        assert len(result.risks) == 1
        assert result.latency_ms == 1500.0

    @pytest.mark.asyncio
    async def test_summarize_empty_transcript(self, agent: SummaryAgent) -> None:
        """Verify empty transcript returns empty summary without calling LLM."""
        result = await agent.summarize("")
        assert result.title == "Empty Meeting"
        assert "No transcript" in result.summary

    @pytest.mark.asyncio
    async def test_summarize_whitespace_only(self, agent: SummaryAgent) -> None:
        """Verify whitespace-only transcript returns empty summary."""
        result = await agent.summarize("   \n  \t  ")
        assert result.title == "Empty Meeting"

    @pytest.mark.asyncio
    async def test_summarize_json_in_fence(
        self, agent: SummaryAgent, mock_provider: MagicMock
    ) -> None:
        """Verify JSON extracted from markdown code fence."""
        mock_provider.invoke_summary.return_value = {
            "content": (
                "```json\n"
                '{"title":"Standup","summary":"Quick sync."'
                ',"key_topics":[],"decisions":[]'
                ',"action_items":[],"risks":[]'
                ',"next_steps":[]}\n```'
            ),
            "latency_ms": 800.0,
        }

        result = await agent.summarize("Quick standup sync...")
        assert result.title == "Standup"
        assert result.summary == "Quick sync."

    @pytest.mark.asyncio
    async def test_summarize_provider_error(
        self, agent: SummaryAgent, mock_provider: MagicMock
    ) -> None:
        """Verify graceful handling of provider errors."""
        mock_provider.invoke_summary.side_effect = Exception("Bedrock timeout")

        result = await agent.summarize("Some transcript...")
        assert result.title == "Summary Error"
        assert "Bedrock timeout" in result.summary

    @pytest.mark.asyncio
    async def test_summarize_malformed_json(
        self, agent: SummaryAgent, mock_provider: MagicMock
    ) -> None:
        """Verify graceful handling of malformed JSON from LLM."""
        mock_provider.invoke_summary.return_value = {
            "content": "This is not JSON at all, just a plain text response.",
            "latency_ms": 600.0,
        }

        result = await agent.summarize("Some meeting transcript...")
        # Should return with fallback title and raw content as summary
        assert result.title == "Meeting Summary"
        assert "This is not JSON" in result.summary

    @pytest.mark.asyncio
    async def test_summarize_partial_json(
        self, agent: SummaryAgent, mock_provider: MagicMock
    ) -> None:
        """Verify partial JSON returns available fields with defaults."""
        mock_provider.invoke_summary.return_value = {
            "content": '{"title":"Retro","summary":"Team retro."}',
            "latency_ms": 500.0,
        }

        result = await agent.summarize("Retro meeting...")
        assert result.title == "Retro"
        assert result.summary == "Team retro."
        assert result.decisions == []
        assert result.action_items == []

    @pytest.mark.asyncio
    async def test_summarize_json_with_extra_text(
        self, agent: SummaryAgent, mock_provider: MagicMock
    ) -> None:
        """Verify JSON extracted when surrounded by extra text."""
        mock_provider.invoke_summary.return_value = {
            "content": (
                "Here is your summary:\n\n"
                '{"title":"Planning"'
                ',"summary":"Good meeting."'
                ',"key_topics":["api"]'
                ',"decisions":[],"action_items":[]'
                ',"risks":[],"next_steps":[]}'
                "\n\nLet me know if you need more."
            ),
            "latency_ms": 700.0,
        }

        result = await agent.summarize("Planning meeting transcript...")
        assert result.title == "Planning"
        assert result.key_topics == ["api"]
