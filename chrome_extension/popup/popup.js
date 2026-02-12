/**
 * MeetMind Chrome Extension — Popup Logic.
 *
 * Handles:
 *   - Start/stop capture via service worker
 *   - Live transcript and insight display
 *   - Settings (backend URL)
 */

// ─── DOM Elements ──────────────────────────

const captureBtn = document.getElementById('capture-btn');
const captureIcon = document.getElementById('capture-icon');
const captureLabel = document.getElementById('capture-label');
const statusText = document.getElementById('status-text');
const connBadge = document.getElementById('connection-badge');

const transcriptSection = document.getElementById('transcript-section');
const transcriptBox = document.getElementById('transcript-box');

const insightsSection = document.getElementById('insights-section');
const insightsList = document.getElementById('insights-list');
const insightCount = document.getElementById('insight-count');

const settingsBtn = document.getElementById('settings-btn');
const settingsModal = document.getElementById('settings-modal');
const backendUrlInput = document.getElementById('backend-url');
const saveSettingsBtn = document.getElementById('save-settings-btn');
const closeSettingsBtn = document.getElementById('close-settings-btn');

// ─── State ─────────────────────────────────

let isCapturing = false;
let insights = [];
let backendUrl = 'ws://localhost:8000/ws';

// ─── Init ──────────────────────────────────

document.addEventListener('DOMContentLoaded', async () => {
    // Load saved settings
    const stored = await chrome.storage.local.get(['backendUrl', 'isCapturing']);
    if (stored.backendUrl) {
        backendUrl = stored.backendUrl;
        backendUrlInput.value = backendUrl;
    }

    // Check current capture status
    chrome.runtime.sendMessage({ type: 'GET_STATUS' }, (response) => {
        if (response?.isCapturing) {
            setCapturingState(true);
        }
    });
});

// ─── Capture Controls ──────────────────────

captureBtn.addEventListener('click', async () => {
    captureBtn.disabled = true;

    if (isCapturing) {
        // Stop
        const result = await chrome.runtime.sendMessage({ type: 'STOP_CAPTURE' });
        if (result?.success) {
            setCapturingState(false);
            statusText.textContent = 'Capture stopped';
        } else {
            statusText.textContent = 'Error stopping: ' + (result?.error || 'Unknown');
        }
    } else {
        // Start
        statusText.textContent = 'Starting capture...';
        const result = await chrome.runtime.sendMessage({
            type: 'START_CAPTURE',
            backendUrl,
        });
        if (result?.success) {
            setCapturingState(true);
            statusText.textContent = 'Capturing tab audio';
        } else {
            statusText.textContent = 'Error: ' + (result?.error || 'Unknown');
        }
    }

    captureBtn.disabled = false;
});

/**
 * Update UI to reflect capture state.
 * @param {boolean} capturing
 */
function setCapturingState(capturing) {
    isCapturing = capturing;

    if (capturing) {
        captureBtn.classList.add('capture-btn--recording');
        captureIcon.textContent = '⏹️';
        captureLabel.textContent = 'Stop Capture';
        transcriptSection.style.display = 'block';
    } else {
        captureBtn.classList.remove('capture-btn--recording');
        captureIcon.textContent = '🎙️';
        captureLabel.textContent = 'Start Capture';
    }
}

// ─── Message Listener ──────────────────────

chrome.runtime.onMessage.addListener((message) => {
    switch (message.type) {
        case 'TRANSCRIPT':
            handleTranscript(message);
            break;

        case 'INSIGHT':
            handleInsight(message);
            break;

        case 'SCREENING':
            handleScreening(message);
            break;

        case 'CONNECTION_STATUS':
            updateConnectionBadge(message.status);
            break;
    }
});

/**
 * Display transcript text.
 * @param {{ text: string, partial: boolean }} message
 */
function handleTranscript(message) {
    if (message.partial) {
        // Replace or add partial element
        let partial = transcriptBox.querySelector('.partial');
        if (!partial) {
            partial = document.createElement('span');
            partial.className = 'partial';
            transcriptBox.appendChild(partial);
        }
        partial.textContent = message.text;
    } else {
        // Remove partial, add finalized
        const partial = transcriptBox.querySelector('.partial');
        if (partial) partial.remove();

        const span = document.createElement('span');
        span.textContent = message.text + ' ';
        transcriptBox.appendChild(span);
    }
    transcriptBox.scrollTop = transcriptBox.scrollHeight;
}

/**
 * Display an AI insight card.
 * @param {{ title: string, analysis: string, category: string }} message
 */
function handleInsight(message) {
    insights.push(message);
    insightsSection.style.display = 'block';
    insightCount.textContent = insights.length;

    const categoryEmoji = {
        decision: '📌',
        action: '✅',
        risk: '⚠️',
        idea: '💡',
    }[message.category] || '💬';

    const card = document.createElement('div');
    card.className = 'insight-card';
    card.innerHTML = `
    <div class="insight-card__header">
      <span class="insight-card__emoji">${categoryEmoji}</span>
      <span class="insight-card__title">${escapeHtml(message.title)}</span>
    </div>
    <div class="insight-card__body">${escapeHtml(message.analysis)}</div>
  `;

    insightsList.prepend(card);
}

/**
 * Handle screening status.
 * @param {{ relevant: boolean, reason: string }} message
 */
function handleScreening(message) {
    if (message.relevant) {
        statusText.textContent = '🟢 AI detected relevant content';
    } else {
        statusText.textContent = '💤 Waiting for relevant discussion...';
    }
}

/**
 * Update connection badge.
 * @param {'connected' | 'connecting' | 'disconnected'} status
 */
function updateConnectionBadge(status) {
    connBadge.className = `badge badge--${status}`;
    const text = connBadge.querySelector('.badge-text');
    const labels = {
        connected: 'Live',
        connecting: 'Connecting',
        disconnected: 'Offline',
    };
    text.textContent = labels[status] || 'Offline';
}

// ─── Settings ──────────────────────────────

settingsBtn.addEventListener('click', () => {
    settingsModal.style.display = 'flex';
    backendUrlInput.value = backendUrl;
});

closeSettingsBtn.addEventListener('click', () => {
    settingsModal.style.display = 'none';
});

saveSettingsBtn.addEventListener('click', async () => {
    backendUrl = backendUrlInput.value.trim() || 'ws://localhost:8000/ws';
    await chrome.storage.local.set({ backendUrl });
    settingsModal.style.display = 'none';
    statusText.textContent = 'Backend URL saved ✓';
});

// ─── Utilities ─────────────────────────────

/**
 * Escape HTML to prevent XSS.
 * @param {string} text
 * @returns {string}
 */
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}
