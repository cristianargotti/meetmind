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
    bedrock_copilot_model: str = "us.anthropic.claude-sonnet-4-5-20250929-v1:0"
    bedrock_deep_model: str = "us.anthropic.claude-opus-4-20250514-v1:0"

    # LLM Provider selection ("bedrock" or "openai")
    llm_provider: str = "bedrock"

    # OpenAI (loaded from .env — never hardcoded)
    openai_api_key: str = ""
    openai_screening_model: str = "gpt-4o-mini"
    openai_analysis_model: str = "gpt-4o"
    openai_copilot_model: str = "gpt-4o"
    openai_deep_model: str = "gpt-4o"

    # Deepgram (cloud STT fallback)
    deepgram_api_key: str = ""

    # Screening
    screening_interval_seconds: int = 5

    # Cost Optimization
    session_budget_usd: float = 1.00
    enable_transcript_compression: bool = True
    enable_response_cache: bool = True
    enable_smart_routing: bool = True

    # STT Engine selection ("parakeet", "moonshine", "whisper", or "qwen")
    stt_engine: str = "parakeet"

    # Moonshine Voice (real-time streaming, ONNX-based, no GPU needed)
    moonshine_language: str = "es"

    # Qwen3-ASR (primary STT — lightweight, 52 languages)
    qwen_asr_model: str = "Qwen/Qwen3-ASR-0.6B"

    # NVIDIA Parakeet TDT via onnx-asr (primary — 25 languages, 30x real-time CPU)
    parakeet_model: str = "nemo-parakeet-tdt-0.6b-v3"
    parakeet_quantization: str = "int8"

    # Whisper STT (legacy fallback)
    whisper_model: str = "small"
    whisper_language: str = "es"
    stt_mode: str = "streaming"  # "streaming" (real-time) or "chunked" (legacy)

    # Speaker Diarization (pyannote)
    enable_diarization: bool = True
    diarization_model: str = "pyannote/speaker-diarization-3.1"
    huggingface_token: str = ""

    # Server
    host: str = "0.0.0.0"
    port: int = 8000

    # Logging
    log_level: str = "INFO"

    model_config = {"env_prefix": "MEETMIND_", "env_file": ".env"}


settings = Settings()
