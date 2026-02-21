# 🚀 Aura Meet — Plan Go-to-Market $0 + Automatización Total

> **Cero presupuesto. Cero intervención humana. Máximo resultado.**

*Documento creado: Febrero 16, 2026 — Basado en análisis del código real del proyecto*

---

## 📋 Resumen Ejecutivo

Aura Meet tiene una arquitectura modular (Hexagonal Architecture + Provider Factory) que permite cambiar de LLM provider con **1 variable de entorno**. Aprovechamos esto para cortar costos de AI de ~$1.78/user/mes a **$0.03/user/mes** usando APIs con free tiers generosos, y automatizamos 100% el marketing con herramientas gratuitas.

**3 objetivos:**
1. 📱 **Descargas** → 5,000 users en 6 meses (sin mover un dedo)
2. 💰 **$10K MRR** → 12 meses (monetización automática)
3. 🤝 **Inversión o venta** → Exit viable con métricas sólidas

---

## 🔍 AUDITORÍA DEL CÓDIGO REAL vs DOCUMENTACIÓN

> [!WARNING]
> **La documentación está desactualizada en varios puntos.** Aquí están las diferencias encontradas:

| Aspecto | Lo que dicen los docs | Lo que hay en el código |
|---|---|---|
| **Instancia EC2** | c8g.xlarge Graviton4 ($79/mo) | **t3.small x86** (Amazon Linux 2023) — mucho más barato |
| **STT Engine** | "Parakeet TDT 1.1B" | **Server-side:** Parakeet TDT 0.6B, Qwen3-ASR 0.6B. **On-device (iOS 26+):** Apple SpeechAnalyzer (`stt_engine` env var) |
| **Modelos Bedrock** | Nova Micro/Pro (VISION_2026) | **Haiku 3.5 + Sonnet 4.5 + Opus 4** (aún no migrado a Nova) |
| **Pricing Flutter** | $9.99 Pro (VISION) / $7.99 (BUSINESS_PLAN) | **$14.99/mo Pro, $19.99/user Team, $39.99/user Business** (en `subscription_service.dart`) |
| **Database** | "PostgreSQL embedded" | **asyncpg + PostgreSQL 17 con pgvector** (schema completo: meetings, segments, insights, summaries, action_items) |
| **RevenueCat** | "❌ Falta" en requisitos | **✅ Ya implementado** con `purchases_flutter`, 4 tiers, free tier tracking semanal |
| **Export** | "❌ Falta" | **✅ `export_service.dart` existe** (3.5KB) |
| **Ask Aura** | "Falta" | **✅ Feature folder existe** (`features/ask_aura/`) |
| **Digest** | "Falta" | **✅ Feature folder existe** (`features/digest/`) |
| **History** | "Falta" | **✅ Feature folder existe** (`features/history/`) con 2 archivos |
| **Onboarding** | "Falta" | **✅ Feature folder existe** (`features/onboarding/`) |
| **Speaker Diarization** | "Falta" | **✅ `diarization.py` implementado** (pyannote 3.1) |
| **LLM Providers** | "Bedrock o OpenAI" | **Correcto** — Factory pattern con `LLMProvider` Protocol. OpenAI provider usa `AsyncOpenAI` |
| **STT on-device** | "whisper.cpp via dart:ffi" | **✅ Reemplazado por Apple SpeechAnalyzer** (iOS 26+, unlimited, 30+ locales, auto language detect) |

> [!IMPORTANT]
> **Hallazgo clave: El `OpenAIProvider` usa la librería `openai` de Python con `AsyncOpenAI`.** Esto significa que podemos apuntar a CUALQUIER API compatible con OpenAI (Groq, Together, OpenRouter, Cerebras) cambiando solo `base_url` y `api_key`. **Cero código nuevo.**

---

## 💸 PARTE 1: Reducir Costos al Mínimo Absoluto

### Opción A: APIs con Free Tier Generoso (RECOMENDADA — $0/mes para empezar)

Reemplazar Bedrock (Haiku/Sonnet/Opus) con APIs que tienen free tiers masivos:

| Capa | Actual (Bedrock) | Costo Actual | **Reemplazo** | **Costo Nuevo** |
|---|---|---|---|---|
| **Screening** | Haiku 3.5 ($0.80/1M input) | ~$0.006/reunión | **Groq** — Llama 3.3 70B (gratis hasta 6K req/día) | **$0** |
| **Analysis** | Sonnet 4.5 ($3.00/1M input) | ~$0.024/reunión | **Groq** — Llama 3.3 70B o **Together** free tier | **$0** |
| **Copilot** | Sonnet 4.5 ($3.00/1M input) | ~$0.014/reunión | **Groq** — Llama 3.3 70B (velocidad brutal: ~750 tok/s) | **$0** |
| **Summary** | Sonnet 4.5 ($3.00/1M input) | ~$0.045/reunión | **Groq** — Llama 3.3 70B | **$0** |
| **Deep Reasoning** | Opus 4 ($15/1M input) | ~$0.10/query | **Groq** — DeepSeek R1 70B (gratis) | **$0** |
| **STT** | Parakeet TDT 0.6B (on-device) | $0 | **Sin cambio** — ya es $0 ✅ | **$0** |

#### Free Tiers Comparados (Feb 2026)

| Provider | Free Tier | Modelos Disponibles | Velocidad | API Compatible OpenAI |
|---|---|---|---|---|
| **Groq** | 6,000 req/día, 6K tokens/min | Llama 3.3 70B, DeepSeek R1 70B, Gemma 2 9B, Mixtral | ~750 tok/s 🔥 | ✅ Sí |
| **Together AI** | $5 crédito gratis al registrar | Llama 3.3, Qwen 2.5, Mistral | ~200 tok/s | ✅ Sí |
| **Cerebras** | Free tier generoso | Llama 3.3 70B | ~2,000 tok/s 🔥🔥 | ✅ Sí |
| **OpenRouter** | Modelos gratis marcados con 🆓 | Varios (rota modelos) | Variable | ✅ Sí |
| **Google AI Studio** | 15 RPM gratis Gemini 2.0 Flash | Gemini 2.0 Flash | ~300 tok/s | ✅ (con adapter) |

#### Implementación: Solo 2 Cambios en `.env`

```bash
# Antes (Bedrock — caro)
MEETMIND_LLM_PROVIDER=bedrock
MEETMIND_AWS_REGION=us-east-1

# Después (Groq — $0)
MEETMIND_LLM_PROVIDER=openai
MEETMIND_OPENAI_API_KEY=gsk_xxxxxxxxxxxx
MEETMIND_OPENAI_SCREENING_MODEL=llama-3.3-70b-versatile
MEETMIND_OPENAI_ANALYSIS_MODEL=llama-3.3-70b-versatile
MEETMIND_OPENAI_COPILOT_MODEL=llama-3.3-70b-versatile
MEETMIND_OPENAI_DEEP_MODEL=deepseek-r1-distill-llama-70b
```

> Y un pequeño cambio en `openai_provider.py` para soportar `base_url`:

```python
# En OpenAIProvider.__init__:
self._client = AsyncOpenAI(
    api_key=settings.openai_api_key,
    base_url=settings.openai_base_url or "https://api.groq.com/openai/v1",  # ← AGREGAR
)
```

**Total de cambios de código: ~3 líneas.** Todo lo demás funciona igual gracias a la Hexagonal Architecture.

### Costo Total Mensual REAL (Mínimo Absoluto)

| Componente | Costo Antes | **Costo Nuevo** |
|---|---|---|
| EC2 t3.small (actual) | ~$15/mo | **$15/mo** (o menos con Reserved) |
| EBS 30GB gp3 | $2.40/mo | **$2.40/mo** |
| Elastic IP | $3.65/mo | **$3.65/mo** |
| ECR | ~$1/mo | **~$1/mo** |
| PostgreSQL (en EC2) | $0 (embedded) | **$0** |
| AI (Bedrock) | ~$1.78/user/mo | **$0 (Groq free tier)** |
| STT (Parakeet on-device) | $0 | **$0** |
| **TOTAL** | **~$22 + $1.78/user** | **~$22/mo FIJO** 🔥 |

> [!IMPORTANT]
> **Con Groq free tier, tu AI cuesta $0. Tu infraestructura total es ~$22/mes. Con 100 usuarios pagando $14.99, tu revenue es $1,499/mes. Eso es 98.5% de margen.**

### Escalamiento al superar el Free Tier

Cuando superes los 6K req/día de Groq (~300 reuniones/día = ~1,000 usuarios activos):

| Opción | Costo | Cuándo |
|---|---|---|
| **Groq Developer plan** | ~$0.05/1M tokens (10x más barato que Bedrock) | >1,000 usuarios |
| **Together AI** | ~$0.20/1M tokens | Alternativa |
| **Multi-provider failover** | Groq → Cerebras → Together | Alta disponibilidad |
| **Self-hosted vLLM** (Hetzner ~$99/mo con GPU) | Costo fijo, sin límites | >5,000 usuarios |

---

## 🤖 PARTE 2: Marketing 100% Automatizado (CERO Intervención Humana)

### Principio: Todo lo configuras UNA VEZ, luego corre solo.

```
┌──────────────────────────────────────────────────────┐
│              SETUP ONE-TIME (1 día)                  │
│                                                      │
│  Configurar herramientas → Crear templates →          │
│  Conectar APIs → Activar automaciones → LISTO        │
└──────────────┬───────────────────────────────────────┘
               ▼
┌──────────────────────────────────────────────────────┐
│           CORRE SOLO PARA SIEMPRE ♾️                 │
│                                                      │
│  Posts automáticos → Emails automáticos →              │
│  Referrals automáticos → Reviews automáticos →        │
│  ASO se optimiza solo → Revenue crece solo            │
└──────────────────────────────────────────────────────┘
```

### Automatización 1: Social Media en Autopilot

| Herramienta | Plan Gratis | Qué Automatiza |
|---|---|---|
| **Buffer** | 3 canales, 10 posts pendientes | Programar posts en X, LinkedIn, IG |
| **Typefully** | Free tier | Threads de X/Twitter programados |
| **IFTTT** | 5 applets gratis | "If new App Store review → post en Twitter" |
| **Zapier** | 100 tasks/mo gratis | Conectar triggers entre servicios |

**Setup one-time:**
1. Crear 30 posts de contenido (Aura Meet tips, demos, comparaciones)
2. Programar en Buffer para que publique 1/día durante 30 días en X + LinkedIn
3. Repetir cada mes con variaciones (o usar AI para generar — gratis con Groq)
4. **Tiempo total: 2 horas, luego CERO**

### Automatización 2: Referral Viral Engine (In-App, Zero Touch)

Ya tienes `subscription_service.dart` con RevenueCat. Solo agregar:

```
Trigger: Usuario completa su 3ra reunión exitosa
   ↓
Mostrar popup: "Invita a un colega → ambos reciben 1 semana Pro"
   ↓
Generar deep link único con Firebase Dynamic Links (gratis)
   ↓
Colega instala → se atribuye referral → ambos upgradeados
   ↓
♾️ Loop viral automático
```

**Costo: $0.** Firebase Dynamic Links es gratis. RevenueCat ya está implementado.

### Automatización 3: App Store Reviews en Autopilot

Implementar un trigger en Flutter:

```dart
// Después de la 5ta reunión exitosa:
if (meetingsCompleted >= 5 && !hasRequestedReview) {
  InAppReview.instance.requestReview(); // API nativa iOS/Android
  hasRequestedReview = true;
}
```

**Cada review positiva sube el ranking en App Store.** No necesitas intervenir.

### Automatización 4: Email Nurturing Automático

| Herramienta | Plan Gratis | Uso |
|---|---|---|
| **Brevo** (ex-Sendinblue) | 300 emails/día gratis | Sequences automáticas |
| **Loops.so** | 1,000 contactos gratis | Product-led email |

**Secuencia automática (configuras una vez):**

| Día | Email Automático | Objetivo |
|---|---|---|
| 0 | "Bienvenido a Aura Meet 🧠" + tutorial | Activación |
| 3 | "Tu primer insight AI — mira lo que descubrimos" | Engagement |
| 7 | "Esta semana tuviste X reuniones. Aquí tu resumen" | Retención |
| 14 | "Desbloquea Ask Aura + Weekly Digest" (paywall suave) | Conversión |
| 30 | "Invita a tu equipo → 30% off Team plan" | Expansion |

**Trigger: registro del usuario. Todo el resto es automático.**

### Automatización 5: Listado en Directorios (One-Time, Passive Traffic Forever)

Publicar UNA VEZ en estos sitios gratuitos. El tráfico viene solo para siempre:

| Directorio | Tipo | Effort | Tráfico Pasivo |
|---|---|---|---|
| **Product Hunt** | Launch (1 vez) | 2 horas | 🔥🔥🔥🔥🔥 |
| **AlternativeTo** | "Alternativa a Otter.ai" | 15 min | 🔥🔥🔥🔥 |
| **There's An AI For That** | AI directory | 10 min | 🔥🔥🔥🔥 |
| **SaaSHub** | SaaS directory | 10 min | 🔥🔥🔥 |
| **BetaList** | Beta launch | 15 min | 🔥🔥🔥 |
| **Futurepedia** | AI tools | 10 min | 🔥🔥🔥 |
| **G2** | Business software | 20 min | 🔥🔥🔥🔥 |
| **Capterra** | Business software | 20 min | 🔥🔥🔥🔥 |
| **Hacker News (Show HN)** | Tech community (1 post) | 30 min | 🔥🔥🔥🔥🔥 |
| **Reddit r/selfhosted** | Community post | 15 min | 🔥🔥🔥 |

**Total: ~3 horas UNA VEZ. Luego estos listings generan tráfico pasivo indefinidamente.**

### Automatización 6: ASO que se Optimiza Solo

| Configuración | Acción | Frecuencia |
|---|---|---|
| **Título optimizado** | "Aura Meet - AI Meeting Notes" | Una vez |
| **Subtítulo** | "Private Transcription & Insights" | Una vez |
| **Keywords** | meeting notes, AI transcription, reuniones, transcripción | Una vez (revisar cada 3 meses) |
| **Screenshots** | 6 screenshots con Canva usando plantillas | Una vez |
| **Localización** | EN, ES, PT-BR | Una vez |
| **Review prompt** | In-app auto después de 5 reuniones | Automático ♾️ |
| **Custom Product Pages** | 1 para "meeting AI", 1 para "transcripción español" | Una vez |

### Automatización 7: Revenue Auto-Creciente con RevenueCat

Ya tienes `SubscriptionService` implementado. Los automáticos que ya tienes:

- ✅ Free tier tracking semanal (`_loadWeeklyUsage`)
- ✅ Paywall cuando se excede límite (`FreeTierLimits.maxMeetingsPerWeek = 3`)
- ✅ RevenueCat entitlements refresh
- ✅ Purchase + restore flows

**Solo falta configurar en RevenueCat Dashboard:**
- Ofertas: Pro Monthly, Pro Yearly (20% descuento)
- Promotional offers: 7-day free trial
- Introductory offers: primer mes a $4.99

**Esto se configura 1 vez en el dashboard de RevenueCat. Después, todo es automático.**

---

## 📊 Proyecciones con Stack Ultra-Barato

### Revenue vs Costs (con Groq free tier)

| Total Users | Paying (25%) | Infra | AI Cost | Revenue/mes | **Profit** | **Margen** |
|---|---|---|---|---|---|---|
| 100 | 25 | $22 | $0 | $375 | **+$353** | **94%** |
| 500 | 125 | $22 | $0 | $1,874 | **+$1,852** | **99%** |
| 1,000 | 250 | $22 | ~$10 (Groq paid) | $3,748 | **+$3,716** | **99%** |
| 5,000 | 1,250 | $99 (scaling) | ~$50 | $18,738 | **+$18,589** | **99%** |
| 10,000 | 2,500 | $199 | ~$100 | $37,475 | **+$37,176** | **99%** |

> [!IMPORTANT]
> **Profitable con 7 usuarios pagando Pro ($14.99 × 2 = $29.98 > $22 infra).** Literalmente 7 personas y ya cubres costos.

---

## 🤝 Atraer Inversionistas o Compradores

### Métricas que Generan Interés

| Métrica | Target Mes 6 | Target Mes 12 | Cómo se consigue |
|---|---|---|---|
| **MRR** | $3K | $10K | Referral viral + ASO + Community listings |
| **MAU** | 1,000 | 5,000 | Orgánico pasivo |
| **Pro Conversion** | ≥20% | ≥25% | Paywall optimizado + 7-day trial |
| **COGS Margin** | 99% | 99% | Groq free → casi sin costo variable |
| **CAC** | $0 | $0 | Todo orgánico |
| **LTV/CAC** | ∞ | ∞ | VCs aman esto |

### Elevator Pitch

> **"Aura Meet es el meeting AI para LATAM. Transcripción on-device (sin bots), AI insights en real-time, $14.99/mes — 50% más barato que Otter.ai. Márgenes de 99% porque nuestra AI corre en APIs gratuitas (Groq) y el STT es on-device. $0 en marketing — todo orgánico. Buscamos $500K para llegar a 5K users pagando y $18K MRR en 12 meses."**

### Opciones de Exit

| Opción | Valoración | Cuando |
|---|---|---|
| **Seed Round** (YC, Platanus, Kaszek) | $5-15M pre-money | Con $10K MRR |
| **Acqui-hire** (Google, Microsoft, Zoom) | $1-5M | Con tech diferenciada |
| **Venta** (Notion, Atlassian, Slack) | $3-10M | Con 5K+ users pagando |
| **Bootstrap forever** | N/A | $37K+/mes con 10K users |

---

## ⚡ PLAN DE EJECUCIÓN (Setup One-Time)

### Día 1: Infraestructura $0 AI (2 horas)

- [ ] Crear cuenta en Groq (groq.com) — gratis, API key instantánea
- [ ] Agregar `openai_base_url` a `settings.py` (3 líneas de código)
- [ ] Cambiar `.env` a `llm_provider=openai` + Groq API key + modelos Llama 3.3
- [ ] Testear que screening, analysis, copilot, summary funcionen con Groq
- [ ] Eliminar dependencia de Bedrock de producción (mantener como fallback)

### Día 2: Monetización Automática (3 horas)

- [ ] Configurar RevenueCat Dashboard (ya tienes el SDK integrado)
- [ ] Crear productos: Pro Monthly ($14.99), Pro Yearly ($149.99)
- [ ] Configurar 7-day free trial
- [ ] Verificar paywall flow en la app
- [ ] Agregar in-app review prompt después de 5ta reunión

### Día 3: Marketing Automático (3 horas)

- [ ] Crear landing page en Carrd.co con video demo + link App Store
- [ ] Configurar email sequence en Brevo (5 emails automáticos)
- [ ] Crear 30 posts para Buffer (1 mes de contenido social automático)
- [ ] Implementar referral deep link con Firebase Dynamic Links
- [ ] Publicar en 10 directorios gratuitos (Product Hunt coming soon + otros)

### Día 4: Product Hunt Launch (3 horas de setup, luego automático)

- [ ] Preparar assets: logo, screenshots, video demo 30seg (Canva + CapCut gratis)
- [ ] Crear listing en Product Hunt
- [ ] Programar launch day
- [ ] Preparar post de Show HN para Hacker News
- [ ] Activar todas las automaciones (Buffer, Brevo, referral)

### Día 5 en adelante: NO TOCAR NADA 🙌

Todo corre solo:
- Posts se publican solos (Buffer)
- Emails se envían solos (Brevo sequences)
- Referrals generan descargas solas (Firebase Dynamic Links)
- Reviews se solicitan solas (in-app review API)
- Revenue llega solo (RevenueCat + App Store)
- Directorios traen tráfico pasivo (listings permanentes)

---

## 🏆 Resumen Final

| Aspecto | Valor |
|---|---|
| **Costo de infra** | $22/mes |
| **Costo de AI** | $0 (Groq free) → ~$0.03/user cuando escales |
| **Costo de marketing** | $0 (todo automático + orgánico) |
| **Profitable desde** | **7 usuarios pagando** |
| **Intervención humana** | **Solo el setup inicial de ~4 días** |
| **Cambios de código** | ~3 líneas (agregar `base_url` al OpenAI provider) |
| **Margen**: | 94-99% |

---

*"La mejor estrategia de marketing es una que no necesita tu tiempo para funcionar."*
