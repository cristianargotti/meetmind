"""Transcript Compressor — reduces token count before LLM calls.

Removes filler words, collapses duplicate whitespace, and eliminates
repeated phrases to reduce token consumption by 30-40%.
"""

from __future__ import annotations

import re

import structlog

logger = structlog.get_logger(__name__)

# Common filler words/phrases across EN, ES, PT
FILLER_PATTERNS: list[re.Pattern[str]] = [
    # English
    re.compile(r"\b(um+|uh+|ah+|eh+|er+|hmm+)\b", re.IGNORECASE),
    re.compile(
        r"\b(you know|i mean|like|basically|actually|literally|"
        r"sort of|kind of|right\?|okay so|so yeah)\b",
        re.IGNORECASE,
    ),
    # Spanish
    re.compile(
        r"\b(ehh?|pues|o sea|digamos|este|bueno bueno|"
        r"entonces entonces|ya ya|sí sí sí)\b",
        re.IGNORECASE,
    ),
    # Portuguese
    re.compile(
        r"\b(né|tipo|então então|aí aí|tá tá|bom bom)\b",
        re.IGNORECASE,
    ),
]

# Whitespace normalization
MULTI_SPACE = re.compile(r"[ \t]+")
MULTI_NEWLINE = re.compile(r"\n{3,}")


def compress_transcript(text: str) -> CompressResult:
    """Compress transcript text to reduce token count.

    Applies:
    1. Filler word removal
    2. Repeated phrase deduplication
    3. Whitespace normalization

    Args:
        text: Raw transcript text.

    Returns:
        CompressResult with compressed text and metrics.
    """
    if not text.strip():
        return CompressResult(text="", original_length=0, compressed_length=0)

    original_length = len(text)
    result = text

    # 1. Remove filler words
    for pattern in FILLER_PATTERNS:
        result = pattern.sub("", result)

    # 2. Remove consecutive duplicate sentences
    result = _dedup_sentences(result)

    # 3. Normalize whitespace
    result = MULTI_SPACE.sub(" ", result)
    result = MULTI_NEWLINE.sub("\n\n", result)
    result = result.strip()

    compressed_length = len(result)
    ratio = round(1 - (compressed_length / original_length), 3) if original_length > 0 else 0.0

    # Estimate token savings (~4 chars per token, rough heuristic)
    tokens_saved = max(0, (original_length - compressed_length) // 4)

    logger.debug(
        "transcript_compressed",
        original_chars=original_length,
        compressed_chars=compressed_length,
        ratio=ratio,
        tokens_saved_est=tokens_saved,
    )

    return CompressResult(
        text=result,
        original_length=original_length,
        compressed_length=compressed_length,
        compression_ratio=ratio,
        tokens_saved_est=tokens_saved,
    )


def _dedup_sentences(text: str) -> str:
    """Remove consecutive duplicate sentences.

    Args:
        text: Input text.

    Returns:
        Text with consecutive duplicates removed.
    """
    sentences = re.split(r"(?<=[.!?])\s+", text)
    if len(sentences) <= 1:
        return text

    deduped: list[str] = [sentences[0]]
    for sentence in sentences[1:]:
        if sentence.strip().lower() != deduped[-1].strip().lower():
            deduped.append(sentence)

    return " ".join(deduped)


class CompressResult:
    """Result of transcript compression."""

    def __init__(
        self,
        text: str,
        original_length: int,
        compressed_length: int,
        compression_ratio: float = 0.0,
        tokens_saved_est: int = 0,
    ) -> None:
        """Initialize compress result.

        Args:
            text: Compressed text.
            original_length: Original character count.
            compressed_length: Compressed character count.
            compression_ratio: Ratio of reduction (0.0 - 1.0).
            tokens_saved_est: Estimated tokens saved.
        """
        self.text = text
        self.original_length = original_length
        self.compressed_length = compressed_length
        self.compression_ratio = compression_ratio
        self.tokens_saved_est = tokens_saved_est
