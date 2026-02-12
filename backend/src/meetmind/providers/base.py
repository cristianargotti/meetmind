"""Provider protocol interfaces — Hexagonal Architecture adapters."""

from typing import Protocol


class STTProvider(Protocol):
    """Speech-to-Text provider interface."""

    async def transcribe(self, audio_chunk: bytes) -> str:
        """Transcribe an audio chunk to text."""
        ...

    async def is_available(self) -> bool:
        """Check if the provider is available."""
        ...


class LLMProvider(Protocol):
    """LLM provider interface for AI agents."""

    async def invoke(
        self,
        model_id: str,
        prompt: str,
        *,
        max_tokens: int = 4096,
        temperature: float = 0.3,
    ) -> str:
        """Invoke an LLM model with a prompt."""
        ...

    async def invoke_streaming(
        self,
        model_id: str,
        prompt: str,
        *,
        max_tokens: int = 4096,
        temperature: float = 0.3,
    ) -> str:
        """Invoke an LLM model with streaming response."""
        ...
