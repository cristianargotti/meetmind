"""Tests for MeetMind configuration settings."""

import os

from meetmind.config.settings import Settings


def test_settings_defaults() -> None:
    """Settings have correct defaults for non-sensitive fields."""
    # Arrange & Act
    settings = Settings()

    # Assert
    assert settings.environment == "dev"
    assert settings.debug is False
    assert settings.port == 8000
    assert settings.log_level == "INFO"


def test_settings_aws_no_hardcoded_defaults() -> None:
    """AWS credentials must come from environment, not hardcoded defaults."""
    # Arrange & Act
    settings = Settings()

    # Assert — SEC-005: no hardcoded AWS defaults
    assert settings.aws_profile == ""
    assert settings.aws_region == ""


def test_settings_from_env(monkeypatch: object) -> None:
    """Settings load from environment variables with MEETMIND_ prefix."""
    # Arrange
    import pytest

    mp = pytest.MonkeyPatch()
    mp.setenv("MEETMIND_ENVIRONMENT", "production")
    mp.setenv("MEETMIND_AWS_PROFILE", "mibaggy-co")
    mp.setenv("MEETMIND_AWS_REGION", "us-east-1")

    # Act
    settings = Settings()

    # Assert
    assert settings.environment == "production"
    assert settings.aws_profile == "mibaggy-co"
    assert settings.aws_region == "us-east-1"

    # Cleanup
    mp.undo()


def test_bedrock_model_ids() -> None:
    """Bedrock model IDs follow the correct format."""
    # Arrange & Act
    settings = Settings()

    # Assert
    assert "haiku" in settings.bedrock_screening_model
    assert "sonnet" in settings.bedrock_analysis_model
    assert "opus" in settings.bedrock_deep_model
