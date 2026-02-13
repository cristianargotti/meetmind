"""Response Cache — LRU cache with TTL for screening results.

Avoids re-screening identical or near-identical transcript segments.
Uses SHA-256 hash of the first 200 characters as cache key.
"""

from __future__ import annotations

import hashlib
import time
from collections import OrderedDict
from typing import Any

import structlog

logger = structlog.get_logger(__name__)


class ResponseCache:
    """LRU cache with TTL for LLM responses.

    Designed for screening agent results where identical transcript
    fragments should return the same screening decision.
    """

    def __init__(
        self,
        max_entries: int = 100,
        ttl_seconds: float = 300.0,
    ) -> None:
        """Initialize the response cache.

        Args:
            max_entries: Maximum number of cached responses.
            ttl_seconds: Time-to-live for cache entries in seconds.
        """
        self._max_entries = max_entries
        self._ttl_seconds = ttl_seconds
        self._cache: OrderedDict[str, _CacheEntry] = OrderedDict()
        self._hits = 0
        self._misses = 0

    @staticmethod
    def _make_key(text: str) -> str:
        """Generate cache key from text.

        Uses SHA-256 of first 200 characters for fast lookup.

        Args:
            text: Input text to hash.

        Returns:
            Hex digest cache key.
        """
        normalized = text.strip().lower()[:200]
        return hashlib.sha256(normalized.encode()).hexdigest()[:16]

    def get(self, text: str) -> dict[str, Any] | None:
        """Look up a cached response.

        Args:
            text: Transcript text to look up.

        Returns:
            Cached response dict or None if miss/expired.
        """
        key = self._make_key(text)
        entry = self._cache.get(key)

        if entry is None:
            self._misses += 1
            return None

        # Check TTL
        if time.monotonic() - entry.timestamp > self._ttl_seconds:
            del self._cache[key]
            self._misses += 1
            logger.debug("cache_expired", key=key[:8])
            return None

        # Move to end (LRU)
        self._cache.move_to_end(key)
        self._hits += 1

        logger.debug(
            "cache_hit",
            key=key[:8],
            age_s=round(time.monotonic() - entry.timestamp, 1),
        )
        return entry.response

    def put(self, text: str, response: dict[str, Any]) -> None:
        """Store a response in the cache.

        Args:
            text: Transcript text (used as key source).
            response: LLM response to cache.
        """
        key = self._make_key(text)

        # Evict oldest if at capacity
        while len(self._cache) >= self._max_entries:
            evicted_key, _ = self._cache.popitem(last=False)
            logger.debug("cache_evicted", key=evicted_key[:8])

        self._cache[key] = _CacheEntry(
            response=response,
            timestamp=time.monotonic(),
        )

    def clear(self) -> None:
        """Clear all cached entries."""
        self._cache.clear()
        logger.info("cache_cleared")

    @property
    def size(self) -> int:
        """Current number of cached entries."""
        return len(self._cache)

    @property
    def hit_rate(self) -> float:
        """Cache hit rate as percentage."""
        total = self._hits + self._misses
        if total == 0:
            return 0.0
        return round((self._hits / total) * 100, 1)

    def to_dict(self) -> dict[str, Any]:
        """Stats for monitoring.

        Returns:
            Cache statistics dictionary.
        """
        return {
            "size": self.size,
            "max_entries": self._max_entries,
            "hits": self._hits,
            "misses": self._misses,
            "hit_rate_pct": self.hit_rate,
            "ttl_seconds": self._ttl_seconds,
        }


class _CacheEntry:
    """Internal cache entry with timestamp."""

    __slots__ = ("response", "timestamp")

    def __init__(self, response: dict[str, Any], timestamp: float) -> None:
        """Initialize cache entry.

        Args:
            response: Cached LLM response.
            timestamp: Monotonic timestamp when cached.
        """
        self.response = response
        self.timestamp = timestamp
