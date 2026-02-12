# MeetMind Chrome Extension

> Capture tab audio from Google Meet, Zoom, Teams (or any browser tab) and get real-time AI transcription and insights.

## Prerequisites

- **Google Chrome** ≥ 116 (Manifest V3 + Offscreen Document support)
- **MeetMind Backend** running locally (`ws://localhost:8000/ws`)

## Installation (Developer Mode)

1. Open Chrome and navigate to `chrome://extensions/`
2. Enable **Developer mode** (toggle in top-right)
3. Click **Load unpacked**
4. Select the `chrome_extension/` directory from the MeetMind project

The extension icon (🧠) will appear in the Chrome toolbar.

## Usage

1. **Navigate** to a tab with audio (Google Meet, Zoom, YouTube, etc.)
2. Click the **MeetMind** extension icon in the toolbar
3. Click **🎙️ Start Capture**
4. The extension will:
   - Capture tab audio via `chrome.tabCapture`
   - Stream 5-second audio chunks to the backend
   - Display real-time transcriptions
   - Show AI-generated insights (📌 decisions, ✅ actions, ⚠️ risks, 💡 ideas)
5. Click **⏹️ Stop Capture** when done

## Settings

Click the ⚙️ gear icon in the footer to configure:

- **Backend URL**: WebSocket endpoint (default: `ws://localhost:8000/ws`)

## Architecture

```
Popup (UI) ←→ Service Worker (MV3) ←→ Offscreen Document (MediaRecorder)
                                              │
                                     WebSocket (binary audio)
                                              │
                                     FastAPI Backend
                                              │
                              ffmpeg → faster-whisper → AI Pipeline
```

### Key Design Decisions

- **Offscreen Document**: Required because `MediaRecorder` needs a DOM context, but MV3 service workers don't have DOM access.
- **5-second audio cycles**: Each MediaRecorder stop/start cycle produces a complete WebM blob with container headers, ensuring reliable ffmpeg decoding.
- **Tab audio playback**: The offscreen document plays back the captured `MediaStream` via `HTMLAudioElement` to prevent Chrome from silencing the tab.

## Files

| File | Purpose |
|------|---------|
| `manifest.json` | MV3 manifest with permissions |
| `service-worker.js` | Extension lifecycle, tab capture, message routing |
| `offscreen/offscreen.js` | Audio recording + WebSocket streaming |
| `popup/popup.html` | Control panel UI |
| `popup/popup.css` | Dark theme styles |
| `popup/popup.js` | UI logic, settings, insight display |

## Troubleshooting

| Issue | Solution |
|-------|---------|
| Badge shows "Offline" | Ensure backend is running: `cd backend && uv run uvicorn meetmind.main:app` |
| No transcription appears | Check Chrome DevTools console for WebSocket errors |
| Tab audio is muted | Extension should play audio back automatically; reload the extension |
| "Permission denied" | Tab capture requires an active, focused tab — click the tab first |
