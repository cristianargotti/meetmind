"""Tests for provider factory — provider selection logic."""

from unittest.mock import MagicMock, patch

import pytest

from meetmind.providers.factory import create_llm_provider


@patch("meetmind.providers.factory.BedrockProvider")
@patch("meetmind.providers.factory.settings")
def test_factory_creates_bedrock_by_default(
    mock_settings: MagicMock, mock_bedrock_cls: MagicMock
) -> None:
    """Factory returns BedrockProvider when llm_provider is 'bedrock'."""
    mock_settings.llm_provider = "bedrock"

    provider = create_llm_provider()

    mock_bedrock_cls.assert_called_once()
    assert provider is mock_bedrock_cls.return_value


@patch("meetmind.providers.factory.OpenAIProvider")
@patch("meetmind.providers.factory.settings")
def test_factory_creates_openai(mock_settings: MagicMock, mock_openai_cls: MagicMock) -> None:
    """Factory returns OpenAIProvider when llm_provider is 'openai'."""
    mock_settings.llm_provider = "openai"

    provider = create_llm_provider()

    mock_openai_cls.assert_called_once()
    assert provider is mock_openai_cls.return_value


@patch("meetmind.providers.factory.settings")
def test_factory_raises_on_unknown_provider(mock_settings: MagicMock) -> None:
    """Factory raises ValueError for unknown provider names."""
    mock_settings.llm_provider = "gemini"

    with pytest.raises(ValueError, match="Unknown LLM provider"):
        create_llm_provider()


@patch("meetmind.providers.factory.BedrockProvider")
@patch("meetmind.providers.factory.settings")
def test_factory_strips_whitespace(mock_settings: MagicMock, mock_bedrock_cls: MagicMock) -> None:
    """Factory handles whitespace/case variations in provider name."""
    mock_settings.llm_provider = "  Bedrock  "

    provider = create_llm_provider()

    mock_bedrock_cls.assert_called_once()
    assert provider is mock_bedrock_cls.return_value
