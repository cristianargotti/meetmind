# CLAUDE.md — Aura Meet (MeetMind)

> AI-powered meeting assistant with on-device transcription, real-time AI insights, and multilingual auto-detect.

## Project Overview

Aura Meet is a multi-platform meeting AI tool. The monorepo contains:

- **backend/** — FastAPI (Python 3.12) API server with hexagonal architecture
- **flutter_app/** — Flutter/Dart mobile app (iOS + Android) with on-device STT
- **chrome_extension/** — Chrome Extension (Manifest V3) for browser-based capture
- **infra/** — Terraform (AWS) infrastructure-as-code
- **website/** — Astro-based marketing site (aurameet.live)
- **scripts/** — Quality gates, deployment, and CI helpers
- **docs/** — Business plan, roadmap, vision documents

## Quick Reference Commands

### Backend (Python)

```bash
cd backend
uv sync                                    # Install all deps (including dev)
uv run pytest                              # Run tests (191 tests, >=70% coverage required)
uv run pytest tests/ --cov=meetmind --cov-report=term-missing  # Tests with coverage
uv run ruff check src/ tests/              # Lint
uv run ruff format src/ tests/             # Format
uv run ruff check src/ tests/ --fix        # Auto-fix lint issues
uv run ruff format --check src/ tests/     # Check formatting without changing
uv run mypy src/                           # Type check (--strict mode, 0 errors required)
uv run uvicorn meetmind.main:app --reload  # Start dev server (port 8000)
```

### Flutter App (Dart)

```bash
cd flutter_app
flutter pub get              # Install dependencies
flutter gen-l10n             # Generate localizations (required before build/test)
flutter test                 # Run tests
flutter analyze --no-pub     # Static analysis (0 issues required)
dart format lib/ test/       # Format code
flutter run                  # Run app
flutter build ipa --release  # Build iOS IPA
flutter build apk --release --obfuscate --split-debug-info=build/debug-info  # Build Android APK
```

FVM is pinned to Flutter 3.38.3 (see `.fvmrc`). When FVM is installed, use `fvm flutter` / `fvm dart` instead.

### Full Quality Gate

```bash
./scripts/quality-check.sh         # All 18 quality gates (security, lint, format, types, tests, coverage)
./scripts/quality-check.sh --fix   # Same but auto-fix formatting issues
```

### Infrastructure (Terraform)

```bash
cd infra/environments/prod
terraform init
terraform plan
terraform apply
```

### Website (Astro)

```bash
cd website
npm install
npm run dev      # Local dev server
npm run build    # Production build
```

## Architecture

### Backend — Hexagonal Architecture

```
backend/src/meetmind/
├── main.py              # FastAPI app entry, routes, lifespan, Pydantic request/response models
├── agents/              # AI agents (Screening, Analysis, Copilot, Summary)
├── api/                 # HTTP + WebSocket endpoints (meeting_api.py)
├── config/              # Settings (Pydantic BaseSettings), logging setup
├── core/                # Domain logic: auth (JWT, OAuth), storage (PostgreSQL), transcript, speaker tracker
├── providers/           # LLM provider factory + adapters (Bedrock, OpenAI-compatible)
│   ├── base.py          # Protocol interfaces: LLMProvider, STTProvider
│   ├── factory.py       # create_llm_provider() — reads settings.llm_provider
│   ├── bedrock.py       # AWS Bedrock adapter
│   └── openai_provider.py  # OpenAI-compatible adapter (Groq, DeepSeek, etc.)
├── security/            # Input validation
└── utils/               # Compressor, cost tracker, response cache
```

Key patterns:
- **Provider Protocol** — Agents depend on `LLMProvider` protocol, not concrete classes. Switch providers by setting `MEETMIND_LLM_PROVIDER=openai|bedrock`.
- **Settings** — All config via env vars with `MEETMIND_` prefix (Pydantic BaseSettings). See `backend/.env.example`.
- **Structured logging** — Use `structlog`, never `print()`.
- **Auth** — Google + Apple OAuth, JWT access/refresh tokens.
- **Database** — PostgreSQL with pgvector for semantic search (RAG).

### Flutter App

```
flutter_app/lib/
├── main.dart            # App entry, Sentry init, STT init
├── config/              # Theme (dark-only), Router (go_router), AppConfig
├── features/            # Feature modules: ask_aura, auth, digest, history, home, meeting,
│                        #   onboarding, settings, setup, splash, subscription
├── l10n/                # Localizations (ARB files, generated)
├── models/              # Domain models (meeting_models.dart)
├── providers/           # Riverpod state management (auth, meeting, preferences, subscription)
└── services/            # STT, audio, auth, export, API, notifications, permissions, subscriptions
```

Key patterns:
- **State management** — Riverpod (compile-safe DI).
- **Navigation** — go_router.
- **STT** — Apple SpeechAnalyzer (iOS 26+, on-device, unlimited). Fallback: speech_to_text package.
- **Subscriptions** — RevenueCat (purchases_flutter).
- **Dark mode only** — `ThemeMode.dark` enforced.
- **Logging** — Use `debugPrint()`, never `print()`.

### Chrome Extension (Manifest V3)

```
chrome_extension/
├── manifest.json        # MV3 config
├── service-worker.js    # Tab capture + message routing
├── popup/               # Control panel UI (dark theme)
├── offscreen/           # Audio recording (MediaRecorder, 5s chunks)
└── icons/               # Extension icons
```

### Infrastructure (Terraform)

```
infra/
├── main.tf              # Provider config, S3 backend for state
├── ec2.tf, ecr.tf, bedrock.tf, ssm.tf, variables.tf  # Root resources
├── environments/prod/   # Production tfvars
└── modules/             # compute, database, dns, ecr, monitoring, networking, oidc, secrets, storage
```

- AWS region: us-east-1
- Backend runs on EC2 (t3.small) with Docker + Caddy reverse proxy
- Database: Aurora Serverless v2 (PostgreSQL + pgvector)
- CI/CD OIDC role for GitHub Actions (no static credentials)
- Terraform >= 1.5.0, AWS provider ~> 5.0

## Code Quality Standards

### Python (Backend)

| Check | Tool | Threshold |
|-------|------|-----------|
| Lint | `ruff check` | 0 errors |
| Format | `ruff format` | 100% formatted |
| Types | `mypy --strict` | 0 errors |
| Tests | `pytest` | All pass |
| Coverage | `pytest --cov` | >= 70% |
| Secrets | `gitleaks` | 0 findings |
| File size | custom | <= 500 lines soft, <= 800 hard |
| No bare `except:` | custom | Use specific exceptions |
| No `print()` | custom | Use `structlog` |

Ruff config (line-length=100, target py312): `E, W, F, I, N, UP, S, B, A, C4, SIM, TCH, RUF`

### Dart (Flutter)

| Check | Tool | Threshold |
|-------|------|-----------|
| Analyze | `flutter analyze` | 0 issues |
| Format | `dart format` | All formatted |
| Tests | `flutter test` | All pass |
| No `dynamic` | custom | No bare `dynamic` types |
| No `print()` | custom | Use `debugPrint()` |
| File size | custom | <= 500 lines |

### Security

- No hardcoded secrets — enforced by gitleaks + custom checks
- `.env` files are gitignored; use `.env.example` for templates
- All credentials via env vars with `MEETMIND_` prefix
- JWT secrets auto-generated if empty in dev
- Non-root Docker user (`meetmind:999`)

## CI/CD Workflows (GitHub Actions)

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `ci.yml` | PR/push to main (backend/**) | Backend quality gate (ruff, mypy, pytest, gitleaks) |
| `flutter-ci.yml` | PR (flutter_app/**) | Flutter analyze, format, test, anti-patterns |
| `deploy-backend.yml` | Push to main (backend/**) | Build Docker → ECR, App Runner auto-deploys |
| `flutter-release.yml` | Tag push | Build IPA + APK, upload to App Store / Play Store |
| `deploy-website.yml` | Push to main (website/**) | Build Astro → S3 + CloudFront |
| `terraform-ci.yml` | PR (infra/**) | Terraform fmt, validate, plan |
| `terraform-apply.yml` | Push to main (infra/**) | Terraform apply |
| `drift-detection.yml` | Scheduled | Detect infra drift |
| `security-scan.yml` | Scheduled/PR | Trivy, gitleaks, dependency scanning |

## Environment Variables

All backend env vars use the `MEETMIND_` prefix. Key variables:

| Variable | Purpose | Default |
|----------|---------|---------|
| `MEETMIND_ENVIRONMENT` | dev/production | dev |
| `MEETMIND_LLM_PROVIDER` | "openai" or "bedrock" | openai |
| `MEETMIND_OPENAI_API_KEY` | API key for OpenAI-compatible provider | (required) |
| `MEETMIND_OPENAI_BASE_URL` | Base URL (Groq, DeepSeek, etc.) | groq |
| `MEETMIND_DATABASE_URL` | PostgreSQL connection string | localhost |
| `MEETMIND_JWT_SECRET_KEY` | JWT signing secret | auto-generated |
| `MEETMIND_AWS_REGION` | AWS region (for Bedrock) | us-east-1 |
| `MEETMIND_LOG_LEVEL` | Logging level | INFO |

See `backend/.env.example` for full list.

## Conventions for AI Assistants

### General

- Read existing code before modifying — understand the patterns in place.
- Run `./scripts/quality-check.sh` (or individual checks) before considering work complete.
- Keep files under 500 lines (hard limit 800). Split if necessary.
- Do not commit `.env`, credentials, or secrets. Check `.gitignore`.
- Bump `version` in `flutter_app/pubspec.yaml` before each App Store upload.

### Python

- Use `structlog` for logging, never `print()`.
- Use specific exception types, never bare `except:`.
- Follow ruff rules (line-length 100). Run `uv run ruff format src/ tests/` after changes.
- All new code must pass `mypy --strict`. Add type annotations to everything.
- Tests go in `backend/tests/`, named `test_*.py`. Use `pytest-asyncio` (auto mode) for async tests.
- Use the Provider Protocol pattern — agents depend on `LLMProvider`, not concrete implementations.

### Dart/Flutter

- Use `debugPrint()` for logging, never `print()`.
- Avoid bare `dynamic` types — use explicit types.
- State management: Riverpod only. No `setState()` for complex state.
- Feature modules go in `flutter_app/lib/features/<feature_name>/`.
- Run `flutter gen-l10n` after modifying ARB localization files.
- Format with `dart format lib/ test/` before committing.

### Terraform

- Never commit `.tfvars` files (they contain secrets).
- Run `terraform fmt` and `terraform validate` before committing.
- Use modules in `infra/modules/` for reusable components.

### Git

- Branch from `main` for feature work.
- CI runs automatically on PRs — all quality gates must pass.
- Flutter CI auto-formats and commits if formatting is off.
- Backend deploys automatically on merge to main.
