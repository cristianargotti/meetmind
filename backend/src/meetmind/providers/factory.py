"""LLM provider factory — selects the right provider from config."""

import structlog

from meetmind.config.settings import settings
from meetmind.providers.base import LLMProvider
from meetmind.providers.bedrock import BedrockProvider
from meetmind.providers.openai_provider import OpenAIProvider

logger = structlog.get_logger(__name__)


def create_llm_provider() -> LLMProvider:
    """Create the configured LLM provider.

    Reads ``settings.llm_provider`` to decide which backend to use:
      - ``"bedrock"`` → AWS Bedrock (default, production)
      - ``"openai"`` → OpenAI Chat Completions API

    Returns:
        An LLMProvider instance (BedrockProvider or OpenAIProvider).

    Raises:
        ValueError: If the provider name is not recognized.
    """
    provider_name = settings.llm_provider.lower().strip()

    if provider_name == "openai":
        logger.info("provider_selected", provider="openai")
        return OpenAIProvider()

    if provider_name == "bedrock":
        logger.info("provider_selected", provider="bedrock")
        return BedrockProvider()

    msg = f"Unknown LLM provider: '{provider_name}'. Use 'bedrock' or 'openai'."
    raise ValueError(msg)
