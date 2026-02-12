# 🧠 MeetMind

> The most powerful meeting AI tool — on-device transcription, real-time AI, Digital Cris.

## Architecture

```
📱 Flutter App → dart:ffi → ONNX Runtime → Voxtral 4B (on-device STT)
       │
       └── WebSocket → ☁️ FastAPI Backend
                              ├── Haiku 3.5 (screening)
                              ├── Sonnet 4.5 (analysis)
                              └── Opus 4.6 (deep think)

🌐 Chrome Extension (MV3) → Same Backend
```

## Quick Start

### Backend
```bash
cd backend
uv sync
uv run pytest                        # Run tests
uv run uvicorn meetmind.main:app     # Start server
```

### Flutter App
```bash
cd flutter_app
fvm use 3.38.3
fvm flutter pub get
fvm flutter test                     # Run tests
fvm flutter run                      # Run app
```

### Quality Gates
```bash
# Python
uv run ruff check src/ tests/
uv run mypy --strict src/
uv run pytest --cov=src --cov-fail-under=80

# Flutter
fvm dart analyze
fvm dart format --set-exit-if-changed .
fvm flutter test --coverage
```

## Project Structure

```
meetmind/
├── flutter_app/          # 📱 Flutter (Dart) — Mobile + Web
├── backend/              # ☁️ FastAPI (Python) — Hexagonal Architecture
│   └── src/meetmind/
│       ├── agents/       # AI agents (Screening, Analysis, Digital Cris)
│       ├── providers/    # External adapters (Bedrock, Deepgram)
│       ├── core/         # Domain logic
│       ├── api/          # HTTP + WebSocket endpoints
│       ├── config/       # Settings (Pydantic)
│       ├── security/     # Input validation
│       └── utils/        # Logging, helpers
├── chrome_extension/     # 🌐 Chrome Extension (MV3)
└── docs/                 # 📚 ADRs, documentation
```

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Mobile/Web | Flutter (Dart) via FVM |
| STT on-device | Voxtral Mini 4B (ONNX Runtime) |
| Backend | FastAPI (Python 3.12) |
| AI | Claude Haiku/Sonnet/Opus (AWS Bedrock) |
| AWS Profile | `mibaggy-co` |
