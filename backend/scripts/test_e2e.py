"""E2E test: WebSocket connection + AI pipeline.

Run: cd backend && uv run python scripts/test_e2e.py
"""

import asyncio
import json
import sys

import websockets


async def test_e2e() -> None:
    """Test WebSocket connection and full AI pipeline."""
    print("=" * 60)
    print("  MeetMind E2E Test — WebSocket + Bedrock AI Pipeline")
    print("=" * 60)

    # Step 1: Connect
    print("\n[1/4] Connecting to ws://localhost:8000/ws ...")
    async with websockets.connect("ws://localhost:8000/ws") as ws:
        welcome = json.loads(await ws.recv())
        agents = welcome.get("agents_ready", False)
        print(f"  ✅ Connected (agents_ready={agents})")

        if not agents:
            print("  ⚠️  Bedrock agents NOT ready — screening/analysis will be skipped")

        # Step 2: Send transcript chunks
        print("\n[2/4] Sending transcript chunks ...")
        chunks = [
            "Okay team lets discuss the migration plan.",
            "We need to move the main database from MySQL to PostgreSQL 16 by end of Q1.",
            "The risk here is that the ORM layer has raw MySQL queries in 3 services.",
            "Action item: Carlos needs to audit all raw SQL by Friday.",
            "Decision: We will use pgloader for the data migration.",
            "Another concern is the connection pooling, we should use PgBouncer.",
            "Also I think we should implement read replicas for analytics.",
        ]

        for i, chunk in enumerate(chunks):
            await ws.send(json.dumps({
                "type": "transcript",
                "text": chunk,
                "speaker": "user",
            }))
            ack = json.loads(await ws.recv())
            print(f"  chunk {i + 1}/{len(chunks)}: segments={ack.get('segments')}")

        # Wait for screening interval (default 5s) + send a ping to trigger
        print("\n  ⏳ Waiting 6s for screening interval ...")
        await asyncio.sleep(6)

        # Send one more chunk to trigger the screening check
        await ws.send(json.dumps({
            "type": "transcript",
            "text": "Let me summarize what we decided.",
            "speaker": "user",
        }))
        trigger_ack = json.loads(await ws.recv())
        print(f"  trigger chunk: segments={trigger_ack.get('segments')}")

        # Step 3: Wait for AI responses (screening + analysis)
        print("\n[3/4] Waiting for AI responses (20s timeout) ...")
        ai_responses = []
        try:
            while True:
                msg = json.loads(await asyncio.wait_for(ws.recv(), timeout=20))
                ai_responses.append(msg)
                msg_type = msg.get("type", "unknown")
                if msg_type == "screening":
                    relevant = msg.get("relevant", False)
                    reason = msg.get("reason", "")[:80]
                    print(f"  🔍 Screening: relevant={relevant}, reason={reason}")
                elif msg_type == "analysis":
                    insight = msg.get("insight", {})
                    title = insight.get("title", "")[:60]
                    category = insight.get("category", "")
                    print(f"  💡 Analysis: [{category}] {title}")
                else:
                    print(f"  📩 {msg_type}: {json.dumps(msg)[:100]}")
        except asyncio.TimeoutError:
            pass

        # Step 4: Summary
        print(f"\n[4/4] Results:")
        print(f"  ✅ WebSocket: OK")
        print(f"  ✅ Transcript: {len(chunks)} chunks sent")
        print(f"  {'✅' if ai_responses else '⚠️ '} AI Responses: {len(ai_responses)}")

        if ai_responses:
            print("\n🏆 FULL E2E PIPELINE WORKING!")
        else:
            print("\n⚠️  No AI responses received — check Bedrock access")

    return None


if __name__ == "__main__":
    try:
        asyncio.run(test_e2e())
    except ConnectionRefusedError:
        print("❌ Backend not running! Start it first:")
        print("   cd backend && uv run uvicorn meetmind.main:app")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nTest cancelled.")
        sys.exit(0)
