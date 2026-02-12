"""Structured logging configuration for MeetMind.

Uses structlog for consistent, JSON-formatted logs following
MEETMIND_DEVELOPMENT_STANDARDS.md OBS-001.
"""

import logging

import structlog

from meetmind.config.settings import settings

LOG_LEVELS = {
    "DEBUG": logging.DEBUG,
    "INFO": logging.INFO,
    "WARNING": logging.WARNING,
    "ERROR": logging.ERROR,
    "CRITICAL": logging.CRITICAL,
}


def setup_logging() -> None:
    """Configure structlog with JSON output for production, console for dev."""
    log_level = LOG_LEVELS.get(settings.log_level.upper(), logging.INFO)

    processors: list[structlog.types.Processor] = [
        structlog.contextvars.merge_contextvars,
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.UnicodeDecoder(),
    ]

    if settings.environment == "dev":
        processors.append(structlog.dev.ConsoleRenderer())
    else:
        processors.append(structlog.processors.JSONRenderer())

    structlog.configure(
        processors=processors,
        wrapper_class=structlog.make_filtering_bound_logger(log_level),
        context_class=dict,
        logger_factory=structlog.PrintLoggerFactory(),
        cache_logger_on_first_use=True,
    )


def get_logger(name: str) -> structlog.stdlib.BoundLogger:
    """Get a structured logger with the given name.

    Args:
        name: Logger name (usually __name__).

    Returns:
        Configured structlog BoundLogger.
    """
    return structlog.get_logger(name)  # type: ignore[no-any-return]
