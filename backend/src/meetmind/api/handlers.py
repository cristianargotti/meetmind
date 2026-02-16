"""AI pipeline handlers for WebSocket connections.

Extracted from websocket.py for maintainability.
Each handler runs an AI agent (screening, copilot, summary)
and sends results back through the connection manager.
"""

from __future__ import annotations

from collections.abc import Awaitable, Callable
from typing import TYPE_CHECKING

import structlog

from meetmind.config.settings import settings
from meetmind.core import storage
from meetmind.utils.cost_tracker import BudgetExceededError

if TYPE_CHECKING:
    from meetmind.agents.analysis_agent import AnalysisAgent
    from meetmind.agents.copilot_agent import CopilotAgent
    from meetmind.agents.screening_agent import ScreeningAgent
    from meetmind.agents.summary_agent import SummaryAgent
    from meetmind.utils.cost_tracker import CostTracker

logger = structlog.get_logger(__name__)

# Type alias for ConnectionManager.send_json
SendJsonFn = Callable[[str, dict[str, object]], Awaitable[None]]


async def _send_json(
    send_fn: SendJsonFn,
    connection_id: str,
    data: dict[str, object],
) -> None:
    """Send JSON data via the manager's send_json method.

    Args:
        send_fn: The ConnectionManager.send_json coroutine.
        connection_id: Target connection.
        data: Payload to send.
    """
    # send_fn is manager.send_json — a bound method
    await send_fn(connection_id, data)


async def send_cost_update(
    send_fn: SendJsonFn,
    connection_id: str,
    tracker: CostTracker | None,
) -> None:
    """Broadcast cost stats to the client.

    Args:
        send_fn: The manager's send_json method.
        connection_id: Target connection.
        tracker: Cost tracker for this session.
    """
    if tracker:
        await _send_json(
            send_fn,
            connection_id,
            {
                "type": "cost_update",
                **tracker.to_dict(),
            },
        )


async def send_budget_exceeded(
    send_fn: SendJsonFn,
    connection_id: str,
) -> None:
    """Notify client that session budget was exceeded.

    Args:
        send_fn: The manager's send_json method.
        connection_id: Target connection.
    """
    await _send_json(
        send_fn,
        connection_id,
        {
            "type": "budget_exceeded",
            "message": "Session budget limit reached. AI paused.",
        },
    )


async def run_screening_pipeline(
    send_fn: SendJsonFn,
    connection_id: str,
    screening_text: str,
    full_context: str,
    screening_agent: ScreeningAgent | None,
    analysis_agent: AnalysisAgent | None,
    tracker: CostTracker | None,
    language: str = "español",
) -> None:
    """Run the AI screening + analysis pipeline as a background task.

    Args:
        send_fn: The manager's send_json method.
        connection_id: WebSocket connection to send results to.
        screening_text: Text buffer to screen.
        full_context: Full meeting transcript for analysis context.
        screening_agent: The screening agent instance.
        analysis_agent: The analysis agent instance.
        tracker: Cost tracker for this session.
        language: Language for AI responses (e.g. 'español', 'english').
    """
    if not screening_agent or not analysis_agent:
        await _send_json(
            send_fn,
            connection_id,
            {
                "type": "screening",
                "relevant": False,
                "reason": "Agents not initialized (no AWS credentials)",
            },
        )
        return

    # Step 1: Screening (Haiku — fast, cheap)
    try:
        screening_result = await screening_agent.screen(
            screening_text,
        )
    except BudgetExceededError:
        await send_budget_exceeded(send_fn, connection_id)
        return

    # Record screening cost (provider-agnostic)
    if tracker:
        s_model = (
            settings.openai_screening_model
            if settings.llm_provider == "openai"
            else settings.bedrock_screening_model
        )
        tracker.record(
            s_model,
            input_tokens=screening_result.input_tokens,
            output_tokens=screening_result.output_tokens,
        )

    await _send_json(
        send_fn,
        connection_id,
        {
            "type": "screening",
            **screening_result.to_dict(),
        },
    )

    # Step 2: Analysis (Sonnet — only if relevant)
    if screening_result.relevant:
        try:
            insight = await analysis_agent.analyze(
                segment=screening_text,
                context=full_context,
                screening_reason=screening_result.reason,
                language=language,
            )
        except BudgetExceededError:
            await send_budget_exceeded(send_fn, connection_id)
            return

        if insight:
            # Record analysis cost (provider-agnostic)
            if tracker:
                a_model = (
                    settings.openai_analysis_model
                    if settings.llm_provider == "openai"
                    else settings.bedrock_analysis_model
                )
                tracker.record(
                    a_model,
                    input_tokens=insight.input_tokens,
                    output_tokens=insight.output_tokens,
                )

            await _send_json(
                send_fn,
                connection_id,
                {
                    "type": "analysis",
                    "insight": insight.to_dict(),
                },
            )

            # Persist insight to DB (graceful fallback)
            try:
                await storage.save_insight(connection_id, insight.to_dict())
            except Exception as e:
                logger.warning("insight_persist_failed", error=str(e))

    # Broadcast updated cost stats
    await send_cost_update(send_fn, connection_id, tracker)


async def run_copilot(
    send_fn: SendJsonFn,
    connection_id: str,
    question: str,
    transcript_context: str,
    copilot_agent: CopilotAgent | None,
    tracker: CostTracker | None,
) -> None:
    """Run the copilot agent to answer a user question.

    Args:
        send_fn: The manager's send_json method.
        connection_id: WebSocket connection to send response to.
        question: The user's question.
        transcript_context: Full meeting transcript for context.
        copilot_agent: The copilot agent instance.
        tracker: Cost tracker for this session.
    """
    if not copilot_agent:
        await _send_json(
            send_fn,
            connection_id,
            {
                "type": "copilot_response",
                "answer": "⚠️ Copilot not initialized (check LLM provider credentials)",
                "error": True,
            },
        )
        return

    response = await copilot_agent.respond(
        question,
        transcript_context,
    )

    # Record copilot cost (provider-agnostic)
    if tracker:
        if settings.llm_provider == "openai":
            model_id = settings.openai_copilot_model
        else:
            model_id = settings.bedrock_copilot_model
        tracker.record(
            model_id,
            input_tokens=response.input_tokens,
            output_tokens=response.output_tokens,
        )

    await _send_json(
        send_fn,
        connection_id,
        {
            "type": "copilot_response",
            "answer": response.answer,
            "latency_ms": response.latency_ms,
            "model_tier": response.model_tier,
            "error": response.answer.startswith("⚠️"),
        },
    )

    # Broadcast updated cost stats
    await send_cost_update(send_fn, connection_id, tracker)


async def run_summary(
    send_fn: SendJsonFn,
    connection_id: str,
    full_transcript: str,
    summary_agent: SummaryAgent | None,
    tracker: CostTracker | None,
    language: str = "español",
) -> None:
    """Generate a post-meeting summary.

    Args:
        send_fn: The manager's send_json method.
        connection_id: WebSocket connection to send result to.
        full_transcript: Complete meeting transcript.
        summary_agent: The summary agent instance.
        tracker: Cost tracker for this session.
        language: Language for AI responses (e.g. 'español', 'english').
    """
    if not summary_agent:
        await _send_json(
            send_fn,
            connection_id,
            {
                "type": "meeting_summary",
                "error": True,
                "summary": {
                    "title": "Error",
                    "summary": "⚠️ Summary agent not initialized",
                },
            },
        )
        return

    result = await summary_agent.summarize(full_transcript, language=language)

    # Record summary cost (provider-agnostic)
    if tracker:
        sum_model = (
            settings.openai_analysis_model
            if settings.llm_provider == "openai"
            else settings.bedrock_analysis_model
        )
        tracker.record(
            sum_model,
            input_tokens=result.input_tokens,
            output_tokens=result.output_tokens,
        )

    await _send_json(
        send_fn,
        connection_id,
        {
            "type": "meeting_summary",
            "summary": result.to_dict(),
            "latency_ms": result.latency_ms,
            "error": result.title == "Summary Error",
        },
    )

    # Persist summary to DB (graceful fallback)
    try:
        await storage.save_summary(connection_id, result.to_dict())
    except Exception as e:
        logger.warning("summary_persist_failed", error=str(e))

    # Broadcast updated cost stats
    await send_cost_update(send_fn, connection_id, tracker)
