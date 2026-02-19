#!/usr/bin/env python3
"""STT Smoke Test — verifies the transcription pipeline end-to-end.

Uses aiohttp for WebSocket (no auto Origin header, matching mobile clients).

Usage:
    # Against production
    python scripts/stt-smoke-test.py

    # Against local dev
    python scripts/stt-smoke-test.py --url ws://localhost:8000

    # With custom JWT secret
    MEETMIND_JWT_SECRET_KEY=your_secret python scripts/stt-smoke-test.py

Exit codes:
    0 = All checks passed
    1 = One or more checks failed
"""

from __future__ import annotations

import argparse
import asyncio
import base64
import json
import math
import os
import struct
import sys
import time
from datetime import datetime, timedelta, timezone

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

SAMPLE_RATE = 16000  # 16 kHz mono PCM16
TONE_DURATION = 3.0  # seconds of audio to send
CHUNK_DURATION = 0.5  # seconds per chunk


def generate_speech_like_audio(duration: float, sample_rate: int = SAMPLE_RATE) -> bytes:
    """Generate audio that loosely mimics speech patterns (varying frequencies)."""
    n_samples = int(sample_rate * duration)
    samples = []
    for i in range(n_samples):
        t = i / sample_rate
        f1 = 200 + 100 * math.sin(2 * math.pi * 3 * t)
        f2 = 800 + 200 * math.sin(2 * math.pi * 5 * t)
        f3 = 2500 + 500 * math.sin(2 * math.pi * 7 * t)
        envelope = 0.5 + 0.5 * math.sin(2 * math.pi * 4 * t)
        value = envelope * (
            0.6 * math.sin(2 * math.pi * f1 * t)
            + 0.3 * math.sin(2 * math.pi * f2 * t)
            + 0.1 * math.sin(2 * math.pi * f3 * t)
        )
        samples.append(struct.pack("<h", max(-32768, min(32767, int(32767 * 0.7 * value)))))
    return b"".join(samples)


def create_jwt(secret: str, user_id: str = "smoke-test") -> str:
    """Create a minimal JWT access token for WebSocket auth."""
    try:
        import jwt as pyjwt

        payload = {
            "sub": user_id,
            "email": "smoke-test@meetmind.dev",
            "type": "access",
            "iat": datetime.now(timezone.utc),
            "exp": datetime.now(timezone.utc) + timedelta(minutes=5),
        }
        return pyjwt.encode(payload, secret, algorithm="HS256")
    except ImportError:
        import hashlib
        import hmac

        header = base64.urlsafe_b64encode(json.dumps({"alg": "HS256", "typ": "JWT"}).encode()).rstrip(b"=").decode()
        payload_data = {
            "sub": user_id,
            "email": "smoke-test@meetmind.dev",
            "type": "access",
            "iat": int(time.time()),
            "exp": int(time.time()) + 300,
        }
        payload_b64 = base64.urlsafe_b64encode(json.dumps(payload_data).encode()).rstrip(b"=").decode()
        sig_input = f"{header}.{payload_b64}".encode()
        signature = base64.urlsafe_b64encode(
            hmac.new(secret.encode(), sig_input, hashlib.sha256).digest()
        ).rstrip(b"=").decode()
        return f"{header}.{payload_b64}.{signature}"


# ---------------------------------------------------------------------------
# Result Tracker
# ---------------------------------------------------------------------------


class SmokeTestResult:
    def __init__(self) -> None:
        self.checks: list[tuple[str, bool, str]] = []

    def check(self, name: str, passed: bool, detail: str = "") -> None:
        status = "✅" if passed else "❌"
        self.checks.append((name, passed, detail))
        print(f"  {status} {name}{f' — {detail}' if detail else ''}")

    @property
    def all_passed(self) -> bool:
        return all(passed for _, passed, _ in self.checks)

    def summary(self) -> str:
        total = len(self.checks)
        passed = sum(1 for _, p, _ in self.checks if p)
        return f"\n{'='*50}\n{'✅ ALL PASSED' if self.all_passed else '❌ FAILURES DETECTED'} ({passed}/{total})\n{'='*50}"


# ---------------------------------------------------------------------------
# Smoke Test (using aiohttp — no auto Origin)
# ---------------------------------------------------------------------------


async def run_smoke_test(ws_url: str, jwt_secret: str, timeout: float = 30.0) -> SmokeTestResult:
    """Run the full STT smoke test suite."""
    try:
        import aiohttp
    except ImportError:
        print("ERROR: pip install aiohttp")
        sys.exit(1)

    result = SmokeTestResult()
    session_id = f"smoke-{int(time.time())}"
    token = create_jwt(jwt_secret)
    full_url = f"{ws_url}/ws/transcription?token={token}"

    print(f"\n🔬 STT Smoke Test — {ws_url}")
    print(f"   Session: {session_id}")
    print(f"   Timeout: {timeout}s\n")

    # ── Step 1: WebSocket Connection ──────────────────────────────
    print("── Step 1: WebSocket Connection ──")
    try:
        # Force HTTP/1.1 via ALPN — WebSocket upgrade doesn't work over HTTP/2
        import ssl
        ssl_ctx = ssl.create_default_context()
        ssl_ctx.set_alpn_protocols(["http/1.1"])
        conn = aiohttp.TCPConnector(ssl=ssl_ctx)
        session = aiohttp.ClientSession(connector=conn)
        ws = await asyncio.wait_for(
            session.ws_connect(full_url),
            timeout=15,
        )
        result.check("WebSocket connected", True)
    except Exception as e:
        result.check("WebSocket connected", False, str(e))
        await session.close()
        print(result.summary())
        return result

    try:
        # ── Step 2: Welcome Message ──────────────────────────────
        print("\n── Step 2: Welcome Message ──")
        try:
            msg_raw = await asyncio.wait_for(ws.receive(), timeout=5)
            msg = json.loads(msg_raw.data)
            result.check("Welcome received", msg.get("type") == "connected", f"type={msg.get('type')}")
            result.check("Connection ID present", bool(msg.get("connection_id")), msg.get("connection_id", ""))
        except asyncio.TimeoutError:
            result.check("Welcome received", False, "timeout")

        # ── Step 3: STT Status ───────────────────────────────────
        print("\n── Step 3: STT Status ──")
        try:
            msg_raw = await asyncio.wait_for(ws.receive(), timeout=30)
            msg = json.loads(msg_raw.data)
            stt_ready = msg.get("ready", False)
            stt_error = msg.get("error", "")
            result.check(
                "STT status received",
                msg.get("type") == "stt_status",
                f"type={msg.get('type')}",
            )
            result.check(
                "STT engine ready",
                stt_ready,
                f"ready={stt_ready}" + (f", error={stt_error}" if stt_error else ""),
            )
        except asyncio.TimeoutError:
            result.check("STT status received", False, "timeout (model may still be loading)")
            result.check("STT engine ready", False, "no status received")

        # ── Step 4: Ping/Pong ────────────────────────────────────
        print("\n── Step 4: Ping/Pong ──")
        try:
            await ws.send_str(json.dumps({"type": "ping"}))
            msg_raw = await asyncio.wait_for(ws.receive(), timeout=5)
            msg = json.loads(msg_raw.data)
            result.check("Ping/Pong works", msg.get("type") == "pong", f"type={msg.get('type')}")
        except asyncio.TimeoutError:
            result.check("Ping/Pong works", False, "timeout")

        # ── Step 5: Send Audio ───────────────────────────────────
        print(f"\n── Step 5: Send Audio (speech-like, {TONE_DURATION:.1f}s) ──")
        audio_data = generate_speech_like_audio(TONE_DURATION)
        chunk_size = int(SAMPLE_RATE * CHUNK_DURATION) * 2
        chunks_sent = 0

        for i in range(0, len(audio_data), chunk_size):
            chunk = audio_data[i : i + chunk_size]
            b64_chunk = base64.b64encode(chunk).decode()
            await ws.send_str(json.dumps({"type": "audio", "data": b64_chunk, "speaker": "smoke-test"}))
            chunks_sent += 1
            await asyncio.sleep(CHUNK_DURATION * 0.5)

        result.check("Audio sent", True, f"{chunks_sent} chunks, {len(audio_data)} bytes")

        # ── Step 6: Wait for Transcription ───────────────────────
        print(f"\n── Step 6: Wait for Transcription (up to {timeout}s) ──")
        got_transcript = False
        messages_received = []
        deadline = time.time() + timeout

        while time.time() < deadline:
            try:
                remaining = max(0.1, deadline - time.time())
                msg_raw = await asyncio.wait_for(ws.receive(), timeout=min(remaining, 5))

                if msg_raw.type in (aiohttp.WSMsgType.CLOSED, aiohttp.WSMsgType.ERROR):
                    print(f"    ⚠️  WebSocket closed: {msg_raw.data}")
                    break

                msg = json.loads(msg_raw.data)
                messages_received.append(msg)
                msg_type = msg.get("type", "")

                if msg_type == "transcript_ack":
                    print(f"    📨 transcript_ack: segments={msg.get('segments')}")
                elif msg_type == "transcript":
                    got_transcript = True
                    print(f'    🎤 transcript: "{msg.get("text", "")}"')
                elif msg_type == "pong":
                    continue
                else:
                    print(f"    📩 {msg_type}: {json.dumps(msg)[:100]}")

                if got_transcript:
                    break

            except asyncio.TimeoutError:
                continue

        result.check(
            "Transcription received",
            got_transcript,
            f"got {len(messages_received)} messages"
            + (f", last: {messages_received[-1].get('type')}" if messages_received else ""),
        )

    finally:
        await ws.close()
        await session.close()
        print("\n   WebSocket closed.")

    print(result.summary())
    return result


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main() -> None:
    parser = argparse.ArgumentParser(description="MeetMind STT Smoke Test")
    parser.add_argument("--url", default=None, help="WebSocket base URL (default: wss://production)")
    parser.add_argument("--timeout", type=float, default=30.0, help="Max wait for transcription")
    parser.add_argument("--local", action="store_true", help="Use ws://localhost:8000")
    args = parser.parse_args()

    if args.local:
        ws_url = "ws://localhost:8000"
    elif args.url:
        ws_url = args.url
    else:
        ws_url = "wss://api.aurameet.live"

    jwt_secret = os.environ.get(
        "MEETMIND_JWT_SECRET_KEY",
        "b9996c282235d1103a878e8f772acbe8f283a04a444045efc1dceae94c5ce175",
    )

    result = asyncio.run(run_smoke_test(ws_url, jwt_secret, timeout=args.timeout))
    sys.exit(0 if result.all_passed else 1)


if __name__ == "__main__":
    main()
