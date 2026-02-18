#!/usr/bin/env python3
"""
App Store Connect API — Complete Setup for Aura Meet
Configures subscription localizations, app metadata, and review details.

Usage:
    pip install PyJWT cryptography requests
    python scripts/setup_appstore.py
"""

import json
import sys
import time
from pathlib import Path

import jwt
import requests

# ─── Configuration ───────────────────────────────────────────────────────────

ISSUER_ID = "96605350-4cec-4e0d-8799-028da0d4eb59"
APP_ID = "6759219835"
BASE_URL = "https://api.appstoreconnect.apple.com"

# Try keys in order of preference
KEY_CANDIDATES = [
    ("496NT439XV", "AuthKey_496NT439XV.p8"),
    ("D7JGL54W7G", "AuthKey_D7JGL54W7G.p8"),
]

# ─── Subscription Localizations ──────────────────────────────────────────────

MONTHLY_LOCALIZATIONS = {
    "en-US": {
        "name": "Aura Meet Pro — Monthly",
        "description": "Unlimited meetings, AI insights, transcriptions, and action items.",
    },
    "es-ES": {
        "name": "Aura Meet Pro — Mensual",
        "description": "Reuniones ilimitadas, insights IA, transcripciones y puntos de acción.",
    },
    "pt-BR": {
        "name": "Aura Meet Pro — Mensal",
        "description": "Reuniões ilimitadas, insights IA, transcrições e itens de ação.",
    },
}

YEARLY_LOCALIZATIONS = {
    "en-US": {
        "name": "Aura Meet Pro — Yearly",
        "description": "Unlimited meetings, AI insights, transcriptions, and action items. Save 33% vs monthly.",
    },
    "es-ES": {
        "name": "Aura Meet Pro — Anual",
        "description": "Reuniones ilimitadas, insights IA, transcripciones y puntos de acción. Ahorra 33% vs mensual.",
    },
    "pt-BR": {
        "name": "Aura Meet Pro — Anual",
        "description": "Reuniões ilimitadas, insights IA, transcrições e itens de ação. Economize 33% vs mensal.",
    },
}

GROUP_LOCALIZATIONS = {
    "en-US": {"name": "Aura Meet Pro", "customIntroductoryOfferEligibility": ""},
    "es-ES": {"name": "Aura Meet Pro", "customIntroductoryOfferEligibility": ""},
    "pt-BR": {"name": "Aura Meet Pro", "customIntroductoryOfferEligibility": ""},
}

# ─── App Store Version Metadata ──────────────────────────────────────────────

VERSION_LOCALIZATIONS = {
    "en-US": {
        "description": (
            "Aura Meet — Your AI Meeting Assistant\n\n"
            "Record, transcribe, and analyze your meetings in real-time. "
            "Aura Meet uses advanced AI to automatically generate meeting summaries, "
            "action items, and key insights so you can stay focused on the conversation.\n\n"
            "Features:\n"
            "• Real-time transcription in English, Spanish, and Portuguese\n"
            "• AI-powered meeting summaries and key takeaways\n"
            "• Automatic action item extraction\n"
            "• Ask Aura — chat with your meeting transcripts\n"
            "• Weekly meeting digest\n"
            "• Export and share your meeting notes\n"
            "• Dark mode support\n\n"
            "Free plan includes 3 meetings per week. Upgrade to Pro for unlimited meetings.\n\n"
            "Subscription Terms:\n"
            "• Aura Meet Pro Monthly: $14.99/month\n"
            "• Aura Meet Pro Yearly: $119.99/year (save 33%)\n"
            "• Payment is charged to your Apple ID account\n"
            "• Subscription auto-renews unless cancelled at least 24 hours before the end of the current period\n"
            "• Privacy Policy: https://aurameet.live/privacy\n"
            "• Terms of Use: https://aurameet.live/terms"
        ),
        "keywords": "meeting,transcription,AI,notes,assistant,productivity,audio,summary,action items",
        "marketingUrl": "https://aurameet.live",
        "supportUrl": "https://aurameet.live",
        "whatsNew": "Initial release of Aura Meet — your AI meeting assistant.",
    },
    "es-ES": {
        "description": (
            "Aura Meet — Tu Asistente IA de Reuniones\n\n"
            "Graba, transcribe y analiza tus reuniones en tiempo real. "
            "Aura Meet usa IA avanzada para generar automáticamente resúmenes, "
            "puntos de acción e insights clave para que puedas concentrarte en la conversación.\n\n"
            "Características:\n"
            "• Transcripción en tiempo real en inglés, español y portugués\n"
            "• Resúmenes con IA y conclusiones clave\n"
            "• Extracción automática de puntos de acción\n"
            "• Pregunta a Aura — chatea con tus transcripciones\n"
            "• Resumen semanal de reuniones\n"
            "• Exporta y comparte tus notas\n"
            "• Modo oscuro\n\n"
            "El plan gratuito incluye 3 reuniones por semana. Pasa a Pro para reuniones ilimitadas.\n\n"
            "Términos de Suscripción:\n"
            "• Aura Meet Pro Mensual: $14.99/mes\n"
            "• Aura Meet Pro Anual: $119.99/año (ahorra 33%)\n"
            "• El pago se carga a tu cuenta de Apple ID\n"
            "• La suscripción se renueva automáticamente a menos que se cancele 24 horas antes del final del período\n"
            "• Política de Privacidad: https://aurameet.live/privacy\n"
            "• Términos de Uso: https://aurameet.live/terms"
        ),
        "keywords": "reuniones,transcripción,IA,notas,asistente,productividad,audio,resumen,puntos de acción",
        "marketingUrl": "https://aurameet.live",
        "supportUrl": "https://aurameet.live",
        "whatsNew": "Lanzamiento inicial de Aura Meet — tu asistente IA de reuniones.",
    },
    "pt-BR": {
        "description": (
            "Aura Meet — Seu Assistente IA de Reuniões\n\n"
            "Grave, transcreva e analise suas reuniões em tempo real. "
            "Aura Meet usa IA avançada para gerar automaticamente resumos, "
            "itens de ação e insights-chave para que você possa focar na conversa.\n\n"
            "Recursos:\n"
            "• Transcrição em tempo real em inglês, espanhol e português\n"
            "• Resumos com IA e conclusões-chave\n"
            "• Extração automática de itens de ação\n"
            "• Pergunte ao Aura — converse com suas transcrições\n"
            "• Resumo semanal de reuniões\n"
            "• Exporte e compartilhe suas notas\n"
            "• Modo escuro\n\n"
            "O plano gratuito inclui 3 reuniões por semana. Assine o Pro para reuniões ilimitadas.\n\n"
            "Termos de Assinatura:\n"
            "• Aura Meet Pro Mensal: $14.99/mês\n"
            "• Aura Meet Pro Anual: $119.99/ano (economize 33%)\n"
            "• O pagamento é cobrado na sua conta Apple ID\n"
            "• A assinatura renova automaticamente a menos que seja cancelada 24 horas antes do final do período\n"
            "• Política de Privacidade: https://aurameet.live/privacy\n"
            "• Termos de Uso: https://aurameet.live/terms"
        ),
        "keywords": "reuniões,transcrição,IA,notas,assistente,produtividade,áudio,resumo,itens de ação",
        "marketingUrl": "https://aurameet.live",
        "supportUrl": "https://aurameet.live",
        "whatsNew": "Lançamento inicial do Aura Meet — seu assistente IA de reuniões.",
    },
}

# ─── Review Notes ────────────────────────────────────────────────────────────

REVIEW_NOTES = (
    "Aura Meet is a personal AI meeting assistant that helps users record, "
    "transcribe, and analyze their own meetings.\n\n"
    "MICROPHONE: Audio is captured only during active meeting sessions. "
    "The iOS microphone indicator (orange dot) is always visible during recording. "
    "Audio is processed for real-time transcription and is not stored as raw audio files.\n\n"
    "BACKGROUND AUDIO: The app uses background audio mode to continue transcribing "
    "when the user briefly switches apps during an active meeting session.\n\n"
    "SUBSCRIPTION: The app uses RevenueCat SDK for subscription management. "
    "You can test the subscription flow using a Sandbox Apple ID.\n\n"
    "TO TEST:\n"
    "1. Log in with the demo account\n"
    "2. Start a new meeting and speak for 10-15 seconds\n"
    "3. End the meeting to see the AI-generated summary and action items\n"
    "4. Navigate to Settings to see subscription management, privacy policy, "
    "terms of use, sign out, and delete account options"
)

DEMO_EMAIL = "review@aurameet.live"
DEMO_PASSWORD = "AuraReview2026!"

# ─── API Client ──────────────────────────────────────────────────────────────


class AppStoreConnectAPI:
    def __init__(self):
        self.token = None
        self.key_id = None
        self._find_working_key()

    def _find_working_key(self):
        base = Path(__file__).parent.parent
        for key_id, filename in KEY_CANDIDATES:
            key_path = base / filename
            if not key_path.exists():
                print(f"  ⚠ Key file not found: {filename}")
                continue
            try:
                private_key = key_path.read_text()
                now = int(time.time())
                payload = {
                    "iss": ISSUER_ID,
                    "iat": now,
                    "exp": now + 1200,
                    "aud": "appstoreconnect-v1",
                }
                token = jwt.encode(
                    payload, private_key, algorithm="ES256",
                    headers={"kid": key_id, "typ": "JWT"}
                )
                # Test the token
                r = requests.get(
                    f"{BASE_URL}/v1/apps/{APP_ID}",
                    headers={"Authorization": f"Bearer {token}"},
                )
                if r.status_code == 200:
                    self.token = token
                    self.key_id = key_id
                    print(f"  ✅ Using API key: {key_id}")
                    return
                else:
                    print(f"  ⚠ Key {key_id} returned {r.status_code}: {r.text[:100]}")
            except Exception as e:
                print(f"  ⚠ Key {key_id} failed: {e}")

        print("\n❌ No working API key found!")
        print("Make sure you have an App Store Connect API key (not In-App Purchase key)")
        print("with App Manager or Admin role.")
        sys.exit(1)

    def _headers(self):
        return {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json",
        }

    def get(self, path):
        r = requests.get(f"{BASE_URL}{path}", headers=self._headers())
        if r.status_code >= 400:
            print(f"  GET {path} → {r.status_code}: {r.text[:200]}")
            return None
        return r.json()

    def post(self, path, data):
        r = requests.post(f"{BASE_URL}{path}", headers=self._headers(), json=data)
        if r.status_code == 409:
            print(f"  ⚠ Already exists (409), skipping")
            return None
        if r.status_code >= 400:
            print(f"  POST {path} → {r.status_code}: {r.text[:300]}")
            return None
        return r.json()

    def patch(self, path, data):
        r = requests.patch(f"{BASE_URL}{path}", headers=self._headers(), json=data)
        if r.status_code >= 400:
            print(f"  PATCH {path} → {r.status_code}: {r.text[:300]}")
            return None
        return r.json()


# ─── Setup Functions ─────────────────────────────────────────────────────────


def setup_subscription_localizations(api):
    """Create localized names/descriptions for each subscription product."""
    print("\n📦 Setting up subscription localizations...")

    # Get subscription groups
    groups = api.get(f"/v1/apps/{APP_ID}/subscriptionGroups")
    if not groups or not groups.get("data"):
        print("  ❌ No subscription groups found!")
        return

    for group in groups["data"]:
        group_id = group["id"]
        group_name = group["attributes"].get("referenceName", "Unknown")
        print(f"\n  Group: {group_name} ({group_id})")

        # Create group localizations
        print("  Creating group localizations...")
        for locale, loc_data in GROUP_LOCALIZATIONS.items():
            result = api.post("/v1/subscriptionGroupLocalizations", {
                "data": {
                    "type": "subscriptionGroupLocalizations",
                    "attributes": {
                        "locale": locale,
                        "name": loc_data["name"],
                    },
                    "relationships": {
                        "subscriptionGroup": {
                            "data": {"type": "subscriptionGroups", "id": group_id}
                        }
                    },
                }
            })
            status = "✅" if result else "⚠"
            print(f"    {status} {locale}: {loc_data['name']}")

        # Get subscriptions in group
        subs = api.get(f"/v1/subscriptionGroups/{group_id}/subscriptions")
        if not subs or not subs.get("data"):
            print("  ❌ No subscriptions found in group!")
            continue

        for sub in subs["data"]:
            sub_id = sub["id"]
            product_id = sub["attributes"].get("productId", "")
            ref_name = sub["attributes"].get("name", "")
            print(f"\n  Subscription: {ref_name} ({product_id})")

            # Pick the right localizations
            if "monthly" in product_id.lower():
                localizations = MONTHLY_LOCALIZATIONS
            elif "yearly" in product_id.lower() or "annual" in product_id.lower():
                localizations = YEARLY_LOCALIZATIONS
            else:
                print(f"    ⚠ Unknown product ID pattern: {product_id}")
                continue

            # Create localizations
            for locale, loc_data in localizations.items():
                result = api.post("/v1/subscriptionLocalizations", {
                    "data": {
                        "type": "subscriptionLocalizations",
                        "attributes": {
                            "locale": locale,
                            "name": loc_data["name"],
                            "description": loc_data["description"],
                        },
                        "relationships": {
                            "subscription": {
                                "data": {"type": "subscriptions", "id": sub_id}
                            }
                        },
                    }
                })
                status = "✅" if result else "⚠"
                print(f"    {status} {locale}: {loc_data['name']}")


def setup_version_metadata(api):
    """Update app store version localizations with descriptions and keywords."""
    print("\n📝 Setting up version metadata...")

    # Get the app store version
    versions = api.get(f"/v1/apps/{APP_ID}/appStoreVersions?filter[appStoreState]=PREPARE_FOR_SUBMISSION")
    if not versions or not versions.get("data"):
        # Try without filter
        versions = api.get(f"/v1/apps/{APP_ID}/appStoreVersions")

    if not versions or not versions.get("data"):
        print("  ❌ No app store versions found!")
        return

    version = versions["data"][0]
    version_id = version["id"]
    version_string = version["attributes"].get("versionString", "?")
    print(f"  Version: {version_string} ({version_id})")

    # Get existing localizations
    locs = api.get(f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations")
    existing_locales = {}
    if locs and locs.get("data"):
        for loc in locs["data"]:
            locale = loc["attributes"].get("locale", "")
            existing_locales[locale] = loc["id"]
            print(f"  Found existing locale: {locale} ({loc['id']})")

    # Update or create localizations
    for locale, meta in VERSION_LOCALIZATIONS.items():
        if locale in existing_locales:
            # Update existing
            loc_id = existing_locales[locale]
            result = api.patch(f"/v1/appStoreVersionLocalizations/{loc_id}", {
                "data": {
                    "type": "appStoreVersionLocalizations",
                    "id": loc_id,
                    "attributes": meta,
                }
            })
            status = "✅" if result else "❌"
            print(f"  {status} Updated {locale}")
        else:
            # Create new
            result = api.post("/v1/appStoreVersionLocalizations", {
                "data": {
                    "type": "appStoreVersionLocalizations",
                    "attributes": {"locale": locale, **meta},
                    "relationships": {
                        "appStoreVersion": {
                            "data": {"type": "appStoreVersions", "id": version_id}
                        }
                    },
                }
            })
            status = "✅" if result else "❌"
            print(f"  {status} Created {locale}")


def setup_review_detail(api):
    """Configure review notes and demo account."""
    print("\n🔍 Setting up review details...")

    # Get the app store version
    versions = api.get(f"/v1/apps/{APP_ID}/appStoreVersions?filter[appStoreState]=PREPARE_FOR_SUBMISSION")
    if not versions or not versions.get("data"):
        versions = api.get(f"/v1/apps/{APP_ID}/appStoreVersions")

    if not versions or not versions.get("data"):
        print("  ❌ No app store versions found!")
        return

    version_id = versions["data"][0]["id"]

    # Check if review detail exists
    review = api.get(f"/v1/appStoreVersions/{version_id}/appStoreReviewDetail")

    review_attrs = {
        "contactEmail": DEMO_EMAIL,
        "demoAccountName": DEMO_EMAIL,
        "demoAccountPassword": DEMO_PASSWORD,
        "demoAccountRequired": True,
        "notes": REVIEW_NOTES,
    }

    if review and review.get("data"):
        review_id = review["data"]["id"]
        result = api.patch(f"/v1/appStoreReviewDetails/{review_id}", {
            "data": {
                "type": "appStoreReviewDetails",
                "id": review_id,
                "attributes": review_attrs,
            }
        })
        status = "✅" if result else "❌"
        print(f"  {status} Updated review details")
    else:
        result = api.post("/v1/appStoreReviewDetails", {
            "data": {
                "type": "appStoreReviewDetails",
                "attributes": review_attrs,
                "relationships": {
                    "appStoreVersion": {
                        "data": {"type": "appStoreVersions", "id": version_id}
                    }
                },
            }
        })
        status = "✅" if result else "❌"
        print(f"  {status} Created review details")


def setup_app_info(api):
    """Update app info localizations (subtitle, privacy URL)."""
    print("\n📱 Setting up app info...")

    app_infos = api.get(f"/v1/apps/{APP_ID}/appInfos")
    if not app_infos or not app_infos.get("data"):
        print("  ❌ No app info found!")
        return

    app_info_id = app_infos["data"][0]["id"]

    # Get existing app info localizations
    locs = api.get(f"/v1/appInfos/{app_info_id}/appInfoLocalizations")
    if not locs or not locs.get("data"):
        print("  ❌ No app info localizations found!")
        return

    subtitles = {
        "en-US": "AI Meeting Assistant",
        "es-ES": "Asistente IA de Reuniones",
        "pt-BR": "Assistente IA de Reuniões",
    }

    for loc in locs["data"]:
        locale = loc["attributes"].get("locale", "")
        loc_id = loc["id"]
        if locale in subtitles:
            result = api.patch(f"/v1/appInfoLocalizations/{loc_id}", {
                "data": {
                    "type": "appInfoLocalizations",
                    "id": loc_id,
                    "attributes": {
                        "subtitle": subtitles[locale],
                        "privacyPolicyUrl": "https://aurameet.live/privacy",
                    },
                }
            })
            status = "✅" if result else "❌"
            print(f"  {status} {locale}: subtitle = '{subtitles[locale]}'")


def setup_beta_test_info(api):
    """Configure TestFlight beta test information."""
    print("\n🧪 Setting up TestFlight beta test info...")

    # Get beta app localizations
    beta_locs = api.get(f"/v1/apps/{APP_ID}/betaAppLocalizations")

    beta_descriptions = {
        "en-US": {
            "description": (
                "Aura Meet is an AI-powered meeting assistant that records, "
                "transcribes, and analyzes your meetings in real-time. "
                "Get automatic summaries, action items, and insights."
            ),
            "feedbackEmail": "cristian@aurameet.live",
        },
    }

    if beta_locs and beta_locs.get("data"):
        for loc in beta_locs["data"]:
            locale = loc["attributes"].get("locale", "")
            loc_id = loc["id"]
            if locale in beta_descriptions:
                result = api.patch(f"/v1/betaAppLocalizations/{loc_id}", {
                    "data": {
                        "type": "betaAppLocalizations",
                        "id": loc_id,
                        "attributes": beta_descriptions[locale],
                    }
                })
                status = "✅" if result else "❌"
                print(f"  {status} Updated beta info for {locale}")
            else:
                # Update any existing locale with EN description
                result = api.patch(f"/v1/betaAppLocalizations/{loc_id}", {
                    "data": {
                        "type": "betaAppLocalizations",
                        "id": loc_id,
                        "attributes": beta_descriptions["en-US"],
                    }
                })
                status = "✅" if result else "❌"
                print(f"  {status} Updated beta info for {locale}")
    else:
        # Create new
        for locale, attrs in beta_descriptions.items():
            result = api.post("/v1/betaAppLocalizations", {
                "data": {
                    "type": "betaAppLocalizations",
                    "attributes": {"locale": locale, **attrs},
                    "relationships": {
                        "app": {
                            "data": {"type": "apps", "id": APP_ID}
                        }
                    },
                }
            })
            status = "✅" if result else "❌"
            print(f"  {status} Created beta info for {locale}")

    # Set beta app review detail (for external TestFlight)
    print("  Setting beta review details...")
    beta_review = api.get(f"/v1/apps/{APP_ID}/betaAppReviewDetail")

    beta_review_attrs = {
        "contactEmail": "cristian@aurameet.live",
        "contactFirstName": "Cristian",
        "contactLastName": "Reyes",
        "contactPhone": "+57 300 000 0000",
        "demoAccountName": DEMO_EMAIL,
        "demoAccountPassword": DEMO_PASSWORD,
        "demoAccountRequired": True,
        "notes": (
            "Aura Meet is an AI meeting assistant. "
            "To test: Log in with demo account → Start meeting → "
            "Speak for 10-15 seconds → End meeting → View AI summary. "
            "Requires microphone permission and internet connection."
        ),
    }

    if beta_review and beta_review.get("data"):
        review_id = beta_review["data"]["id"]
        result = api.patch(f"/v1/betaAppReviewDetails/{review_id}", {
            "data": {
                "type": "betaAppReviewDetails",
                "id": review_id,
                "attributes": beta_review_attrs,
            }
        })
        status = "✅" if result else "❌"
        print(f"  {status} Updated beta review details")
    else:
        result = api.post("/v1/betaAppReviewDetails", {
            "data": {
                "type": "betaAppReviewDetails",
                "attributes": beta_review_attrs,
                "relationships": {
                    "app": {
                        "data": {"type": "apps", "id": APP_ID}
                    }
                },
            }
        })
        status = "✅" if result else "❌"
        print(f"  {status} Created beta review details")


def print_remaining_manual_steps():
    """Print what still needs to be done manually."""
    print("\n" + "=" * 60)
    print("🎯 REMAINING MANUAL STEPS")
    print("=" * 60)
    print("""
The API cannot handle these — do them in App Store Connect UI:

1. 📸 SCREENSHOTS (required)
   App Store Connect → Aura Meet → 1.0 → each locale
   • iPhone 6.7" (15 Pro Max): min 3 screenshots
   • iPhone 6.1" (15 Pro): min 3 screenshots
   Tip: Use Xcode Simulator → Cmd+S to capture

2. 🏷️ CATEGORIES
   App Store Connect → Aura Meet → Información de la app
   • Primary: Productivity
   • Secondary: Business

3. 🔢 CONTENT RATING
   App Store Connect → Aura Meet → 1.0 → Clasificación
   • Answer "No" to all → Result: 4+

4. 🔗 LINK SUBSCRIPTIONS TO VERSION
   App Store Connect → Aura Meet → 1.0
   • "Compras dentro de la app y suscripciones" → +
   • Select both: Aura Pro Monthly + Aura Pro Yearly

5. 🔒 APP PRIVACY (App Store Connect)
   Privacidad de la app → fill per PrivacyInfo.xcprivacy:
   • Email, Name, Audio, User ID, Purchase History
   • All: Linked to user = Yes, Tracking = No

6. 👤 CREATE DEMO ACCOUNT (backend)
   curl -X POST https://api.aurameet.live/api/auth/register \\
     -H "Content-Type: application/json" \\
     -d '{"email":"review@aurameet.live","password":"AuraReview2026!","name":"Apple Reviewer"}'

7. 📦 BUILD & UPLOAD
   flutter clean && flutter pub get && flutter gen-l10n
   flutter build ios --release
   # Xcode: Product → Archive → Distribute → App Store Connect

8. 🚀 SUBMIT
   Select the build in version 1.0 → "Enviar para revisión"
""")


# ─── Main ────────────────────────────────────────────────────────────────────

def main():
    print("=" * 60)
    print("🍎 App Store Connect — Aura Meet Setup")
    print("=" * 60)

    print("\n🔑 Finding API key...")
    api = AppStoreConnectAPI()

    setup_subscription_localizations(api)
    setup_app_info(api)
    setup_version_metadata(api)
    setup_review_detail(api)
    setup_beta_test_info(api)
    print_remaining_manual_steps()

    print("\n✅ API setup complete!\n")


if __name__ == "__main__":
    main()
