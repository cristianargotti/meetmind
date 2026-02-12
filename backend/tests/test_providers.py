"""Tests for MeetMind provider protocol interfaces."""

from meetmind.providers.base import LLMProvider, STTProvider


def test_stt_provider_is_protocol() -> None:
    """STTProvider is a properly defined Protocol."""
    # Assert — should have required methods
    assert hasattr(STTProvider, "transcribe")
    assert hasattr(STTProvider, "is_available")


def test_llm_provider_is_protocol() -> None:
    """LLMProvider is a properly defined Protocol."""
    # Assert — should have required methods
    assert hasattr(LLMProvider, "invoke")
    assert hasattr(LLMProvider, "invoke_streaming")
