"""Tests for AI pipeline handlers."""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from meetmind.api.handlers import (
    run_copilot,
    run_screening_pipeline,
    run_summary,
    send_budget_exceeded,
    send_cost_update,
)
from meetmind.utils.cost_tracker import BudgetExceededError


@pytest.fixture
def send_fn() -> AsyncMock:
    """Create a mock send_json function."""
    return AsyncMock()


@pytest.fixture
def mock_tracker() -> MagicMock:
    """Create a mock CostTracker."""
    t = MagicMock()
    t.to_dict.return_value = {
        "total_cost_usd": 0.01,
        "budget_remaining_usd": 0.99,
        "budget_pct": 1.0,
    }
    return t


# ─── send_cost_update ────────────────────────────────────────────


@pytest.mark.asyncio
async def test_send_cost_update_with_tracker(send_fn: AsyncMock, mock_tracker: MagicMock) -> None:
    """send_cost_update broadcasts cost stats."""
    await send_cost_update(send_fn, "conn-1", mock_tracker)
    send_fn.assert_called_once()
    payload = send_fn.call_args[0][1]
    assert payload["type"] == "cost_update"


@pytest.mark.asyncio
async def test_send_cost_update_no_tracker(send_fn: AsyncMock) -> None:
    """send_cost_update does nothing without a tracker."""
    await send_cost_update(send_fn, "conn-1", None)
    send_fn.assert_not_called()


# ─── send_budget_exceeded ────────────────────────────────────────


@pytest.mark.asyncio
async def test_send_budget_exceeded(send_fn: AsyncMock) -> None:
    """send_budget_exceeded notifies the client."""
    await send_budget_exceeded(send_fn, "conn-1")
    send_fn.assert_called_once()
    payload = send_fn.call_args[0][1]
    assert payload["type"] == "budget_exceeded"


# ─── run_screening_pipeline ──────────────────────────────────────


@pytest.mark.asyncio
async def test_screening_no_agents(send_fn: AsyncMock) -> None:
    """Screening returns early when agents are not initialized."""
    await run_screening_pipeline(
        send_fn,
        "conn-1",
        "test text",
        "full context",
        screening_agent=None,
        analysis_agent=None,
        tracker=None,
    )
    send_fn.assert_called_once()
    payload = send_fn.call_args[0][1]
    assert payload["type"] == "screening"
    assert payload["relevant"] is False


@pytest.mark.asyncio
async def test_screening_budget_exceeded(send_fn: AsyncMock) -> None:
    """Screening sends budget_exceeded when BudgetExceededError is raised."""
    mock_agent = MagicMock()
    mock_agent.screen = AsyncMock(side_effect=BudgetExceededError("over budget"))

    await run_screening_pipeline(
        send_fn,
        "conn-1",
        "text",
        "context",
        screening_agent=mock_agent,
        analysis_agent=MagicMock(),
        tracker=None,
    )
    # Should send budget_exceeded message
    payload = send_fn.call_args[0][1]
    assert payload["type"] == "budget_exceeded"


@pytest.mark.asyncio
async def test_screening_not_relevant(send_fn: AsyncMock, mock_tracker: MagicMock) -> None:
    """Screening sends result and skips analysis when not relevant."""
    mock_screening = MagicMock()
    result = MagicMock()
    result.relevant = False
    result.reason = "not important"
    result.input_tokens = 10
    result.output_tokens = 5
    result.to_dict.return_value = {"relevant": False, "reason": "not important"}
    mock_screening.screen = AsyncMock(return_value=result)

    await run_screening_pipeline(
        send_fn,
        "conn-1",
        "text",
        "context",
        screening_agent=mock_screening,
        analysis_agent=MagicMock(),
        tracker=mock_tracker,
        language="español",
    )
    # Should have calls: screening result + cost update
    assert send_fn.call_count == 2


@pytest.mark.asyncio
@patch("meetmind.api.handlers.storage")
async def test_screening_relevant_with_analysis(
    mock_storage: MagicMock,
    send_fn: AsyncMock,
    mock_tracker: MagicMock,
) -> None:
    """Full pipeline: screening + analysis when relevant."""
    # Screening result
    screening_result = MagicMock()
    screening_result.relevant = True
    screening_result.reason = "important topic"
    screening_result.input_tokens = 10
    screening_result.output_tokens = 5
    screening_result.to_dict.return_value = {"relevant": True, "reason": "important"}

    mock_screening = MagicMock()
    mock_screening.screen = AsyncMock(return_value=screening_result)

    # Analysis result
    insight = MagicMock()
    insight.input_tokens = 50
    insight.output_tokens = 100
    insight.to_dict.return_value = {"title": "Insight", "content": "Analysis result"}

    mock_analysis = MagicMock()
    mock_analysis.analyze = AsyncMock(return_value=insight)

    mock_storage.save_insight = AsyncMock()

    await run_screening_pipeline(
        send_fn,
        "conn-1",
        "text",
        "context",
        screening_agent=mock_screening,
        analysis_agent=mock_analysis,
        tracker=mock_tracker,
        language="español",
    )
    # Should have: screening + analysis + cost_update
    assert send_fn.call_count == 3
    mock_storage.save_insight.assert_called_once()


@pytest.mark.asyncio
async def test_screening_analysis_budget_exceeded(
    send_fn: AsyncMock, mock_tracker: MagicMock
) -> None:
    """Analysis budget exceeded sends notification."""
    screening_result = MagicMock()
    screening_result.relevant = True
    screening_result.reason = "important"
    screening_result.input_tokens = 10
    screening_result.output_tokens = 5
    screening_result.to_dict.return_value = {"relevant": True}

    mock_screening = MagicMock()
    mock_screening.screen = AsyncMock(return_value=screening_result)

    mock_analysis = MagicMock()
    mock_analysis.analyze = AsyncMock(side_effect=BudgetExceededError("over"))

    await run_screening_pipeline(
        send_fn,
        "conn-1",
        "text",
        "context",
        screening_agent=mock_screening,
        analysis_agent=mock_analysis,
        tracker=mock_tracker,
    )
    # Last call should be budget_exceeded
    last_payload = send_fn.call_args[0][1]
    assert last_payload["type"] == "budget_exceeded"


# ─── run_copilot ─────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_copilot_no_agent(send_fn: AsyncMock) -> None:
    """Copilot returns error when agent is not initialized."""
    await run_copilot(
        send_fn,
        "conn-1",
        "question?",
        "transcript",
        copilot_agent=None,
        tracker=None,
    )
    payload = send_fn.call_args[0][1]
    assert payload["type"] == "copilot_response"
    assert payload["error"] is True


@pytest.mark.asyncio
async def test_copilot_success(send_fn: AsyncMock, mock_tracker: MagicMock) -> None:
    """Copilot responds with answer and cost update."""
    response = MagicMock()
    response.answer = "The answer is 42"
    response.latency_ms = 150
    response.model_tier = "standard"
    response.input_tokens = 20
    response.output_tokens = 30

    mock_agent = MagicMock()
    mock_agent.respond = AsyncMock(return_value=response)

    await run_copilot(
        send_fn,
        "conn-1",
        "question?",
        "transcript",
        copilot_agent=mock_agent,
        tracker=mock_tracker,
    )
    assert send_fn.call_count == 2  # response + cost_update
    payload = send_fn.call_args_list[0][0][1]
    assert payload["type"] == "copilot_response"
    assert payload["answer"] == "The answer is 42"


# ─── run_summary ─────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_summary_no_agent(send_fn: AsyncMock) -> None:
    """Summary returns error when agent is not initialized."""
    await run_summary(
        send_fn,
        "conn-1",
        "full transcript",
        summary_agent=None,
        tracker=None,
    )
    payload = send_fn.call_args[0][1]
    assert payload["type"] == "meeting_summary"
    assert payload["error"] is True


@pytest.mark.asyncio
@patch("meetmind.api.handlers.storage")
async def test_summary_success(
    mock_storage: MagicMock,
    send_fn: AsyncMock,
    mock_tracker: MagicMock,
) -> None:
    """Summary generates and persists result."""
    result = MagicMock()
    result.title = "Meeting Summary"
    result.input_tokens = 500
    result.output_tokens = 200
    result.latency_ms = 3000
    result.to_dict.return_value = {"title": "Meeting Summary", "overview": "Discussion"}

    mock_agent = MagicMock()
    mock_agent.summarize = AsyncMock(return_value=result)
    mock_storage.save_summary = AsyncMock()

    await run_summary(
        send_fn,
        "conn-1",
        "full transcript",
        summary_agent=mock_agent,
        tracker=mock_tracker,
    )
    # summary + cost_update
    assert send_fn.call_count == 2
    mock_storage.save_summary.assert_called_once()
