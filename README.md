# 🧠 Aura Meet

> The most powerful meeting AI tool — on-device transcription (unlimited), real-time AI insights, multilingual auto-detect.

## Architecture

```
📱 Flutter App (Dart) ──► Apple SpeechAnalyzer (iOS 26+, on-device, unlimited)
       │                         └──► SpeechTranscriber (es/en/pt/fr/de/it/ko/zh/ja)
       │                         └──► Auto language detection (text-based heuristics)
       │
       └──► REST API ──► ☁️ FastAPI Backend (Python)
                                   │
                                   ├──► 🔀 Provider Factory (configurable)
                                   │         ├──► AWS Bedrock (Haiku/Sonnet/Opus)
                                   │         └──► OpenAI-compatible (Groq/DeepSeek)
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
                                              STT ──► AI Pipeline
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
flutter pub get
flutter gen-l10n              # Generate localizations
flutter test                  # Run tests
flutter run                   # Run app
```

### Local Builds (iOS + Android)
```bash
cd flutter_app

# iOS — Build IPA for App Store
flutter build ipa --release
# Output: build/ios/ipa/*.ipa (≈30 MB)
# Upload via Transporter app: https://apps.apple.com/us/app/transporter/id1450874784

# Android — Build release APK
flutter build apk --release --obfuscate --split-debug-info=build/debug-info
# Output: build/app/outputs/flutter-apk/app-release.apk
```

> **Note:** Bump the build number in `pubspec.yaml` (`version: X.Y.Z+BUILD`)
> before each App Store upload to avoid ITMS-90189 duplicate build errors.

### Chrome Extension
```bash
# 1. Open chrome://extensions/
# 2. Enable Developer Mode
# 3. Load unpacked → select chrome_extension/
# 4. Start backend, then click 🧠 Aura Meet icon
```

### Quality Gates
```bash
./scripts/quality-check.sh    # 18/18 gates: Security, Lint, Format, Types, Tests, Coverage
```

## Project Structure

```
meetmind/
├── flutter_app/              # 📱 Flutter (Dart) — iOS + Android
│   ├── lib/
│   │   ├── config/           # Theme, Router
│   │   ├── features/         # Features (Home, Meeting, History, Settings, Ask Aura)
│   │   ├── models/           # Domain models (Freezed-style)
│   │   ├── providers/        # Riverpod state management
│   │   └── services/         # STT, RevenueCat, Export, Audio
│   └── ios/Runner/           # Native iOS plugin (SpeechAnalyzer)
├── backend/                  # ☁️ FastAPI (Python 3.12) — Hexagonal Architecture
│   └── src/meetmind/
│       ├── agents/           # AI agents (Screening, Analysis, Copilot)
│       ├── providers/        # Factory: Bedrock, OpenAI-compatible
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
| Mobile | **Flutter** (Dart) 3.41.x | AOT native, cross-platform |
| STT on-device | **Apple SpeechAnalyzer** (iOS 26+) | Unlimited, no 60s limit, on-device |
| Auto language | **Text-based heuristics** | Auto-detect es/en/pt |
| Backend | **FastAPI** (Python 3.12) | Hexagonal Architecture |
| AI Providers | **Groq** / **Bedrock** / **OpenAI** | Switchable via `LLMProvider` factory |
| Database | **PostgreSQL** + **pgvector** | Relational + Semantic Search (RAG) |
| State mgmt | **Riverpod** | Compile-safe DI |
| Extension | **Manifest V3** | `tabCapture` + Offscreen |
| CI/CD | **GitHub Actions** | Auto build APK + IPA on tag push |

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
