"""Tests for ResponseCache — LRU cache with TTL for screening results."""

from __future__ import annotations

import time

from meetmind.utils.response_cache import ResponseCache


class TestResponseCache:
    """Tests for ResponseCache hit/miss, TTL, and LRU eviction."""

    def test_put_and_get(self) -> None:
        """Basic put/get returns cached response."""
        cache = ResponseCache()
        response = {"relevant": True, "reason": "Decision made"}
        cache.put("The team decided to use PostgreSQL", response)

        result = cache.get("The team decided to use PostgreSQL")
        assert result is not None
        assert result["relevant"] is True

    def test_cache_miss(self) -> None:
        """Missing key returns None."""
        cache = ResponseCache()
        result = cache.get("Not in cache")
        assert result is None

    def test_different_text_different_key(self) -> None:
        """Different text produces different cache keys."""
        cache = ResponseCache()
        cache.put("Text A", {"result": "A"})
        result = cache.get("Text B completely different")
        assert result is None

    def test_ttl_expiry(self) -> None:
        """Expired entries return None."""
        cache = ResponseCache(ttl_seconds=0.1)
        cache.put("test text", {"result": "cached"})

        # Wait for expiry
        time.sleep(0.15)
        result = cache.get("test text")
        assert result is None

    def test_max_entries_eviction(self) -> None:
        """Oldest entries are evicted when max reached."""
        cache = ResponseCache(max_entries=3)

        cache.put("text-1", {"result": "1"})
        cache.put("text-2", {"result": "2"})
        cache.put("text-3", {"result": "3"})

        # This should evict text-1
        cache.put("text-4", {"result": "4"})

        assert cache.size == 3
        assert cache.get("text-1") is None
        assert cache.get("text-4") is not None

    def test_hit_rate(self) -> None:
        """Hit rate tracks hits and misses correctly."""
        cache = ResponseCache()
        cache.put("test", {"result": "ok"})

        cache.get("test")  # hit
        cache.get("test")  # hit
        cache.get("missing")  # miss

        assert cache.hit_rate == 66.7  # 2/3

    def test_clear(self) -> None:
        """Clear removes all entries."""
        cache = ResponseCache()
        cache.put("text-1", {"result": "1"})
        cache.put("text-2", {"result": "2"})

        cache.clear()
        assert cache.size == 0

    def test_to_dict(self) -> None:
        """to_dict returns stats with all fields."""
        cache = ResponseCache(max_entries=50, ttl_seconds=120)
        cache.put("test", {"result": "ok"})
        cache.get("test")

        d = cache.to_dict()
        assert d["size"] == 1
        assert d["max_entries"] == 50
        assert d["hits"] == 1
        assert d["misses"] == 0
        assert d["hit_rate_pct"] == 100.0
        assert d["ttl_seconds"] == 120

    def test_case_insensitive_keys(self) -> None:
        """Cache keys are case-insensitive."""
        cache = ResponseCache()
        cache.put("Hello World Test", {"result": "ok"})
        result = cache.get("hello world test")
        assert result is not None

    def test_empty_cache_hit_rate(self) -> None:
        """Empty cache has 0% hit rate."""
        cache = ResponseCache()
        assert cache.hit_rate == 0.0
