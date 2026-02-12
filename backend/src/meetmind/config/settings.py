"""MeetMind configuration settings."""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application configuration loaded from environment variables."""

    # Environment
    environment: str = "dev"
    debug: bool = False

    # AWS
    aws_profile: str = "mibaggy-co"
    aws_region: str = "us-east-1"

    # Bedrock Models
    bedrock_screening_model: str = "anthropic.claude-3-5-haiku-20241022-v1:0"
    bedrock_analysis_model: str = "anthropic.claude-sonnet-4-5-20250514-v1:0"
    bedrock_deep_model: str = "anthropic.claude-opus-4-0-20250514-v1:0"

    # Deepgram (cloud STT fallback)
    deepgram_api_key: str = ""

    # Server
    host: str = "0.0.0.0"
    port: int = 8000

    # Logging
    log_level: str = "INFO"

    model_config = {"env_prefix": "MEETMIND_", "env_file": ".env"}


settings = Settings()
