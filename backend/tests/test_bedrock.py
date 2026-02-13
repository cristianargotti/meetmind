"""Tests for BedrockProvider — mocked AWS calls."""

from unittest.mock import MagicMock, patch

import pytest

from meetmind.providers.bedrock import BedrockProvider


@pytest.fixture
def mock_bedrock_client() -> MagicMock:
    """Create a mock Bedrock runtime client."""
    import json

    mock_response_body = MagicMock()
    mock_response_body.read.return_value = json.dumps(
        {
            "content": [{"text": "Test response"}],
            "usage": {"input_tokens": 10, "output_tokens": 20},
        }
    ).encode()

    mock_client = MagicMock()
    mock_client.invoke_model.return_value = {"body": mock_response_body}
    return mock_client


@patch("meetmind.providers.bedrock.boto3.Session")
def test_bedrock_provider_init(mock_session: MagicMock) -> None:
    """BedrockProvider initializes with boto3 session."""
    # Arrange & Act
    provider = BedrockProvider()

    # Assert
    mock_session.assert_called_once()
    assert provider._total_requests == 0


@patch("meetmind.providers.bedrock.boto3.Session")
@pytest.mark.asyncio
async def test_invoke_returns_content(
    mock_session: MagicMock, mock_bedrock_client: MagicMock
) -> None:
    """Invoke returns parsed content and usage stats."""
    # Arrange
    mock_session.return_value.client.return_value = mock_bedrock_client
    provider = BedrockProvider()

    # Act
    result = await provider.invoke(
        model_id="anthropic.claude-3-5-haiku-20241022-v1:0",
        prompt="Hello",
    )

    # Assert
    assert result["content"] == "Test response"
    assert result["input_tokens"] == 10
    assert result["output_tokens"] == 20
    assert "latency_ms" in result
    assert provider._total_requests == 1


@patch("meetmind.providers.bedrock.boto3.Session")
@pytest.mark.asyncio
async def test_invoke_with_system_prompt(
    mock_session: MagicMock, mock_bedrock_client: MagicMock
) -> None:
    """Invoke includes system prompt in body when provided."""
    # Arrange
    import json

    mock_session.return_value.client.return_value = mock_bedrock_client
    provider = BedrockProvider()

    # Act
    await provider.invoke(
        model_id="test-model",
        prompt="Hello",
        system_prompt="You are a test bot.",
    )

    # Assert
    call_args = mock_bedrock_client.invoke_model.call_args
    body = json.loads(call_args[1]["body"])
    assert body["system"] == "You are a test bot."


@patch("meetmind.providers.bedrock.boto3.Session")
@pytest.mark.asyncio
async def test_invoke_screening(mock_session: MagicMock, mock_bedrock_client: MagicMock) -> None:
    """invoke_screening uses Haiku model with low temperature."""
    # Arrange
    import json

    mock_session.return_value.client.return_value = mock_bedrock_client
    provider = BedrockProvider()

    # Act
    await provider.invoke_screening("test transcript")

    # Assert
    call_args = mock_bedrock_client.invoke_model.call_args
    assert "haiku" in call_args[1]["modelId"]
    body = json.loads(call_args[1]["body"])
    assert body["temperature"] == 0.1
    assert body["max_tokens"] == 256


@patch("meetmind.providers.bedrock.boto3.Session")
def test_usage_stats(mock_session: MagicMock) -> None:
    """usage_stats returns cumulative token counts."""
    # Arrange
    provider = BedrockProvider()

    # Assert
    stats = provider.usage_stats
    assert stats["total_input_tokens"] == 0
    assert stats["total_output_tokens"] == 0
    assert stats["total_requests"] == 0
