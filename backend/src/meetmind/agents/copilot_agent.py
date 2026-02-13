"""Copilot Agent — Secret AI assistant for meetings.

The user silently asks questions during a meeting and the copilot
responds using the full transcript context. Nobody else knows it exists.

Supports smart routing: simple queries go to Haiku (12x cheaper),
complex queries go to Sonnet for high-quality analysis.
"""

from __future__ import annotations

import re
import time
from dataclasses import dataclass
from typing import TYPE_CHECKING

import structlog

if TYPE_CHECKING:
    from meetmind.providers.bedrock import BedrockProvider

logger = structlog.get_logger(__name__)

CRIS_PERSONA = """\
You are Digital Cris, the secret AI copilot of Cristian Reyes, SRE Senior.

## Your Role
You are a hidden assistant during meetings. The user asks you questions
silently while the meeting is happening. You have the full transcript of
everything said so far. Nobody else in the meeting knows you exist.

## Your Identity
- SRE Senior at Dafiti/Falabella with deep expertise in:
  - AWS (EKS, EC2, RDS, CloudWatch, Bedrock)
  - Kubernetes, Istio, ArgoCD, GitOps
  - Observability: Datadog APM, Graylog, Mimir/Prometheus
  - Python, Node.js, Docker, Terraform
  - AI/ML: LLMs, RAG, AI agents

## Your Style
- Direct and technical, but friendly
- Use emojis strategically 🔥
- When you see risk, say it clearly
- Always propose alternatives, never just criticize
- Speak in the same language the user writes (Spanish or English)
- Use technical terms in English even when writing in Spanish

## Rules
- Keep responses SHORT (2-5 lines max). The user is in a meeting.
- Be actionable: give the user something they can say RIGHT NOW
- If someone proposes something risky, point it out diplomatically
- Include concrete data when possible
- Never repeat what was already said in the transcript
- Format: use bullet points for multiple items, plain text for opinions
"""


@dataclass(frozen=True)
class CopilotResponse:
    """Response from the copilot agent."""

    answer: str
    latency_ms: float
    input_tokens: int
    output_tokens: int
    model_tier: str = "sonnet"


# Keywords that indicate a simple, factual query (→ Haiku)
_SIMPLE_PATTERNS: list[re.Pattern[str]] = [
    re.compile(r"\b(who said|when did|what time|how many|list|name)\b", re.I),
    re.compile(r"\b(quién dijo|cuándo|a qué hora|cuántos|nombr)\b", re.I),
    re.compile(r"\b(quem disse|quando|que horas|quantos)\b", re.I),
    re.compile(r"^(repeat|repite|repita)\b", re.I),
]

# Keywords that indicate a complex, analytical query (→ Sonnet)
_COMPLEX_PATTERNS: list[re.Pattern[str]] = [
    re.compile(r"\b(why|explain|analyze|impact|risk|strategy|compare)\b", re.I),
    re.compile(r"\b(por qué|explica|analiza|impacto|riesgo|estrategia)\b", re.I),
    re.compile(r"\b(por que|explique|analise|impacto|risco)\b", re.I),
    re.compile(r"\b(summarize|resum|suggest|recommend|pros.cons)\b", re.I),
]


def classify_query_complexity(question: str) -> str:
    """Classify a copilot query as simple or complex.

    Simple queries (factual lookups) → Haiku (12x cheaper).
    Complex queries (analysis/reasoning) → Sonnet.

    Args:
        question: The user's question.

    Returns:
        'simple' or 'complex'.
    """
    # Short questions are usually simple
    word_count = len(question.split())
    if word_count <= 4:
        return "simple"

    # Check for complex patterns first (higher priority)
    for pattern in _COMPLEX_PATTERNS:
        if pattern.search(question):
            return "complex"

    # Check for simple patterns
    for pattern in _SIMPLE_PATTERNS:
        if pattern.search(question):
            return "simple"

    # Default: complex (better quality for ambiguous queries)
    return "complex"


class CopilotAgent:
    """Secret meeting copilot — answers user questions with transcript context."""

    def __init__(self, provider: BedrockProvider) -> None:
        """Initialize copilot agent.

        Args:
            provider: Bedrock provider for LLM calls.
        """
        self._provider = provider

    async def respond(
        self,
        question: str,
        transcript_context: str,
    ) -> CopilotResponse:
        """Answer a user question using the meeting transcript context.

        Args:
            question: The user's question.
            transcript_context: Full transcript of the meeting so far.

        Returns:
            CopilotResponse with the answer and metrics.
        """
        # Build prompt with meeting context
        prompt = self._build_prompt(question, transcript_context)

        start = time.monotonic()

        try:
            # Always use copilot model (Sonnet) for user-facing answers
            result = await self._provider.invoke_copilot(prompt)
            model_tier = "sonnet"

            answer = str(result.get("content", "")).strip()
            latency_ms = result.get("latency_ms", 0.0)

            logger.info(
                "copilot_response",
                question_length=len(question),
                answer_length=len(answer),
                context_length=len(transcript_context),
                latency_ms=latency_ms,
                model_tier=model_tier,
            )

            return CopilotResponse(
                answer=answer,
                latency_ms=latency_ms,
                input_tokens=result.get("input_tokens", 0),
                output_tokens=result.get("output_tokens", 0),
                model_tier=model_tier,
            )

        except Exception as e:
            elapsed = (time.monotonic() - start) * 1000
            logger.error(
                "copilot_error",
                error=str(e),
                question_length=len(question),
            )
            return CopilotResponse(
                answer=f"⚠️ Error: {e!s}",
                latency_ms=elapsed,
                input_tokens=0,
                output_tokens=0,
            )

    def _build_prompt(self, question: str, transcript_context: str) -> str:
        """Build the full prompt with meeting context.

        Args:
            question: User's question.
            transcript_context: Full transcript so far.

        Returns:
            Formatted prompt string.
        """
        if transcript_context:
            return (
                f"## Meeting Transcript (so far)\n\n"
                f"{transcript_context}\n\n"
                f"---\n\n"
                f"## User's Question\n\n"
                f"{question}\n\n"
                f"Answer concisely (2-5 lines max). "
                f"The user is in the meeting right now."
            )
        return (
            f"The meeting just started and there's no transcript yet.\n\n"
            f"## User's Question\n\n"
            f"{question}\n\n"
            f"Answer concisely (2-5 lines max)."
        )
