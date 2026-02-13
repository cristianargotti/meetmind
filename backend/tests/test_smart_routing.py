"""Tests for Smart Copilot Routing — query complexity classification."""

from __future__ import annotations

from meetmind.agents.copilot_agent import classify_query_complexity


class TestClassifyQueryComplexity:
    """Tests for the query complexity classifier."""

    # Simple queries (→ Haiku)

    def test_short_question(self) -> None:
        """Short questions default to simple."""
        assert classify_query_complexity("who said that?") == "simple"

    def test_who_said(self) -> None:
        """'Who said X' is a simple lookup."""
        assert classify_query_complexity("Who said we need more pods?") == "simple"

    def test_when_did(self) -> None:
        """'When did X' is a simple lookup."""
        assert classify_query_complexity("When did they mention the deadline?") == "simple"

    def test_how_many(self) -> None:
        """'How many X' is a simple lookup."""
        assert classify_query_complexity("How many action items were mentioned?") == "simple"

    def test_spanish_simple(self) -> None:
        """Spanish simple query classification."""
        assert classify_query_complexity("¿Quién dijo que migremos la base?") == "simple"

    def test_repeat_command(self) -> None:
        """'Repeat' is a simple command."""
        assert classify_query_complexity("Repeat the last point") == "simple"

    # Complex queries (→ Sonnet)

    def test_why_question(self) -> None:
        """'Why' questions require analysis."""
        assert classify_query_complexity("Why did they choose Kubernetes over ECS?") == "complex"

    def test_explain_request(self) -> None:
        """'Explain' needs deep response."""
        assert classify_query_complexity("Explain the impact of this migration") == "complex"

    def test_risk_analysis(self) -> None:
        """Risk analysis is complex."""
        assert classify_query_complexity("What is the risk of this approach?") == "complex"

    def test_compare_request(self) -> None:
        """Comparison requires reasoning."""
        query = "Compare PostgreSQL vs DynamoDB for this use case"
        assert classify_query_complexity(query) == "complex"

    def test_summarize(self) -> None:
        """Summarization is complex."""
        query = "Summarize the discussion about the architecture"
        assert classify_query_complexity(query) == "complex"

    def test_spanish_complex(self) -> None:
        """Spanish complex query classification."""
        assert classify_query_complexity("¿Por qué decidieron usar ese approach?") == "complex"

    def test_strategy_question(self) -> None:
        """Strategy questions are complex."""
        query = "What strategy should we use for the rollout?"
        assert classify_query_complexity(query) == "complex"

    # Edge cases

    def test_ambiguous_defaults_to_complex(self) -> None:
        """Ambiguous queries default to complex for safety."""
        query = "What about the database situation we discussed earlier?"
        assert classify_query_complexity(query) == "complex"

    def test_very_short_query(self) -> None:
        """Very short query is simple."""
        assert classify_query_complexity("what?") == "simple"
