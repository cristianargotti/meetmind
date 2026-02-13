"""Tests for CostTracker — pricing, budget enforcement, metrics."""

from __future__ import annotations

import pytest

from meetmind.utils.cost_tracker import (
    BudgetExceededError,
    CostTracker,
    ModelUsage,
    _classify_model,
)


class TestClassifyModel:
    """Tests for model tier classification."""

    def test_haiku(self) -> None:
        """Haiku model IDs are classified correctly."""
        assert _classify_model("us.anthropic.claude-3-5-haiku-20241022-v1:0") == "haiku"

    def test_sonnet(self) -> None:
        """Sonnet model IDs are classified correctly."""
        assert _classify_model("us.anthropic.claude-sonnet-4-5-20250929-v1:0") == "sonnet"

    def test_opus(self) -> None:
        """Opus model IDs are classified correctly."""
        assert _classify_model("us.anthropic.claude-opus-4-20250514-v1:0") == "opus"

    def test_unknown_defaults_to_sonnet(self) -> None:
        """Unknown model IDs default to sonnet tier."""
        assert _classify_model("some-unknown-model") == "sonnet"


class TestModelUsage:
    """Tests for ModelUsage cost calculation."""

    def test_haiku_cost(self) -> None:
        """Haiku cost calculation is correct."""
        usage = ModelUsage(tier="haiku", input_tokens=1_000_000, output_tokens=0)
        assert usage.cost_usd == pytest.approx(0.25, abs=0.01)

    def test_sonnet_cost(self) -> None:
        """Sonnet cost with both input and output."""
        usage = ModelUsage(
            tier="sonnet",
            input_tokens=1_000_000,
            output_tokens=100_000,
        )
        expected = 3.00 + (0.1 * 15.00)  # $3 input + $1.5 output
        assert usage.cost_usd == pytest.approx(expected, abs=0.01)

    def test_zero_tokens(self) -> None:
        """Zero tokens means zero cost."""
        usage = ModelUsage(tier="haiku")
        assert usage.cost_usd == 0.0


class TestCostTracker:
    """Tests for CostTracker tracking and budget enforcement."""

    def test_record_increments_totals(self) -> None:
        """Recording usage increments token totals."""
        tracker = CostTracker(budget_usd=10.0)
        tracker.record("haiku-model", input_tokens=100, output_tokens=50)

        assert tracker.total_input_tokens == 100
        assert tracker.total_output_tokens == 50
        assert tracker._total_requests == 1

    def test_multiple_records(self) -> None:
        """Multiple records accumulate correctly."""
        tracker = CostTracker(budget_usd=10.0)
        tracker.record("haiku-model", input_tokens=100, output_tokens=50)
        tracker.record("sonnet-model", input_tokens=200, output_tokens=100)

        assert tracker.total_input_tokens == 300
        assert tracker.total_output_tokens == 150
        assert tracker._total_requests == 2

    def test_budget_exceeded_raises(self) -> None:
        """Exceeding budget raises BudgetExceededError."""
        tracker = CostTracker(budget_usd=0.001)
        with pytest.raises(BudgetExceededError):
            tracker.record(
                "opus-model",
                input_tokens=1_000_000,
                output_tokens=100_000,
            )

    def test_budget_within_limit(self) -> None:
        """Small usage stays within budget."""
        tracker = CostTracker(budget_usd=10.0)
        # This should not raise
        tracker.record("haiku-model", input_tokens=1000, output_tokens=500)
        assert tracker.budget_pct < 1.0

    def test_budget_remaining(self) -> None:
        """Budget remaining decreases after usage."""
        tracker = CostTracker(budget_usd=1.0)
        initial = tracker.budget_remaining_usd
        tracker.record("haiku-model", input_tokens=1000, output_tokens=0)
        assert tracker.budget_remaining_usd <= initial

    def test_compression_savings(self) -> None:
        """Compression savings are tracked."""
        tracker = CostTracker()
        tracker.record_compression_savings(500)
        tracker.record_compression_savings(300)
        assert tracker._compression_savings == 800

    def test_to_dict(self) -> None:
        """to_dict includes all required fields."""
        tracker = CostTracker(budget_usd=5.0)
        tracker.record("haiku-model", input_tokens=100, output_tokens=50)
        d = tracker.to_dict()

        assert "total_cost_usd" in d
        assert "budget_usd" in d
        assert d["budget_usd"] == 5.0
        assert "budget_remaining_usd" in d
        assert "budget_pct" in d
        assert "total_requests" in d
        assert d["total_requests"] == 1
        assert "by_tier" in d
        assert "haiku" in d["by_tier"]

    def test_session_duration(self) -> None:
        """Session duration is positive."""
        tracker = CostTracker()
        assert tracker.session_duration_seconds >= 0.0
