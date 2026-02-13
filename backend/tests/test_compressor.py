"""Tests for Transcript Compressor — filler removal, dedup, metrics."""

from __future__ import annotations

from meetmind.utils.compressor import CompressResult, compress_transcript


class TestCompressTranscript:
    """Tests for compress_transcript function."""

    def test_empty_string(self) -> None:
        """Empty input returns empty result."""
        result = compress_transcript("")
        assert result.text == ""
        assert result.original_length == 0

    def test_whitespace_only(self) -> None:
        """Whitespace-only returns empty."""
        result = compress_transcript("   \n  \t  ")
        assert result.text == ""

    def test_removes_english_fillers(self) -> None:
        """English filler words are removed."""
        text = "So um basically the um server is like down you know"
        result = compress_transcript(text)
        assert "um" not in result.text.lower().split()
        assert "server" in result.text.lower()
        assert "down" in result.text.lower()

    def test_removes_spanish_fillers(self) -> None:
        """Spanish filler words are removed."""
        text = "Ehh pues o sea el servidor está caído"
        result = compress_transcript(text)
        assert "servidor" in result.text.lower()
        assert "caído" in result.text.lower()

    def test_dedup_sentences(self) -> None:
        """Consecutive duplicate sentences are removed."""
        text = "The server is down. The server is down. We need to fix it."
        result = compress_transcript(text)
        count = result.text.lower().count("the server is down")
        assert count == 1
        assert "fix it" in result.text.lower()

    def test_collapses_whitespace(self) -> None:
        """Multiple spaces are collapsed to single space."""
        text = "The   server   is    down"
        result = compress_transcript(text)
        assert "   " not in result.text

    def test_compression_ratio(self) -> None:
        """Compression ratio is positive for text with fillers."""
        text = "So um basically like you know the uh server is um like totally down you know"
        result = compress_transcript(text)
        assert result.compression_ratio > 0.0

    def test_tokens_saved_estimate(self) -> None:
        """Tokens saved estimate is positive for compressed text."""
        text = "Um um um um um um um um um um the server is down"
        result = compress_transcript(text)
        assert result.tokens_saved_est > 0

    def test_clean_text_minimal_change(self) -> None:
        """Clean text without fillers has minimal compression."""
        text = "The database migration completed successfully."
        result = compress_transcript(text)
        assert result.compression_ratio < 0.1

    def test_returns_compress_result(self) -> None:
        """Result is a CompressResult instance."""
        result = compress_transcript("test text")
        assert isinstance(result, CompressResult)
        assert hasattr(result, "text")
        assert hasattr(result, "compression_ratio")
        assert hasattr(result, "tokens_saved_est")
