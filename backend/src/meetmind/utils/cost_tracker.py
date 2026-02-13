"""Cost Tracker — per-connection token usage and USD cost tracking.

Tracks token consumption with model-level granularity, calculates
estimated USD cost using Bedrock pricing, and enforces configurable
session budget limits.
"""

from __future__ import annotations

import time
from dataclasses import dataclass
from typing import Any

import structlog

logger = structlog.get_logger(__name__)


class BudgetExceededError(Exception):
    """Raised when session budget limit is reached."""


# Bedrock pricing per 1M tokens (USD) — Jan 2025
BEDROCK_PRICING: dict[str, dict[str, float]] = {
    "haiku": {"input": 0.25, "output": 1.25},
    "sonnet": {"input": 3.00, "output": 15.00},
    "opus": {"input": 15.00, "output": 75.00},
}


def _classify_model(model_id: str) -> str:
    """Classify a Bedrock model ID into a pricing tier.

    Args:
        model_id: Full Bedrock model identifier.

    Returns:
        One of: 'haiku', 'sonnet', 'opus'.
    """
    model_lower = model_id.lower()
    if "haiku" in model_lower:
        return "haiku"
    if "opus" in model_lower:
        return "opus"
    return "sonnet"


@dataclass
class ModelUsage:
    """Token usage for a specific model tier."""

    tier: str
    input_tokens: int = 0
    output_tokens: int = 0
    requests: int = 0

    @property
    def cost_usd(self) -> float:
        """Calculate USD cost for this model tier."""
        pricing = BEDROCK_PRICING.get(self.tier, BEDROCK_PRICING["sonnet"])
        input_cost = (self.input_tokens / 1_000_000) * pricing["input"]
        output_cost = (self.output_tokens / 1_000_000) * pricing["output"]
        return round(input_cost + output_cost, 6)


class CostTracker:
    """Per-connection cost tracker with budget enforcement.

    Tracks token usage across model tiers and calculates real-time
    USD cost estimates. Sends budget warnings when approaching limits.
    """

    def __init__(self, budget_usd: float = 1.00) -> None:
        """Initialize cost tracker.

        Args:
            budget_usd: Maximum USD budget for this session.
        """
        self._budget_usd = budget_usd
        self._usage: dict[str, ModelUsage] = {}
        self._start_time = time.monotonic()
        self._total_requests = 0
        self._compression_savings = 0  # tokens saved by compressor

    def record(
        self,
        model_id: str,
        input_tokens: int,
        output_tokens: int,
    ) -> None:
        """Record token usage from an LLM call.

        Args:
            model_id: Bedrock model identifier.
            input_tokens: Number of input tokens consumed.
            output_tokens: Number of output tokens generated.

        Raises:
            BudgetExceededError: If session budget would be exceeded.
        """
        tier = _classify_model(model_id)

        if tier not in self._usage:
            self._usage[tier] = ModelUsage(tier=tier)

        usage = self._usage[tier]
        usage.input_tokens += input_tokens
        usage.output_tokens += output_tokens
        usage.requests += 1
        self._total_requests += 1

        total_cost = self.total_cost_usd

        logger.info(
            "cost_recorded",
            tier=tier,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            total_cost_usd=total_cost,
            budget_usd=self._budget_usd,
            budget_pct=round((total_cost / self._budget_usd) * 100, 1),
        )

        if total_cost >= self._budget_usd:
            raise BudgetExceededError(
                f"Session budget ${self._budget_usd:.2f} exceeded (current: ${total_cost:.4f})"
            )

    def record_compression_savings(self, tokens_saved: int) -> None:
        """Record tokens saved by the compressor.

        Args:
            tokens_saved: Number of tokens eliminated by compression.
        """
        self._compression_savings += tokens_saved

    @property
    def total_cost_usd(self) -> float:
        """Calculate total USD cost across all model tiers."""
        return round(
            sum(u.cost_usd for u in self._usage.values()),
            6,
        )

    @property
    def total_input_tokens(self) -> int:
        """Total input tokens across all tiers."""
        return sum(u.input_tokens for u in self._usage.values())

    @property
    def total_output_tokens(self) -> int:
        """Total output tokens across all tiers."""
        return sum(u.output_tokens for u in self._usage.values())

    @property
    def budget_remaining_usd(self) -> float:
        """Remaining budget in USD."""
        return max(0.0, self._budget_usd - self.total_cost_usd)

    @property
    def budget_pct(self) -> float:
        """Percentage of budget consumed (0-100+)."""
        if self._budget_usd <= 0:
            return 100.0
        return round((self.total_cost_usd / self._budget_usd) * 100, 1)

    @property
    def session_duration_seconds(self) -> float:
        """Session duration in seconds."""
        return round(time.monotonic() - self._start_time, 1)

    def to_dict(self) -> dict[str, Any]:
        """Convert to dictionary for WebSocket broadcasting.

        Returns:
            Cost stats dictionary suitable for JSON serialization.
        """
        return {
            "total_cost_usd": self.total_cost_usd,
            "budget_usd": self._budget_usd,
            "budget_remaining_usd": self.budget_remaining_usd,
            "budget_pct": self.budget_pct,
            "total_input_tokens": self.total_input_tokens,
            "total_output_tokens": self.total_output_tokens,
            "total_requests": self._total_requests,
            "compression_savings": self._compression_savings,
            "session_duration_s": self.session_duration_seconds,
            "by_tier": {
                tier: {
                    "input_tokens": u.input_tokens,
                    "output_tokens": u.output_tokens,
                    "requests": u.requests,
                    "cost_usd": u.cost_usd,
                }
                for tier, u in self._usage.items()
            },
        }
