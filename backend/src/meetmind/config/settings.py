"""MeetMind configuration settings."""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application configuration loaded from environment variables."""

    # Environment
    environment: str = "dev"
    debug: bool = False

    # Database (PostgreSQL + pgvector)
    database_url: str = "postgresql://meetmind:meetmind@localhost:5432/meetmind"

    # AWS (loaded from .env — never hardcoded)
    aws_profile: str = ""
    aws_region: str = ""

    # Bedrock Models (cross-region inference profiles)
    bedrock_screening_model: str = "us.anthropic.claude-3-5-haiku-20241022-v1:0"
    bedrock_analysis_model: str = "us.anthropic.claude-sonnet-4-5-20250929-v1:0"
    bedrock_copilot_model: str = "us.anthropic.claude-sonnet-4-5-20250929-v1:0"
    bedrock_deep_model: str = "us.anthropic.claude-opus-4-20250514-v1:0"

    # LLM Provider selection ("bedrock" or "openai")
    llm_provider: str = "openai"

    # OpenAI-compatible API (default: Groq free tier)
    openai_api_key: str = ""  # Groq key from console.groq.com
    openai_base_url: str = "https://api.groq.com/openai/v1"
    openai_screening_model: str = "llama-3.1-8b-instant"
    openai_analysis_model: str = "llama-3.3-70b-versatile"
    openai_copilot_model: str = "llama-3.3-70b-versatile"
    openai_deep_model: str = "llama-3.3-70b-versatile"

    # Screening
    screening_interval_seconds: int = 5

    # Cost Optimization
    session_budget_usd: float = 1.00
    enable_transcript_compression: bool = True
    enable_response_cache: bool = True
    enable_smart_routing: bool = True

    # Auth (zero-cost: Google + Apple OAuth)
    jwt_secret_key: str = ""  # Auto-generated if empty; set in .env for production
    jwt_access_minutes: int = 10080  # 7 days — avoids 401s without app-side auto-refresh
    jwt_refresh_days: int = 30
    google_client_id: str = (
        "190972367615-4ft721hggursqog484ftlibtthkeeskm.apps.googleusercontent.com"
    )
    apple_team_id: str = ""
    apple_bundle_id: str = "com.meetmind.meetmind"
    apple_service_id: str = ""  # For web Sign in with Apple

    # Server
    host: str = "0.0.0.0"
    port: int = 8000

    # CORS — comma-separated origins, or "*" for dev
    cors_origins: str = "https://aurameet.live"

    # Logging
    log_level: str = "INFO"

    model_config = {"env_prefix": "MEETMIND_", "env_file": ".env"}


settings = Settings()
