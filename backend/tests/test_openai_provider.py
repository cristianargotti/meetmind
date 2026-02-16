"""Tests for OpenAIProvider — mocked API calls."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from meetmind.providers.openai_provider import OpenAIProvider


@pytest.fixture
def mock_openai_response() -> MagicMock:
    """Create a mock OpenAI ChatCompletion response."""
    usage = MagicMock()
    usage.prompt_tokens = 15
    usage.completion_tokens = 25

    message = MagicMock()
    message.content = "Test OpenAI response"

    choice = MagicMock()
    choice.message = message

    response = MagicMock()
    response.choices = [choice]
    response.usage = usage
    return response


@patch("meetmind.providers.openai_provider.settings")
def test_openai_provider_init_requires_api_key(mock_settings: MagicMock) -> None:
    """OpenAIProvider raises ValueError when API key is empty."""
    mock_settings.openai_api_key = ""

    with pytest.raises(ValueError, match="MEETMIND_OPENAI_API_KEY"):
        OpenAIProvider()


@patch("meetmind.providers.openai_provider.AsyncOpenAI")
@patch("meetmind.providers.openai_provider.settings")
def test_openai_provider_init_with_key(
    mock_settings: MagicMock, mock_client_cls: MagicMock
) -> None:
    """OpenAIProvider initializes with API key."""
    mock_settings.openai_api_key = "sk-test-key"

    provider = OpenAIProvider()

    mock_client_cls.assert_called_once()
    call_kwargs = mock_client_cls.call_args[1]
    assert call_kwargs["api_key"] == "sk-test-key"
    assert provider._total_requests == 0


@patch("meetmind.providers.openai_provider.AsyncOpenAI")
@patch("meetmind.providers.openai_provider.settings")
@pytest.mark.asyncio
async def test_invoke_returns_content(
    mock_settings: MagicMock,
    mock_client_cls: MagicMock,
    mock_openai_response: MagicMock,
) -> None:
    """Invoke returns parsed content and usage stats."""
    mock_settings.openai_api_key = "sk-test"

    mock_client = MagicMock()
    mock_client.chat.completions.create = AsyncMock(return_value=mock_openai_response)
    mock_client_cls.return_value = mock_client

    provider = OpenAIProvider()
    result = await provider.invoke(model_id="gpt-4o", prompt="Hello")

    assert result["content"] == "Test OpenAI response"
    assert result["input_tokens"] == 15
    assert result["output_tokens"] == 25
    assert result["model_id"] == "gpt-4o"
    assert "latency_ms" in result
    assert provider._total_requests == 1


@patch("meetmind.providers.openai_provider.AsyncOpenAI")
@patch("meetmind.providers.openai_provider.settings")
@pytest.mark.asyncio
async def test_invoke_with_system_prompt(
    mock_settings: MagicMock,
    mock_client_cls: MagicMock,
    mock_openai_response: MagicMock,
) -> None:
    """Invoke includes system prompt in messages when provided."""
    mock_settings.openai_api_key = "sk-test"

    mock_client = MagicMock()
    mock_client.chat.completions.create = AsyncMock(return_value=mock_openai_response)
    mock_client_cls.return_value = mock_client

    provider = OpenAIProvider()
    await provider.invoke(
        model_id="gpt-4o",
        prompt="Hello",
        system_prompt="You are a test bot.",
    )

    call_args = mock_client.chat.completions.create.call_args
    messages = call_args[1]["messages"]
    assert messages[0] == {"role": "system", "content": "You are a test bot."}
    assert messages[1] == {"role": "user", "content": "Hello"}


@patch("meetmind.providers.openai_provider.AsyncOpenAI")
@patch("meetmind.providers.openai_provider.settings")
@pytest.mark.asyncio
async def test_invoke_screening_uses_mini(
    mock_settings: MagicMock,
    mock_client_cls: MagicMock,
    mock_openai_response: MagicMock,
) -> None:
    """invoke_screening uses gpt-4o-mini with low temperature."""
    mock_settings.openai_api_key = "sk-test"
    mock_settings.openai_screening_model = "gpt-4o-mini"

    mock_client = MagicMock()
    mock_client.chat.completions.create = AsyncMock(return_value=mock_openai_response)
    mock_client_cls.return_value = mock_client

    provider = OpenAIProvider()
    await provider.invoke_screening("test transcript")

    call_args = mock_client.chat.completions.create.call_args
    assert call_args[1]["model"] == "gpt-4o-mini"
    assert call_args[1]["temperature"] == 0.1
    assert call_args[1]["max_completion_tokens"] == 256


@patch("meetmind.providers.openai_provider.AsyncOpenAI")
@patch("meetmind.providers.openai_provider.settings")
def test_usage_stats(mock_settings: MagicMock, mock_client_cls: MagicMock) -> None:
    """usage_stats returns cumulative token counts."""
    mock_settings.openai_api_key = "sk-test"

    provider = OpenAIProvider()

    stats = provider.usage_stats
    assert stats["total_input_tokens"] == 0
    assert stats["total_output_tokens"] == 0
    assert stats["total_requests"] == 0
