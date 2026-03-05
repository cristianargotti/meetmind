/**
 * Aura Meet — Sidepanel JS
 * Listens for messages from the service worker and renders live
 * transcript segments, insights, and Copilot chat.
 */

import { apiFetch, getUser } from '../auth/auth.js';

// ─── State ─────────────────────────────────────────────────────

let isRecording = false;

// ─── Status ────────────────────────────────────────────────────

const statusEl = document.querySelector('.sp-status');
const statusText = statusEl?.querySelector('.sp-status__text');

function setStatus(recording) {
    isRecording = recording;
    statusEl?.classList.toggle('sp-status--recording', recording);
    if (statusText) statusText.textContent = recording ? 'Recording' : 'Not recording';
}

// ─── Transcript ────────────────────────────────────────────────

const transcriptEl = document.getElementById('sp-transcript');

function appendTranscript(segment) {
    const empty = transcriptEl?.querySelector('.sp-transcript__empty');
    if (empty) empty.remove();

    const div = document.createElement('div');
    div.className = 'sp-segment';
    const time = new Date(segment.timestamp_unix * 1000).toLocaleTimeString('en-US', {
        hour: 'numeric', minute: '2-digit', second: '2-digit'
    });
    div.innerHTML = `<span class="sp-segment__time">${time}</span>${escHtml(segment.text)}`;
    transcriptEl?.appendChild(div);
    transcriptEl?.scrollTo(0, transcriptEl.scrollHeight);
}

// ─── Insights ──────────────────────────────────────────────────

const insightsEl = document.getElementById('sp-insights');

function appendInsight(insight) {
    const empty = insightsEl?.querySelector('.sp-insights__empty');
    if (empty) empty.remove();

    const div = document.createElement('div');
    div.className = 'sp-insight';
    div.innerHTML = `<div class="sp-insight__title">${escHtml(insight.title || '')}</div>${escHtml(insight.content || '')}`;
    insightsEl?.prepend(div);
}

// ─── Copilot ───────────────────────────────────────────────────

const chatEl = document.getElementById('sp-chat');
const inputEl = document.getElementById('sp-input');
const sendBtn = document.getElementById('sp-send');

function addBubble(text, role) {
    const empty = chatEl?.querySelector('.sp-chat__welcome');
    if (empty) empty.remove();

    const div = document.createElement('div');
    div.className = `sp-bubble sp-bubble--${role}`;
    div.textContent = text;
    chatEl?.appendChild(div);
    chatEl?.scrollTo(0, chatEl.scrollHeight);
}

async function sendQuestion() {
    const q = inputEl?.value.trim();
    if (!q) return;
    inputEl.value = '';
    addBubble(q, 'user');
    sendBtn.disabled = true;

    try {
        const data = await apiFetch('/api/meetings/live/copilot', {
            method: 'POST',
            body: JSON.stringify({ question: q }),
        });
        addBubble(data.answer || data.response || '...', 'ai');
    } catch (err) {
        addBubble('⚠️ ' + err.message, 'ai');
    } finally {
        sendBtn.disabled = false;
        inputEl?.focus();
    }
}

sendBtn?.addEventListener('click', sendQuestion);
inputEl?.addEventListener('keydown', e => {
    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendQuestion(); }
});

// ─── Service Worker Messages ───────────────────────────────────

chrome.runtime.onMessage.addListener((msg) => {
    switch (msg.type) {
        case 'CAPTURE_STARTED':
            setStatus(true);
            break;
        case 'CAPTURE_STOPPED':
            setStatus(false);
            break;
        case 'TRANSCRIPT_UPDATE':
            if (msg.segment) appendTranscript(msg.segment);
            break;
        case 'INSIGHT_UPDATE':
            if (msg.insight) appendInsight(msg.insight);
            break;
    }
});

// ─── Init ──────────────────────────────────────────────────────

(async () => {
    const user = await getUser();
    if (!user) {
        document.body.innerHTML = `
            <div style="padding:32px;text-align:center;color:#94A3B8;font-family:Inter,sans-serif">
                <div style="font-size:32px;margin-bottom:12px">✦</div>
                <p>Sign in to use Aura Meet</p>
                <button onclick="chrome.runtime.openOptionsPage()" style="margin-top:16px;padding:8px 16px;background:#8B5CF6;color:white;border:none;border-radius:8px;cursor:pointer;font-family:inherit">Open Extension</button>
            </div>`;
    }
})();

function escHtml(str) {
    const d = document.createElement('div');
    d.textContent = String(str);
    return d.innerHTML;
}
