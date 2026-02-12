"""AWS Bedrock LLM provider — Hexagonal Architecture adapter.

Implements the LLMProvider protocol using AWS Bedrock with the
tiered model strategy:
  - Haiku 3.5: Screening ($0.05/hr)
  - Sonnet 4.5: Analysis ($0.50/hr)
  - Opus 4: Deep Think ($1.00/hr)
"""

import json
import time
from typing import Any

import boto3
import structlog

from meetmind.config.settings import settings

logger = structlog.get_logger(__name__)


class BedrockProvider:
    """AWS Bedrock LLM provider with cost tracking."""

    def __init__(self) -> None:
        """Initialize Bedrock client with AWS profile."""
        session = boto3.Session(
            profile_name=settings.aws_profile or None,
            region_name=settings.aws_region or None,
        )
        self._client = session.client("bedrock-runtime")
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
        """Invoke a Bedrock model with the Messages API.

        Args:
            model_id: Bedrock model identifier.
            prompt: User message content.
            max_tokens: Maximum tokens in response.
            temperature: Sampling temperature.
            system_prompt: System instruction.

        Returns:
            Dict with 'content', 'input_tokens', 'output_tokens', 'latency_ms'.
        """
        start_time = time.monotonic()

        messages = [{"role": "user", "content": prompt}]

        body: dict[str, Any] = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": max_tokens,
            "temperature": temperature,
            "messages": messages,
        }

        if system_prompt:
            body["system"] = system_prompt

        response = self._client.invoke_model(
            modelId=model_id,
            contentType="application/json",
            accept="application/json",
            body=json.dumps(body),
        )

        result = json.loads(response["body"].read())
        latency_ms = (time.monotonic() - start_time) * 1000

        input_tokens = result.get("usage", {}).get("input_tokens", 0)
        output_tokens = result.get("usage", {}).get("output_tokens", 0)

        self._total_input_tokens += input_tokens
        self._total_output_tokens += output_tokens
        self._total_requests += 1

        logger.info(
            "bedrock_invoke",
            model_id=model_id,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            latency_ms=round(latency_ms, 1),
            total_requests=self._total_requests,
        )

        content = ""
        if result.get("content"):
            content = result["content"][0].get("text", "")

        return {
            "content": content,
            "input_tokens": input_tokens,
            "output_tokens": output_tokens,
            "latency_ms": round(latency_ms, 1),
            "model_id": model_id,
        }

    async def invoke_screening(self, prompt: str) -> dict[str, Any]:
        """Invoke Haiku for fast screening — 'is this relevant?'

        Args:
            prompt: Text to screen for relevance.

        Returns:
            Bedrock response dict.
        """
        return await self.invoke(
            model_id=settings.bedrock_screening_model,
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
        """Invoke Sonnet for analysis — generate insights.

        Args:
            prompt: Relevant transcript to analyze.

        Returns:
            Bedrock response dict.
        """
        return await self.invoke(
            model_id=settings.bedrock_analysis_model,
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
        """Invoke Opus for deep thinking — complex queries and summaries.

        Args:
            prompt: Complex query or full meeting context.

        Returns:
            Bedrock response dict.
        """
        return await self.invoke(
            model_id=settings.bedrock_deep_model,
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

    @property
    def usage_stats(self) -> dict[str, int]:
        """Return cumulative token usage and request count."""
        return {
            "total_input_tokens": self._total_input_tokens,
            "total_output_tokens": self._total_output_tokens,
            "total_requests": self._total_requests,
        }
