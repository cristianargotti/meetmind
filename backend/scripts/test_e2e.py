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

        # Step 3.5: Test Secret Copilot
        print("\n[3.5/4] Testing Secret Copilot ...")
        await ws.send(json.dumps({
            "type": "copilot_query",
            "question": "¿Qué riesgos ves en la migración a PostgreSQL?",
        }))

        copilot_ok = False
        try:
            copilot_msg = json.loads(await asyncio.wait_for(ws.recv(), timeout=20))
            if copilot_msg.get("type") == "copilot_response":
                answer = copilot_msg.get("answer", "")[:120]
                latency = copilot_msg.get("latency_ms", 0)
                error = copilot_msg.get("error", False)
                if error:
                    print(f"  ⚠️  Copilot error: {answer}")
                else:
                    print(f"  🕵️ Copilot: {answer}")
                    print(f"     latency: {latency:.0f}ms")
                    copilot_ok = True
            else:
                print(f"  📩 Unexpected: {copilot_msg.get('type')}")
        except asyncio.TimeoutError:
            print("  ⏰ Copilot timeout (20s)")

        # Step 4: Generate Summary
        print("\n[4/5] 📊 Requesting post-meeting summary...")
        await ws.send(json.dumps({"type": "generate_summary"}))

        summary_ok = False
        try:
            summary_msg = json.loads(await asyncio.wait_for(ws.recv(), timeout=30))
            if summary_msg.get("type") == "meeting_summary":
                summary = summary_msg.get("summary", {})
                error = summary_msg.get("error", False)
                latency = summary_msg.get("latency_ms", 0)
                if error:
                    print(f"  ⚠️  Summary error: {summary.get('summary', '')[:120]}")
                else:
                    print(f"  📊 Title: {summary.get('title', 'N/A')}")
                    print(f"     Decisions: {len(summary.get('decisions', []))}")
                    print(f"     Actions:   {len(summary.get('action_items', []))}")
                    print(f"     Risks:     {len(summary.get('risks', []))}")
                    print(f"     latency:   {latency:.0f}ms")
                    summary_ok = True
            else:
                print(f"  📩 Unexpected: {summary_msg.get('type')}")
        except asyncio.TimeoutError:
            print("  ⏰ Summary timeout (30s)")

        # Step 5: Results
        print(f"\n[5/5] Results:")
        print(f"  ✅ WebSocket: OK")
        print(f"  ✅ Transcript: {len(chunks)} chunks sent")
        print(f"  {'✅' if ai_responses else '⚠️ '} AI Responses: {len(ai_responses)}")
        print(f"  {'✅' if copilot_ok else '⚠️ '} Copilot: {'OK' if copilot_ok else 'FAILED'}")
        print(f"  {'✅' if summary_ok else '⚠️ '} Summary: {'OK' if summary_ok else 'FAILED'}")

        if ai_responses and copilot_ok and summary_ok:
            print("\n🏆 FULL E2E PIPELINE WORKING!")
        elif ai_responses:
            print("\n🏆 E2E pipeline partial — check failed steps above")
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
