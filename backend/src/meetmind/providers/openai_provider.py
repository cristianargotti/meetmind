"""OpenAI LLM provider — Hexagonal Architecture adapter.

Implements the LLMProvider protocol using the OpenAI Chat Completions API.
Uses the same tiered model strategy as Bedrock:
  - gpt-4o-mini: Screening (cheapest)
  - gpt-4o: Analysis, Copilot, Summary
  - gpt-4o: Deep Think (same, but allows future upgrade to o1/o3)
"""

import time
from typing import Any

import structlog
from openai import AsyncOpenAI

from meetmind.config.settings import settings

logger = structlog.get_logger(__name__)


class OpenAIProvider:
    """OpenAI LLM provider with cost tracking."""

    def __init__(self) -> None:
        """Initialize OpenAI async client."""
        if not settings.openai_api_key:
            raise ValueError("MEETMIND_OPENAI_API_KEY is required when llm_provider=openai")
        self._client = AsyncOpenAI(api_key=settings.openai_api_key)
        self._total_input_tokens: int = 0
        self._total_output_tokens: int = 0
        self._total_requests: int = 0

    async def invoke(
        self,
        model_id: str,
        prompt: str,
        *,
        max_tokens: int = 4096,
        temperature: float = 0.3,
        system_prompt: str = "",
    ) -> dict[str, Any]:
        """Invoke an OpenAI model with the Chat Completions API.

        Args:
            model_id: OpenAI model identifier (e.g. 'gpt-4o').
            prompt: User message content.
            max_tokens: Maximum tokens in response.
            temperature: Sampling temperature.
            system_prompt: System instruction.

        Returns:
            Dict with 'content', 'input_tokens', 'output_tokens', 'latency_ms'.
        """
        start_time = time.monotonic()

        messages: list[dict[str, str]] = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        messages.append({"role": "user", "content": prompt})

        response = await self._client.chat.completions.create(
            model=model_id,
            messages=messages,  # type: ignore[arg-type]
            max_completion_tokens=max_tokens,
            temperature=temperature,
        )

        latency_ms = (time.monotonic() - start_time) * 1000

        content = ""
        if response.choices:
            content = response.choices[0].message.content or ""

        input_tokens = 0
        output_tokens = 0
        if response.usage:
            input_tokens = response.usage.prompt_tokens
            output_tokens = response.usage.completion_tokens

        self._total_input_tokens += input_tokens
        self._total_output_tokens += output_tokens
        self._total_requests += 1

        logger.info(
            "openai_invoke",
            model_id=model_id,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            latency_ms=round(latency_ms, 1),
            total_requests=self._total_requests,
        )

        return {
            "content": content,
            "input_tokens": input_tokens,
            "output_tokens": output_tokens,
            "latency_ms": round(latency_ms, 1),
            "model_id": model_id,
        }

    async def invoke_screening(self, prompt: str) -> dict[str, Any]:
        """Invoke gpt-4o-mini for fast screening."""
        return await self.invoke(
            model_id=settings.openai_screening_model,
            prompt=prompt,
            max_tokens=256,
            temperature=0.1,
            system_prompt=(
                "You are a relevance screener for a meeting AI assistant. "
                "Analyze the transcript segment and determine if it contains "
                "actionable information (decisions, tasks, risks, ideas). "
                'Respond with JSON: {"relevant": true/false, "reason": "..."}'
            ),
        )

    async def invoke_analysis(self, prompt: str) -> dict[str, Any]:
        """Invoke gpt-4o for analysis — generate insights."""
        return await self.invoke(
            model_id=settings.openai_analysis_model,
            prompt=prompt,
            max_tokens=2048,
            temperature=0.3,
            system_prompt=(
                "You are an AI meeting analyst. Analyze the transcript and provide: "
                "1) Key decisions made, 2) Action items with owners, "
                "3) Risks identified, 4) Ideas worth exploring. "
                "Be concise and structured. Use JSON format."
            ),
        )

    async def invoke_deep(self, prompt: str) -> dict[str, Any]:
        """Invoke gpt-4o for deep thinking."""
        return await self.invoke(
            model_id=settings.openai_deep_model,
            prompt=prompt,
            max_tokens=4096,
            temperature=0.4,
            system_prompt=(
                "You are Digital Cris, an expert AI SRE assistant participating "
                "in meetings. Provide deep, thoughtful analysis with your unique "
                "perspective. Be direct, actionable, and reference specific details "
                "from the conversation."
            ),
        )

    async def invoke_copilot(self, prompt: str) -> dict[str, Any]:
        """Invoke gpt-4o for copilot — conversational meeting assistant."""
        from meetmind.agents.copilot_agent import CRIS_PERSONA

        return await self.invoke(
            model_id=settings.openai_copilot_model,
            prompt=prompt,
            max_tokens=1024,
            temperature=0.5,
            system_prompt=CRIS_PERSONA,
        )

    async def invoke_summary(self, prompt: str) -> dict[str, Any]:
        """Invoke gpt-4o for post-meeting summary."""
        from meetmind.agents.summary_agent import SUMMARY_SYSTEM_PROMPT

        return await self.invoke(
            model_id=settings.openai_analysis_model,
            prompt=prompt,
            max_tokens=2048,
            temperature=0.3,
            system_prompt=SUMMARY_SYSTEM_PROMPT,
        )

    @property
    def usage_stats(self) -> dict[str, int]:
        """Return cumulative token usage and request count."""
        return {
            "total_input_tokens": self._total_input_tokens,
            "total_output_tokens": self._total_output_tokens,
            "total_requests": self._total_requests,
        }
