"""Screening agent — Haiku 3.5 for fast relevance filtering.

Uses the cheapest model to answer: "Is this transcript segment
worth analyzing?" Runs every 30 seconds on buffered text.
"""

import json
import re

import structlog

from meetmind.providers.bedrock import BedrockProvider

logger = structlog.get_logger(__name__)


class ScreeningResult:
    """Result of a screening invocation."""

    def __init__(
        self,
        relevant: bool,
        reason: str,
        text_length: int,
        input_tokens: int = 0,
        output_tokens: int = 0,
    ) -> None:
        """Initialize a screening result.

        Args:
            relevant: Whether the segment is relevant.
            reason: Why the segment is/isn't relevant.
            text_length: Length of the screened text.
            input_tokens: Number of input tokens used.
            output_tokens: Number of output tokens used.
        """
        self.relevant = relevant
        self.reason = reason
        self.text_length = text_length
        self.input_tokens = input_tokens
        self.output_tokens = output_tokens

    def to_dict(self) -> dict[str, object]:
        """Convert to dictionary for WebSocket transmission."""
        return {
            "relevant": self.relevant,
            "reason": self.reason,
            "text_length": self.text_length,
        }


class ScreeningAgent:
    """AI screening agent — filters transcript for relevance.

    Uses Claude Haiku 3.5 via Bedrock to quickly determine if
    a transcript segment contains actionable content.
    """

    def __init__(self, provider: BedrockProvider) -> None:
        """Initialize with a Bedrock provider.

        Args:
            provider: Bedrock LLM provider instance.
        """
        self._provider = provider

    async def screen(self, text: str) -> ScreeningResult:
        """Screen a transcript segment for relevance.

        Args:
            text: Transcript text to screen.

        Returns:
            ScreeningResult with relevance determination.
        """
        if not text.strip():
            return ScreeningResult(relevant=False, reason="Empty text", text_length=0)

        try:
            result = await self._provider.invoke_screening(text)
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
            relevant = bool(parsed.get("relevant", False))
            reason = str(parsed.get("reason", "No reason provided"))

            logger.info(
                "screening_complete",
                relevant=relevant,
                reason=reason,
                text_length=len(text),
                latency_ms=result.get("latency_ms"),
            )

            return ScreeningResult(
                relevant=relevant,
                reason=reason,
                text_length=len(text),
                input_tokens=result.get("input_tokens", 0),
                output_tokens=result.get("output_tokens", 0),
            )

        except json.JSONDecodeError:
            logger.warning(
                "screening_json_parse_error",
                text_length=len(text),
                raw_content=str(result.get("content", ""))[:200],
            )
            # Default to relevant on parse failure — better safe than sorry
            return ScreeningResult(
                relevant=True,
                reason="Failed to parse screening response",
                text_length=len(text),
            )
        except Exception as e:
            logger.error(
                "screening_error",
                error=str(e),
                text_length=len(text),
            )
            return ScreeningResult(
                relevant=False,
                reason=f"Screening error: {e!s}",
                text_length=len(text),
            )
