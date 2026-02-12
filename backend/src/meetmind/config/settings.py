"""MeetMind configuration settings."""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application configuration loaded from environment variables."""

    # Environment
    environment: str = "dev"
    debug: bool = False

    # AWS (loaded from .env — never hardcoded)
    aws_profile: str = ""
    aws_region: str = ""

    # Bedrock Models (cross-region inference profiles)
    bedrock_screening_model: str = "us.anthropic.claude-3-5-haiku-20241022-v1:0"
    bedrock_analysis_model: str = "us.anthropic.claude-sonnet-4-5-20250929-v1:0"
    bedrock_deep_model: str = "us.anthropic.claude-opus-4-20250514-v1:0"

    # Deepgram (cloud STT fallback)
    deepgram_api_key: str = ""

    # Screening
    screening_interval_seconds: int = 5

    # Server
    host: str = "0.0.0.0"
    port: int = 8000

    # Logging
    log_level: str = "INFO"

    model_config = {"env_prefix": "MEETMIND_", "env_file": ".env"}


settings = Settings()
