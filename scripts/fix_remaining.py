#!/usr/bin/env python3
"""Fix remaining ASC items: en-US version localization + review details."""

import jwt
import time
import requests
from pathlib import Path

ISSUER_ID = "96605350-4cec-4e0d-8799-028da0d4eb59"
KEY_ID = "496NT439XV"
APP_ID = "6759219835"
BASE = "https://api.appstoreconnect.apple.com"
VERSION_ID = "36ae5c19-d505-438d-b232-060297230df2"
EN_LOC_ID = "3e1212ba-583b-4878-9f31-e0006f28b8e8"

key = Path(__file__).parent.parent / f"AuthKey_{KEY_ID}.p8"
private_key = key.read_text()
now = int(time.time())
token = jwt.encode(
    {"iss": ISSUER_ID, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
    private_key, algorithm="ES256", headers={"kid": KEY_ID, "typ": "JWT"}
)
h = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

# 1. Fix en-US version localization (without whatsNew which is invalid for v1.0)
print("=== Updating en-US version localization ===")
desc_en = (
    "Aura Meet \u2014 Your AI Meeting Assistant\n\n"
    "Record, transcribe, and analyze your meetings in real-time. "
    "Aura Meet uses advanced AI to automatically generate meeting summaries, "
    "action items, and key insights so you can stay focused on the conversation.\n\n"
    "Features:\n"
    "\u2022 Real-time transcription in English, Spanish, and Portuguese\n"
    "\u2022 AI-powered meeting summaries and key takeaways\n"
    "\u2022 Automatic action item extraction\n"
    "\u2022 Ask Aura \u2014 chat with your meeting transcripts\n"
    "\u2022 Weekly meeting digest\n"
    "\u2022 Export and share your meeting notes\n"
    "\u2022 Dark mode support\n\n"
    "Free plan includes 3 meetings per week. Upgrade to Pro for unlimited meetings.\n\n"
    "Subscription Terms:\n"
    "\u2022 Aura Meet Pro Monthly: $14.99/month\n"
    "\u2022 Aura Meet Pro Yearly: $119.99/year (save 33%)\n"
    "\u2022 Payment is charged to your Apple ID account\n"
    "\u2022 Subscription auto-renews unless cancelled at least 24 hours before "
    "the end of the current period\n"
    "\u2022 Privacy Policy: https://aurameet.live/privacy\n"
    "\u2022 Terms of Use: https://aurameet.live/terms"
)

r = requests.patch(
    f"{BASE}/v1/appStoreVersionLocalizations/{EN_LOC_ID}",
    headers=h,
    json={
        "data": {
            "type": "appStoreVersionLocalizations",
            "id": EN_LOC_ID,
            "attributes": {
                "description": desc_en,
                "keywords": "meeting,transcription,AI,notes,assistant,productivity,audio,summary,action items",
                "marketingUrl": "https://aurameet.live",
                "supportUrl": "https://aurameet.live",
            },
        }
    },
)
print(f"  Status: {r.status_code}")
if r.status_code >= 400:
    print(f"  Error: {r.text[:300]}")
else:
    print("  \u2705 en-US version localization updated!")

# 2. Fix review details
print("\n=== Setting up review details ===")
review = requests.get(
    f"{BASE}/v1/appStoreVersions/{VERSION_ID}/appStoreReviewDetail", headers=h
)
print(f"  GET review detail: {review.status_code}")

review_notes = (
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

review_attrs = {
    "contactEmail": "review@aurameet.live",
    "contactFirstName": "Cristian",
    "contactLastName": "Reyes",
    "contactPhone": "+573000000000",
    "demoAccountName": "review@aurameet.live",
    "demoAccountPassword": "AuraReview2026!",
    "demoAccountRequired": True,
    "notes": review_notes,
}

if review.status_code == 200:
    data = review.json()
    if data.get("data"):
        rid = data["data"]["id"]
        print(f"  Found existing review detail: {rid}, updating...")
        r2 = requests.patch(
            f"{BASE}/v1/appStoreReviewDetails/{rid}",
            headers=h,
            json={
                "data": {
                    "type": "appStoreReviewDetails",
                    "id": rid,
                    "attributes": review_attrs,
                }
            },
        )
        print(f"  PATCH: {r2.status_code}")
        if r2.status_code >= 400:
            print(f"  Error: {r2.text[:300]}")
        else:
            print("  \u2705 Review details updated!")
    else:
        print("  No existing review detail found, creating...")
        r3 = requests.post(
            f"{BASE}/v1/appStoreReviewDetails",
            headers=h,
            json={
                "data": {
                    "type": "appStoreReviewDetails",
                    "attributes": review_attrs,
                    "relationships": {
                        "appStoreVersion": {
                            "data": {"type": "appStoreVersions", "id": VERSION_ID}
                        }
                    },
                }
            },
        )
        print(f"  POST: {r3.status_code}")
        if r3.status_code >= 400:
            print(f"  Error: {r3.text[:300]}")
        else:
            print("  \u2705 Review details created!")

print("\nDone!")
