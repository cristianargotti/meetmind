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

#### Choosing Your AI Provider (Zero Cost Strategy)
The backend supports the `LLMProvider` protocol, allowing you to use AWS Bedrock or **any OpenAI-compatible API** (Groq, Together, DeepSeek).

```bash
# Option A: Groq (Recommended for $0 Cost)
MEETMIND_LLM_PROVIDER=openai
MEETMIND_OPENAI_API_KEY=gsk_...
MEETMIND_OPENAI_BASE_URL=https://api.groq.com/openai/v1
MEETMIND_OPENAI_SCREENING_MODEL=llama-3.3-70b-versatile
MEETMIND_OPENAI_ANALYSIS_MODEL=llama-3.3-70b-versatile

# Option B: AWS Bedrock (Production/Enterprise)
MEETMIND_LLM_PROVIDER=bedrock
MEETMIND_AWS_REGION=us-east-1
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
│   │   ├── features/         # Features (Home, Meeting, History, Settings, Ask Aura)
│   │   ├── models/           # Domain models (Freezed-style)
│   │   ├── providers/        # Riverpod state management
│   │   ├── services/         # WebSocket, RevenueCat, Export, Audio
│   │   └── native/           # dart:ffi whisper.cpp bridge
│   └── native/               # C++ plugin (whisper.cpp + CMake)
├── backend/                  # ☁️ FastAPI (Python 3.12) — Hexagonal Architecture
│   └── src/meetmind/
│       ├── agents/           # AI agents (Screening, Analysis, Copilot)
│       ├── providers/        # Factory: Bedrock, OpenAI-compatible, 4 STT engines
│       ├── core/             # Domain logic (Transcript, Storage)
│       ├── api/              # HTTP + WebSocket endpoints
│       ├── config/           # Settings (Pydantic)
│       └── security/         # Input validation
├── chrome_extension/         # 🌐 Chrome Extension (MV3)
│   ├── popup/                # Control panel UI (dark theme)
│   ├── offscreen/            # Audio recording (MediaRecorder)
│   └── service-worker.js     # Tab capture + message routing
├── infra/                    # 🏗️ Terraform (EC2 t3.small, Caddy, Docker)
├── scripts/                  # 🔧 quality-check.sh (18 gates)
└── docs/                     # 📚 Documentation (Business Plan, Vision, GTM)
```

## Tech Stack

| Component | Technology | Rationale |
|-----------|------------|-----------|
| Mobile/Web | **Flutter** (Dart) via FVM 3.38.3 | AOT native, `dart:ffi` → C++ |
| STT on-device | **whisper.cpp** / **Moonshine** | CoreML/Metal, 99 languages |
| STT server | **Parakeet TDT 0.6B** / **Qwen3-ASR** | CPU int8, local processing (4 engines) |
| Backend | **FastAPI** (Python 3.12) | Hexagonal Architecture |
| AI Providers | **Groq** / **Bedrock** / **OpenAI** | Switchable via `LLMProvider` factory |
| Database | **PostgreSQL** + **pgvector** | Relational + Semantic Search (RAG) |
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
