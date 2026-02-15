"""Summary Agent — generates structured post-meeting reports.

Triggered when the user clicks "Generate Summary" after a meeting.
Uses the full transcript context to produce a structured report
with decisions, action items, risks, and next steps.

Uses Sonnet 4.5 for high-quality structured output.
"""

from __future__ import annotations

import json
import re
import time
from dataclasses import dataclass, field
from typing import TYPE_CHECKING, Any

import structlog

if TYPE_CHECKING:
    from meetmind.providers.base import LLMProvider

logger = structlog.get_logger(__name__)

SUMMARY_SYSTEM_PROMPT = """\
You are an expert meeting summarizer. Analyze the full meeting transcript
and produce a structured JSON summary.

## Output Format (strict JSON)

{
  "title": "Meeting title (inferred from context)",
  "key_topics": ["topic1", "topic2", ...],
  "decisions": [
    {"what": "Description of the decision", "who": "Person(s) involved"}
  ],
  "action_items": [
    {"task": "What needs to be done", "owner": "Person responsible", "deadline": "If mentioned"}
  ],
  "risks": [
    {"description": "Risk identified", "severity": "high|medium|low"}
  ],
  "next_steps": ["Next step 1", "Next step 2"],
  "summary": "2-3 sentence executive summary of the entire meeting"
}

## Rules
- Extract ONLY what was explicitly said — never invent information
- If no owner was mentioned for an action item, use "TBD"
- If no deadline was mentioned, use "Not specified"
- Keep descriptions concise (1-2 lines each)
- Respond with ONLY the JSON object, no extra text
"""


@dataclass(frozen=True)
class MeetingSummary:
    """Structured meeting summary."""

    title: str
    summary: str
    key_topics: list[str] = field(default_factory=list)
    decisions: list[dict[str, str]] = field(default_factory=list)
    action_items: list[dict[str, str]] = field(default_factory=list)
    risks: list[dict[str, str]] = field(default_factory=list)
    next_steps: list[str] = field(default_factory=list)
    latency_ms: float = 0.0
    input_tokens: int = 0
    output_tokens: int = 0

    def to_dict(self) -> dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return {
            "title": self.title,
            "summary": self.summary,
            "key_topics": self.key_topics,
            "decisions": self.decisions,
            "action_items": self.action_items,
            "risks": self.risks,
            "next_steps": self.next_steps,
        }


class SummaryAgent:
    """Post-meeting summary generator."""

    def __init__(self, provider: LLMProvider) -> None:
        """Initialize summary agent.

        Args:
            provider: LLM provider for AI calls.
        """
        self._provider = provider

    async def summarize(
        self,
        full_transcript: str,
    ) -> MeetingSummary:
        """Generate a structured meeting summary.

        Args:
            full_transcript: Complete meeting transcript.

        Returns:
            MeetingSummary with structured data.
        """
        if not full_transcript.strip():
            return MeetingSummary(
                title="Empty Meeting",
                summary="No transcript content was captured.",
            )

        prompt = (
            f"## Full Meeting Transcript\n\n"
            f"{full_transcript}\n\n"
            f"---\n\n"
            f"Generate the structured JSON summary now."
        )

        start = time.monotonic()

        try:
            result = await self._provider.invoke_summary(prompt)
            content = str(result.get("content", "")).strip()
            latency_ms = result.get("latency_ms", 0.0)

            # Parse JSON from response
            parsed = self._extract_json(content)

            logger.info(
                "summary_generated",
                title=parsed.get("title", "")[:60],
                decisions=len(parsed.get("decisions", [])),
                action_items=len(parsed.get("action_items", [])),
                risks=len(parsed.get("risks", [])),
                latency_ms=latency_ms,
            )

            return MeetingSummary(
                title=parsed.get("title", "Meeting Summary"),
                summary=parsed.get("summary", ""),
                key_topics=parsed.get("key_topics", []),
                decisions=parsed.get("decisions", []),
                action_items=parsed.get("action_items", []),
                risks=parsed.get("risks", []),
                next_steps=parsed.get("next_steps", []),
                latency_ms=latency_ms,
                input_tokens=result.get("input_tokens", 0),
                output_tokens=result.get("output_tokens", 0),
            )

        except Exception as e:
            elapsed = (time.monotonic() - start) * 1000
            logger.error("summary_error", error=str(e))
            return MeetingSummary(
                title="Summary Error",
                summary=f"⚠️ Failed to generate summary: {e!s}",
                latency_ms=elapsed,
            )

    def _extract_json(self, content: str) -> dict[str, Any]:
        """Extract JSON object from LLM response.

        Handles markdown fences, extra text, or raw JSON.

        Args:
            content: Raw LLM response text.

        Returns:
            Parsed dictionary.
        """
        # Try direct parse first
        try:
            result: dict[str, Any] = json.loads(content)
            return result
        except json.JSONDecodeError:
            pass

        # Try extracting from markdown fence
        fence_match = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", content, re.DOTALL)
        if fence_match:
            try:
                return dict(json.loads(fence_match.group(1)))
            except json.JSONDecodeError:
                pass

        # Try extracting any JSON object
        brace_match = re.search(r"\{.*\}", content, re.DOTALL)
        if brace_match:
            try:
                return dict(json.loads(brace_match.group(0)))
            except json.JSONDecodeError:
                pass

        logger.warning("summary_json_parse_error", raw_content=content[:200])
        return {"title": "Meeting Summary", "summary": content[:500]}
