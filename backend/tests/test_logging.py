"""Tests for structured logging configuration."""

import structlog

from meetmind.config.logging import get_logger, setup_logging


def test_setup_logging_configures_structlog() -> None:
    """setup_logging initializes structlog without errors."""
    # Act — should not raise
    setup_logging()

    # Assert — structlog is configured
    assert structlog.is_configured()


def test_get_logger_returns_bound_logger() -> None:
    """get_logger returns a usable structured logger."""
    # Arrange
    setup_logging()

    # Act
    log = get_logger("test_module")

    # Assert — logger has expected methods
    assert hasattr(log, "info")
    assert hasattr(log, "error")
    assert hasattr(log, "warning")
