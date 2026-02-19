"""REST API module for meeting AI features.

Replaces the WebSocket-based approach with simple REST endpoints.
STT is handled on-device (Whisper); this module provides:
  - Transcript ingestion + AI screening
  - Copilot chat (question/answer with meeting context)
  - Post-meeting summary generation
"""

from __future__ import annotations

from typing import TYPE_CHECKING, Any

import structlog

from meetmind.agents.analysis_agent import AnalysisAgent
from meetmind.agents.copilot_agent import CopilotAgent
from meetmind.agents.screening_agent import ScreeningAgent
from meetmind.agents.summary_agent import SummaryAgent
from meetmind.config.settings import settings
from meetmind.core import storage
from meetmind.core.transcript import TranscriptManager
from meetmind.providers.factory import create_llm_provider
from meetmind.utils.cost_tracker import BudgetExceededError, CostTracker

if TYPE_CHECKING:
    from meetmind.providers.base import LLMProvider

logger = structlog.get_logger(__name__)


class MeetingManager:
    """Manages meeting sessions and AI agents (stateless — no WebSocket).

    Initialized once at app startup. Provides AI agent access
    for the REST endpoints.
    """

    def __init__(self) -> None:
        """Initialize the meeting manager."""
        self._provider: LLMProvider | None = None
        self._screening_agent: ScreeningAgent | None = None
        self._analysis_agent: AnalysisAgent | None = None
        self._copilot_agent: CopilotAgent | None = None
        self._summary_agent: SummaryAgent | None = None
        # Per-meeting session state (meeting_id → state)
        self._transcripts: dict[str, TranscriptManager] = {}
        self._cost_trackers: dict[str, CostTracker] = {}
        self._languages: dict[str, str] = {}

    def init_agents(self) -> None:
        """Initialize LLM provider and AI agents.

        Call during FastAPI lifespan startup.
        Uses settings.llm_provider to select bedrock or openai.
        """
        provider = create_llm_provider()
        self._provider = provider
        self._screening_agent = ScreeningAgent(provider)
        self._analysis_agent = AnalysisAgent(provider)
        self._copilot_agent = CopilotAgent(provider)
        self._summary_agent = SummaryAgent(provider)
        logger.info("agents_initialized", provider=settings.llm_provider)

    @property
    def agents_ready(self) -> bool:
        """Check if AI agents are initialized."""
        return self._screening_agent is not None

    async def get_or_create_session(
        self,
        meeting_id: str,
        language: str = "es",
        user_id: str | None = None,
    ) -> None:
        """Ensure a meeting session exists (in-memory + DB).

        Args:
            meeting_id: The unique meeting identifier.
            language: Language code (e.g. 'es', 'en').
            user_id: Owner's user ID for DB persistence.
        """
        if meeting_id not in self._transcripts:
            transcript = TranscriptManager(
                screening_interval=settings.screening_interval_seconds,
            )
            transcript.set_meeting_id(meeting_id)
            self._transcripts[meeting_id] = transcript
            self._cost_trackers[meeting_id] = CostTracker(
                budget_usd=settings.session_budget_usd,
            )
            lang_map = {
                "es": "español",
                "en": "english",
                "pt": "português",
                "fr": "français",
                "de": "deutsch",
            }
            self._languages[meeting_id] = lang_map.get(language, language)

            # Persist meeting to DB (idempotent — ignores if exists)
            try:
                await storage.create_meeting(
                    meeting_id=meeting_id,
                    language=language,
                    user_id=user_id,
                )
            except Exception as e:
                # Meeting may already exist — that's fine
                logger.debug(
                    "meeting_create_skipped",
                    meeting_id=meeting_id,
                    reason=str(e),
                )

    def cleanup_session(self, meeting_id: str) -> None:
        """Remove session state for a completed meeting.

        Args:
            meeting_id: The meeting to clean up.
        """
        self._transcripts.pop(meeting_id, None)
        self._cost_trackers.pop(meeting_id, None)
        self._languages.pop(meeting_id, None)

    async def ingest_transcript(
        self,
        meeting_id: str,
        segments: list[dict[str, Any]],
        language: str = "es",
        user_id: str | None = None,
    ) -> dict[str, Any]:
        """Ingest transcript segments and run screening if needed.

        Args:
            meeting_id: The meeting ID to add segments to.
            segments: List of {text, speaker} dicts from the client.
            language: Language code for AI responses.
            user_id: Owner's user ID for DB persistence.

        Returns:
            Dict with screening/analysis results (if triggered).
        """
        await self.get_or_create_session(meeting_id, language, user_id=user_id)
        transcript = self._transcripts[meeting_id]
        tracker = self._cost_trackers.get(meeting_id)
        lang = self._languages.get(meeting_id, "español")

        result: dict[str, Any] = {"segments_added": 0, "screening": None}

        for seg in segments:
            text = seg.get("text", "")
            speaker = seg.get("speaker", "unknown")
            if text.strip():
                transcript.add_chunk(text, speaker=speaker)
                result["segments_added"] += 1

        # Persist segments to DB
        try:
            await storage.save_segments(meeting_id, segments)
        except Exception as e:
            logger.warning("transcript_persist_failed", error=str(e))

        # Run screening if buffer threshold reached
        if transcript.should_screen() and self._screening_agent:
            screening_text = transcript.get_screening_text()
            full_context = transcript.get_full_transcript()
            screening_result = await self._run_screening(
                meeting_id,
                screening_text,
                full_context,
                tracker,
                lang,
            )
            result["screening"] = screening_result

        return result

    async def _run_screening(
        self,
        meeting_id: str,
        screening_text: str,
        full_context: str,
        tracker: CostTracker | None,
        language: str,
    ) -> dict[str, Any]:
        """Run screening + analysis pipeline.

        Args:
            meeting_id: Meeting identifier.
            screening_text: Text to screen.
            full_context: Full transcript for analysis context.
            tracker: Cost tracker for this session.
            language: Language for AI responses.

        Returns:
            Dict with screening and analysis results.
        """
        result: dict[str, Any] = {"relevant": False}

        if not self._screening_agent or not self._analysis_agent:
            result["reason"] = "Agents not initialized"
            return result

        try:
            screening = await self._screening_agent.screen(screening_text)
        except BudgetExceededError:
            result["budget_exceeded"] = True
            return result

        if tracker:
            s_model = (
                settings.openai_screening_model
                if settings.llm_provider == "openai"
                else settings.bedrock_screening_model
            )
            tracker.record(
                s_model,
                input_tokens=screening.input_tokens,
                output_tokens=screening.output_tokens,
            )

        result.update(screening.to_dict())

        if screening.relevant:
            try:
                insight = await self._analysis_agent.analyze(
                    segment=screening_text,
                    context=full_context,
                    screening_reason=screening.reason,
                    language=language,
                )
            except BudgetExceededError:
                result["budget_exceeded"] = True
                return result

            if insight:
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
                result["analysis"] = insight.to_dict()

                try:
                    await storage.save_insight(meeting_id, insight.to_dict())
                except Exception as e:
                    logger.warning("insight_persist_failed", error=str(e))

        return result

    async def run_copilot(
        self,
        meeting_id: str,
        question: str,
        transcript_context: str,
    ) -> dict[str, Any]:
        """Run copilot to answer a question with meeting context.

        Args:
            meeting_id: Meeting identifier (for cost tracking).
            question: The user's question.
            transcript_context: Full meeting transcript.

        Returns:
            Dict with AI answer and metadata.
        """
        if not self._copilot_agent:
            return {
                "answer": "⚠️ Copilot not initialized",
                "error": True,
            }

        tracker = self._cost_trackers.get(meeting_id)

        try:
            response = await self._copilot_agent.respond(
                question,
                transcript_context,
            )
        except Exception as e:
            logger.warning("copilot_llm_failed", error=str(e))
            return {
                "answer": f"⚠️ AI temporarily unavailable: {e}",
                "error": True,
                "latency_ms": 0,
            }

        if tracker:
            model_id = (
                settings.openai_copilot_model
                if settings.llm_provider == "openai"
                else settings.bedrock_copilot_model
            )
            tracker.record(
                model_id,
                input_tokens=response.input_tokens,
                output_tokens=response.output_tokens,
            )

        return {
            "answer": response.answer,
            "latency_ms": response.latency_ms,
            "model_tier": response.model_tier,
            "error": response.answer.startswith("⚠️"),
        }

    async def run_summary(
        self,
        meeting_id: str,
        full_transcript: str,
        language: str = "es",
    ) -> dict[str, Any]:
        """Generate a post-meeting summary.

        Args:
            meeting_id: Meeting identifier (for cost tracking + DB).
            full_transcript: Complete meeting transcript.
            language: Language code for AI response.

        Returns:
            Dict with summary data.
        """
        if not self._summary_agent:
            return {
                "error": True,
                "summary": {
                    "title": "Error",
                    "summary": "⚠️ Summary agent not initialized",
                },
            }

        tracker = self._cost_trackers.get(meeting_id)
        lang = self._languages.get(meeting_id, language)
        result = await self._summary_agent.summarize(
            full_transcript,
            language=lang,
        )

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

        summary_data = result.to_dict()

        try:
            await storage.save_summary(meeting_id, summary_data)
        except Exception as e:
            logger.warning("summary_persist_failed", error=str(e))

        return {
            "summary": summary_data,
            "latency_ms": result.latency_ms,
            "error": result.title == "Summary Error",
        }


# Global meeting manager instance
meeting_manager = MeetingManager()
