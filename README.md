# 🧠 MeetMind

> The most powerful meeting AI tool — on-device transcription, real-time AI insights, proactive participation as "Digital Cris".

## Architecture

```
📱 Flutter App (Dart) ──► dart:ffi ──► whisper.cpp ──► Whisper Base (on-device STT)
       │                                    └──► CoreML/Metal (iOS) + NNAPI (Android)
       │
       └──► WebSocket ──► ☁️ FastAPI Backend (Python)
                                  │
                                  ├──► 🔀 Provider Factory (configurable)
                                  │         ├──► AWS Bedrock (Haiku/Sonnet/Opus)
                                  │         └──► OpenAI (gpt-4o-mini/gpt-4o)
                                  │
                                  ├──► Screening Agent (fast relevance check)
                                  ├──► Analysis Agent (insight generation)
                                  ├──► Copilot Agent (conversational assistant)
                                  └──► Summary Agent (structured reports)

🌐 Chrome Extension (MV3) ──► tabCapture ──► MediaRecorder (5s chunks)
                                                    │
                                                    ▼
                                            ☁️ FastAPI Backend
                                                    │
                                      ffmpeg ──► faster-whisper ──► AI Pipeline
```

## Quick Start

### Backend
```bash
cd backend
uv sync
cp .env.example .env          # Configure environment
uv run pytest                 # Run tests (191 tests, 85% coverage)
uv run uvicorn meetmind.main:app --reload  # Start server
```

#### Switching LLM Provider
```bash
# Default: AWS Bedrock (production)
MEETMIND_LLM_PROVIDER=bedrock

# Alternative: OpenAI (dev/testing)
MEETMIND_LLM_PROVIDER=openai
MEETMIND_OPENAI_API_KEY=sk-...
```

### Flutter App
```bash
cd flutter_app
fvm use 3.38.3
fvm flutter pub get
fvm flutter test              # Run tests
fvm flutter run               # Run app
```

### Chrome Extension
```bash
# 1. Open chrome://extensions/
# 2. Enable Developer Mode
# 3. Load unpacked → select chrome_extension/
# 4. Start backend, then click 🧠 MeetMind icon
```

### Quality Gates
```bash
./scripts/quality-check.sh    # 18/18 gates: Security, Lint, Format, Types, Tests, Coverage
```

## Project Structure

```
meetmind/
├── flutter_app/              # 📱 Flutter (Dart) — Mobile + Web
│   ├── lib/
│   │   ├── config/           # Theme, Router
│   │   ├── features/         # Screens (Home, Meeting, History, Settings)
│   │   ├── models/           # Domain models (Freezed-style)
│   │   ├── providers/        # Riverpod state management
│   │   ├── services/         # WebSocket, Audio, Permissions
│   │   └── native/           # dart:ffi whisper.cpp bridge
│   └── native/               # C++ plugin (whisper.cpp + CMake)
├── backend/                  # ☁️ FastAPI (Python 3.12) — Hexagonal Architecture
│   └── src/meetmind/
│       ├── agents/           # AI agents (Screening, Analysis)
│       ├── providers/        # Bedrock, OpenAI, Whisper STT, Deepgram
│       ├── core/             # Domain logic (Transcript)
│       ├── api/              # HTTP + WebSocket endpoints
│       ├── config/           # Settings (Pydantic)
│       └── security/         # Input validation
├── chrome_extension/         # 🌐 Chrome Extension (MV3)
│   ├── popup/                # Control panel UI (dark theme)
│   ├── offscreen/            # Audio recording (MediaRecorder)
│   └── service-worker.js     # Tab capture + message routing
├── infra/                    # 🏗️ Terraform (IAM for Bedrock)
├── scripts/                  # 🔧 quality-check.sh (18 gates)
└── docs/                     # 📚 Documentation
```

## Tech Stack

| Component | Technology | Rationale |
|-----------|------------|-----------|
| Mobile/Web | **Flutter** (Dart) via FVM 3.38.3 | AOT native, `dart:ffi` → C++ |
| STT on-device | **whisper.cpp** (ggerganov, MIT) | CoreML/Metal, 99 languages |
| STT server | **faster-whisper** (CTranslate2) | CPU int8, local processing |
| Backend | **FastAPI** (Python 3.12) | Hexagonal Architecture |
| AI screening | **Claude Haiku 3.5** / **gpt-4o-mini** | Configurable via `MEETMIND_LLM_PROVIDER` |
| AI analysis | **Claude Sonnet 4.5** / **gpt-4o** | Configurable via `MEETMIND_LLM_PROVIDER` |
| AI deep think | **Claude Opus 4** / **gpt-4o** | Configurable via `MEETMIND_LLM_PROVIDER` |
| State mgmt | **Riverpod** | Compile-safe DI |
| Extension | **Manifest V3** | `tabCapture` + Offscreen |

## Quality

| Metric | Value |
|--------|-------|
| Python tests | 191 passing |
| Coverage | 85% (≥80% required) |
| Quality gates | 18/18 |
| MyPy | `--strict` mode, 0 errors |
| Ruff | 0 lint errors, 100% formatted |
| Security | gitleaks scan, no secrets |

## License

Private — © Cristian Reyes
