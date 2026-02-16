"""Analysis agent — deep insight generation.

Triggered when the screening agent marks a transcript segment as
relevant. Generates structured insights: decisions, action items,
risks, and ideas.
"""

import json
import re

import structlog

from meetmind.providers.base import LLMProvider

logger = structlog.get_logger(__name__)


class AnalysisInsight:
    """A structured insight from transcript analysis."""

    def __init__(
        self,
        title: str,
        analysis: str,
        recommendation: str,
        category: str,
        input_tokens: int = 0,
        output_tokens: int = 0,
    ) -> None:
        """Initialize an analysis insight.

        Args:
            title: Brief insight title.
            analysis: Detailed analysis text.
            recommendation: Actionable recommendation.
            category: Category (decision, action, risk, idea).
            input_tokens: Number of input tokens used.
            output_tokens: Number of output tokens used.
        """
        self.title = title
        self.analysis = analysis
        self.recommendation = recommendation
        self.category = category
        self.input_tokens = input_tokens
        self.output_tokens = output_tokens

    def to_dict(self) -> dict[str, str]:
        """Convert to dictionary for WebSocket transmission."""
        return {
            "title": self.title,
            "analysis": self.analysis,
            "recommendation": self.recommendation,
            "category": self.category,
        }


class AnalysisAgent:
    """AI analysis agent — generates insights from relevant segments.

    Uses Claude Sonnet 4.5 via Bedrock to analyze transcript segments
    that passed screening and generate actionable insights.
    """

    ANALYSIS_PROMPT = (
        "IMPORTANT: Respond entirely in {language}. "
        "All text values in the JSON must be in {language}.\n\n"
        "Analyze this meeting transcript segment and provide a structured insight.\n\n"
        "Context: {context}\n\n"
        "Relevant segment: {segment}\n\n"
        "Screening reason: {reason}\n\n"
        "Respond with JSON:\n"
        "{{\n"
        '  "title": "Brief insight title (1 line)",\n'
        '  "analysis": "Your analysis (2-3 sentences)",\n'
        '  "recommendation": "Concrete actionable recommendation",\n'
        '  "category": "decision|action|risk|idea"\n'
        "}}"
    )

    def __init__(self, provider: LLMProvider) -> None:
        """Initialize with an LLM provider.

        Args:
            provider: LLM provider instance.
        """
        self._provider = provider

    async def analyze(
        self,
        segment: str,
        context: str,
        screening_reason: str,
        language: str = "español",
    ) -> AnalysisInsight | None:
        """Analyze a relevant transcript segment and generate an insight.

        Args:
            segment: The relevant transcript text.
            context: Full meeting transcript for context.
            screening_reason: Why screening flagged this as relevant.
            language: Language for the response (e.g. 'español', 'english').

        Returns:
            AnalysisInsight or None on failure.
        """
        prompt = self.ANALYSIS_PROMPT.format(
            context=context[:4000],  # Limit context to ~1000 tokens
            segment=segment,
            reason=screening_reason,
            language=language,
        )

        try:
            result = await self._provider.invoke_analysis(prompt)
            content = str(result.get("content", "")).strip()

            # Try direct parse first, then extract JSON from wrapper text
            try:
                parsed = json.loads(content)
            except json.JSONDecodeError:
                json_str = content
                fence_match = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", content, re.DOTALL)
                if fence_match:
                    json_str = fence_match.group(1)
                else:
                    brace_match = re.search(r"\{.*\}", content, re.DOTALL)
                    if brace_match:
                        json_str = brace_match.group(0)
                parsed = json.loads(json_str)

            insight = AnalysisInsight(
                title=str(parsed.get("title", "Untitled Insight")),
                analysis=str(parsed.get("analysis", "")),
                recommendation=str(parsed.get("recommendation", "")),
                category=str(parsed.get("category", "idea")),
                input_tokens=result.get("input_tokens", 0),
                output_tokens=result.get("output_tokens", 0),
            )

            logger.info(
                "analysis_complete",
                title=insight.title,
                category=insight.category,
                latency_ms=result.get("latency_ms"),
            )

            return insight

        except json.JSONDecodeError:
            logger.warning(
                "analysis_json_parse_error",
                raw_content=str(result.get("content", ""))[:200],
            )
            return None
        except Exception as e:
            logger.error("analysis_error", error=str(e))
            return None
