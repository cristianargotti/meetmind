## 📊 Costos Reales & Unit Economics (Updated Feb 2026)

### Infraestructura Fija (Optimizada)

| Recurso | Specs | Costo/mes |
|---|---|---|
| EC2 t3.small | 2 vCPU, 2GB RAM (x86) | $15.00 |
| EBS gp3 30GB | Storage | $2.40 |
| Elastic IP | Static IP | $3.65 |
| ECR | Container registry | ~$1.00 |
| **Total infra** | | **~$22.05/mes** |

> [!IMPORTANT]
> **Cambio clave:** Migramos de Graviton ($79) a t3.small ($15) usando **Docker + Caddy + vLLM remote**. La base de datos corre en el mismo EC2 (PostgreSQL embedded).

### Costo AI por Usuario (Zero-Cost Strategy)

Usando **Groq Free Tier** (Llama 3.3 70B, DeepSeek R1) via OpenAI-compatible API:

| Componente | Modelo | Provider | Costo/reunión |
|---|---|---|---|
| Screening | Llama 3.3 70B | Groq | **$0** (Free Tier) |
| Analysis | Llama 3.3 70B | Groq | **$0** (Free Tier) |
| Copilot | Llama 3.3 70B | Groq | **$0** (Free Tier) |
| Summary | Llama 3.3 70B | Groq | **$0** (Free Tier) |
| **Total/reunión** | | | **$0.00** |

> **Límite Free Tier:** 6,000 requests/día (~300 reuniones/día).
> **Plan B (Escalado):** Groq Paid ($0.05/1M tokens) o Together AI ($0.20/1M).
> **Costo estimado a escala:** **$0.03/user/mes** (vs $1.78 con Bedrock).

### Unit Economics Rentables

| Métrica | Valor |
|---|---|
| Costo fijo/mes | $22.05 |
| Costo variable/usuario/mes | $0.00 (hasta 1,000 users) |
| **Break-even point** | **2 usuarios pagando Pro** ($14.99 × 2 = $29.98) |
| Margen con 100 users | Revenue $1,050 - Cost $22 = **98% Margen** |

---

## 💰 Pricing Strategy

### Propuesta: Freemium + Premium + Business

| Plan | Precio | Incluye | Target |
|---|---|---|---|
| **Free** | $0 | 3 reuniones/semana, transcripción, 1 insight/reunión | Adopción |
| **Pro** | **$14.99/mes** | Ilimitado, Ask Aura, Weekly Digest, Background rec, Push | Profesionales |
| **Team** | **$19.99/user** | Todo Pro + shared workspace, team analytics | Equipos pequeños |
| **Business** | **$39.99/user** | Todo Team + SSO, API, DeepSeek R1 reasoning | Empresas |

> [!TIP]
> **Pricing validado en código:** `subscription_service.dart` ya implementa estos tiers.

### Revenue Projections (99% Margen)

| Usuarios activos | Paid Conversion (5%) | Revenue/mes | Costos (Infra) | Profit/mes |
|---|---|---|---|---|
| 100 | 5 (Pro) | $75 | $22 | **+$53** |
| 1,000 | 50 (Pro) | $750 | $22 | **+$728** |
| 5,000 | 250 (Pro) | $3,748 | $50 (scale infra) | **+$3,698** |
| 10,000 | 500 (Pro) | $7,495 | $100 | **+$7,395** |

---

## 🏗️ Scaling Strategy

### Fase 1: Zero-Cost Launch (0-1,000 users)
- **Infra:** 1 EC2 t3.small ($15/mo)
- **AI:** Groq Free Tier ($0)
- **STT:** Parakeet/Moonshine on-device ($0)
- **DB:** PostgreSQL local en EC2

### Fase 2: Growth (1,000-5,000 users)
- **Infra:** Upgrade a c6i.large ($60/mo) o Hetzner AX102 ($99/mo)
- **AI:** Groq Developer Plan (Pay-as-you-go)
- **DB:** Separar RDS si es necesario (o mantener en NVMe dedicado)

---

## 🗺️ Feature Roadmap & Status Real

### ✅ Ya Implementado (Codebase Audit Feb 2026)
- **Backend:** FastAPI, Hexagonal Arch, Provider Factory (Bedrock/OpenAI), 4 STT engines.
- **Flutter:** RevenueCat subscription workflow, Free tier limits, Background service.
- **Features:** History, Export (PDF/JSON), Ask Aura (chat), Weekly Digest skeleton.
- **Infra:** Caddy reverse proxy, Docker Compose.

### 🗓️ Próximos Pasos (Go-to-Market Auto)
1. **Configurar Groq:** Cambiar `OPENAI_BASE_URL` a `https://api.groq.com/openai/v1`.
2. **Launch Automation:** Landing page (Carrd), Buffer (Social), Brevo (Email).
3. **App Store Deploy:** Screenshots, metadata, submit.

---

## 📋 Requisitos para Lanzamiento Paid

| # | Requisito | Estado Real | Acción inmediata |
|---|---|---|---|
| 1 | RevenueCat integration | ✅ Listo | Configurar productos en dashboard |
| 2 | Meeting history | ✅ Listo | - |
| 3 | Export options | ✅ Listo | - |
| 4 | Paywall UI | ✅ Listo | Testear flow |
| 5 | Speaker diarization | ✅ Listo | Verificar pyannote token |
| 6 | AI Provider Switch | ⚠️ Bedrock | **Cambiar a Groq (.env)** |
| 7 | App Store metadata | ❌ Falta | Crear en App Store Connect |

---

## 🎯 Milestones 2026

| Milestone | Fecha | Meta Financiera |
|---|---|---|
| **Zero-Cost Launch** | Mar 2026 | **$0 burn rate** |
| **First 10 Customers** | Abr 2026 | **$150 MRR** (Profitable) |
| **1,000 Active Users** | Jun 2026 | **$750 MRR** |
| **5,000 Active Users** | Sep 2026 | **$3,750 MRR** |
| **Seed Round / Exit** | Dic 2026 | Valuation $3M+ |
