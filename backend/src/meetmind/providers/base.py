"""Provider protocol interfaces — Hexagonal Architecture adapters."""

from typing import Any, Protocol


class STTProvider(Protocol):
    """Speech-to-Text provider interface."""

    async def transcribe(self, audio_chunk: bytes) -> str:
        """Transcribe an audio chunk to text."""
        ...

    async def is_available(self) -> bool:
        """Check if the provider is available."""
        ...


class LLMProvider(Protocol):
    """LLM provider interface for AI agents.

    Both BedrockProvider and OpenAIProvider implement this protocol.
    Agents depend on this protocol, not on concrete provider classes.
    """

    async def invoke(
        self,
        model_id: str,
        prompt: str,
        *,
        max_tokens: int = 4096,
        temperature: float = 0.3,
        system_prompt: str = "",
    ) -> dict[str, Any]:
        """Invoke an LLM model with a prompt."""
        ...

    async def invoke_screening(self, prompt: str) -> dict[str, Any]:
        """Invoke the screening model (cheapest — fast relevance check)."""
        ...

    async def invoke_analysis(self, prompt: str) -> dict[str, Any]:
        """Invoke the analysis model (mid-tier — insight generation)."""
        ...

    async def invoke_copilot(self, prompt: str) -> dict[str, Any]:
        """Invoke the copilot model (mid-tier — conversational assistant)."""
        ...

    async def invoke_summary(self, prompt: str) -> dict[str, Any]:
        """Invoke the summary model (mid-tier — structured JSON output)."""
        ...

    async def invoke_deep(self, prompt: str) -> dict[str, Any]:
        """Invoke the deep model (highest tier — complex reasoning)."""
        ...

    @property
    def usage_stats(self) -> dict[str, int]:
        """Return cumulative token usage and request count."""
        ...
