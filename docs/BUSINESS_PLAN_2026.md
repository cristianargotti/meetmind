# 💼 Aura Meet — Business Plan 2026

## 📊 Costos Reales Actuales

### Infraestructura Fija

| Recurso | Specs | Costo/mes |
|---|---|---|
| EC2 c6i.xlarge | 4 vCPU, 8GB RAM | $124 |
| EBS gp3 30GB | Storage | $2.40 |
| Elastic IP | Static IP | $3.65 |
| ECR | Container registry | ~$1 |
| **Total infra** | | **~$131/mes** |

### Costo AI por Usuario (Bedrock)

Estimando **1 reunión de 30 min/día** por usuario:

| Componente | Modelo | Tokens/reunión | Costo/reunión |
|---|---|---|---|
| Screening (×10) | Haiku 3.5 | ~5K in + 500 out | $0.006 |
| Analysis (×3) | Sonnet 4.5 | ~3K in + 1K out | $0.024 |
| Copilot (×2) | Sonnet 4.5 | ~2K in + 500 out | $0.014 |
| Summary (×1) | Sonnet 4.5 | ~5K in + 2K out | $0.045 |
| **Total/reunión** | | | **$0.089** |
| **Total/mes** (20 reuniones) | | | **$1.78/user** |

### Costo STT (Parakeet)

| Item | Detalle | Costo |
|---|---|---|
| Parakeet TDT v3 | Corre en EC2, sin API | **$0** adicional por token |
| CPU por sesión | ~25% de 1 vCPU | Incluido en EC2 |
| **Capacidad actual** | c6i.xlarge = ~4 sesiones simultáneas | — |

### Unit Economics

| Métrica | Valor |
|---|---|
| Costo fijo/mes | $131 |
| Costo variable/usuario/mes | $1.78 (AI) |
| Costo total con 50 usuarios | $131 + $89 = **$220/mes** |
| Costo total con 200 usuarios | $131×3 + $356 = **$749/mes** |

---

## 💰 Pricing Strategy

### Propuesta: Freemium + Premium

| Plan | Precio | Incluye | Target |
|---|---|---|---|
| **Free** | $0 | 3 reuniones/semana, transcripción only, sin AI insights | Adopción, prueba |
| **Pro** | **$7.99/mes** | Ilimitado, AI insights, background recording, notificaciones, historial, export | Profesionales |
| **Team** | **$14.99/user/mes** | Todo Pro + shared workspace, analytics, integrations, priority support | Equipos |

> [!IMPORTANT]
> **$7.99/mes** es estratégico: más barato que Otter ($8.33), Fireflies ($10), y Granola ($14), pero con features que ellos no tienen (background recording, push notifications, AI screening real-time).

### Revenue Projections

| Usuarios activos | Free (70%) | Pro (25%) | Team (5%) | Revenue/mes | Profit/mes |
|---|---|---|---|---|---|
| 100 | 70 | 25 | 5 | $275 | +$99 |
| 500 | 350 | 125 | 25 | $1,373 | +$764 |
| 1,000 | 700 | 250 | 50 | $2,748 | +$1,396 |
| 5,000 | 3,500 | 1,250 | 250 | $13,748 | +$8,700 |
| 10,000 | 7,000 | 2,500 | 500 | $27,495 | +$19,495 |

---

## 🏗️ Scaling Strategy

### Fase 1: Actual (0-100 users)

```
  iPhone → WebSocket → EC2 c6i.xlarge
                        ├── Parakeet STT
                        ├── FastAPI
                        └── Bedrock API
```

- **1 EC2 c6i.xlarge** = ~4 sesiones STT simultáneas
- Suficiente para ~100 usuarios (no todos hablan al mismo tiempo)
- **Costo: $131/mes**

### Fase 2: Growth (100-1,000 users)

```
  iPhone → ALB → ECS Fargate (auto-scale)
                  ├── Task: API + STT (CPU-optimized)
                  └── Bedrock API
```

- Migrar a **ECS Fargate** con auto-scaling
- Cada task: 4 vCPU, 8GB = ~$0.18/hora = ~4 sesiones concurrent
- Auto-scale: 2-10 tasks según demanda
- **Costo estimado: $300-800/mes**

### Fase 3: Scale (1,000-10,000 users)

```
  iPhone → CloudFront → ALB → ECS Fargate (multi-AZ)
                                ├── STT tasks (CPU-optimized)
                                ├── API tasks (lightweight)
                                └── Bedrock (cross-region)
           RDS PostgreSQL ← meeting history
           S3 ← audio archives
           ElastiCache ← session cache
```

- **Separar STT y API** en tasks diferentes
- **RDS** para meeting history + search
- **S3** para audio backup
- **Multi-AZ** para alta disponibilidad
- **Costo estimado: $1,500-3,000/mes**

---

## 🗺️ Feature Roadmap por Prioridad de Monetización

### Sprint 1: Monetización Base (2-3 semanas)

| Feature | Impacto Revenue | Esfuerzo |
|---|---|---|
| **RevenueCat** — In-app subscription | 🔥🔥🔥 CRÍTICO | 3 días |
| **Paywall** — Free vs Pro | 🔥🔥🔥 | 2 días |
| **Meeting History** — guardar/buscar | 🔥🔥🔥 | 5 días |
| **Export** — copiar, compartir, email | 🔥🔥 | 2 días |

### Sprint 2: Retención (2-3 semanas)

| Feature | Impacto Revenue | Esfuerzo |
|---|---|---|
| **Speaker Diarization** (pyannote) | 🔥🔥🔥 | 5 días |
| **"Ask Aura"** — chat sobre meetings | 🔥🔥🔥 | 5 días |
| **Onboarding** — tutorial primer uso | 🔥🔥 | 2 días |
| **Meeting Templates** — standup, 1:1, brainstorm | 🔥 | 2 días |

### Sprint 3: Crecimiento (3-4 semanas)

| Feature | Impacto Revenue | Esfuerzo |
|---|---|---|
| **Android app** (Flutter = mismo code) | 🔥🔥🔥 | 5 días |
| **Apple Watch** companion | 🔥🔥🔥 | 7 días |
| **Slack/Notion integration** | 🔥🔥 | 3 días |
| **Chrome Extension** (virtual meetings) | 🔥🔥 | 5 días |

### Sprint 4: Diferenciación (4 semanas)

| Feature | Impacto Revenue | Esfuerzo |
|---|---|---|
| **Live Coaching** — sugerencias en real-time | 🔥🔥🔥 | 10 días |
| **Multi-language auto-detect** | 🔥🔥 | 3 días |
| **Weekly Digest** — resumen semanal AI | 🔥🔥 | 3 días |
| **CRM sync** (HubSpot) — plan Team | 🔥 | 5 días |

---

## 🛡️ Competitive Moat

Lo que nos hace **imposibles de copiar rápido**:

| Moat | Detalle |
|---|---|
| **STT propio** | Parakeet on-device, sin dependencia de APIs cloud |
| **AI screening real-time** | Nadie más detecta ideas mientras hablas |
| **Background + push** | Única app que graba en background y notifica |
| **LATAM-first** | Optimizado para ES/PT desde día 1, no como add-on |
| **Precio agresivo** | $7.99 vs competencia $10-35 |

---

## 📋 Requisitos para Lanzamiento Paid

| # | Requisito | Estado | Prioridad |
|---|---|---|---|
| 1 | RevenueCat + subscriptions iOS | ❌ Falta | 🔴 |
| 2 | Meeting history persistente | ❌ Falta | 🔴 |
| 3 | Export (copy/share/email) | ❌ Falta | 🔴 |
| 4 | Paywall UI (Free vs Pro) | ❌ Falta | 🔴 |
| 5 | Speaker diarization | ❌ Falta | 🟡 |
| 6 | App Store listing + screenshots | ❌ Falta | 🟡 |
| 7 | Privacy policy + Terms | ❌ Falta | 🟡 |
| 8 | Onboarding flow | ❌ Falta | 🟡 |
| 9 | App icon correcto | ⚠️ Warning | 🟢 |
| 10 | Android build | ❌ Falta | 🟢 |

---

## 🎯 Milestones

| Milestone | Fecha Target | Métrica |
|---|---|---|
| **v1 Alpha** (ahora) | Feb 2026 | ✅ Transcripción + AI insights working |
| **v2 Beta** — paid ready | Mar 2026 | RevenueCat + history + export + paywall |
| **v3 Launch** — App Store | Abr 2026 | Speaker ID + Ask Aura + listing |
| **100 users** | May 2026 | $275/mes revenue |
| **500 users** | Jul 2026 | $1,373/mes revenue |
| **Android launch** | Ago 2026 | 2× market reach |
| **1,000 users** | Oct 2026 | $2,748/mes → profitable |
| **Apple Watch** | Nov 2026 | Killer differentiator |
