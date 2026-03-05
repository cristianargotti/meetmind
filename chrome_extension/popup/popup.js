/**
 * Aura Meet Chrome Extension — Popup Logic.
 *
 * Handles:
 *   - Auth gate: shows login screen or main app based on session
 *   - Start/stop capture via service worker
 *   - Live transcript and insight display
 *   - Tab navigation (Transcript ↔ Aura ↔ Summary)
 *   - Aura copilot chat with AI
 *   - Post-meeting summary generation
 *   - Settings (backend URL, language, transcription language)
 *   - i18n (EN/ES/PT) via i18n.js
 */

import { signIn, signOut, getUser, getIsPro } from '../auth/auth.js';

// ─── DOM Elements ──────────────────────────

const captureBtn = document.getElementById('capture-btn');
const captureIcon = document.getElementById('capture-icon');
const captureLabel = document.getElementById('capture-label');
const statusText = document.getElementById('status-text');
const connBadge = document.getElementById('connection-badge');

const tabNav = document.getElementById('tab-nav');
const transcriptPanel = document.getElementById('panel-transcript');
const insightsPanel = document.getElementById('panel-insights');
const copilotPanel = document.getElementById('panel-copilot');
const summaryPanel = document.getElementById('panel-summary');

const transcriptSection = document.getElementById('transcript-section');
const transcriptBox = document.getElementById('transcript-box');

const insightsEmpty = document.getElementById('insights-empty');
const insightsFeed = document.getElementById('insights-feed');
const insightsList = document.getElementById('insights-list');

const chatMessages = document.getElementById('chat-messages');
const chatInput = document.getElementById('chat-input');
const chatSendBtn = document.getElementById('chat-send-btn');
const dashboardBtn = document.getElementById('dashboard-btn');

const settingsBtn = document.getElementById('settings-btn');
const settingsModal = document.getElementById('settings-modal');
const backendUrlInput = document.getElementById('backend-url');
const uiLanguageSelect = document.getElementById('ui-language');
const transcriptionLanguageSelect = document.getElementById('transcription-language');
const saveSettingsBtn = document.getElementById('save-settings-btn');
const closeSettingsBtn = document.getElementById('close-settings-btn');

// Cost bar elements
const costBar = document.getElementById('cost-bar');
const costValue = document.getElementById('cost-value');
const costBudget = document.getElementById('cost-budget');
const costFill = document.getElementById('cost-fill');

// ─── State ─────────────────────────────────

let isCapturing = false;
let insights = [];
let backendUrl = 'wss://api.aurameet.live/ws';
let copilotWaiting = false;
let lastSummaryData = null;

// ─── Init ──────────────────────────────────

document.addEventListener('DOMContentLoaded', async () => {
    // 1. Auth gate — show login or app
    await checkAuthAndRender();

    // Initialize i18n (auto-detect or load persisted locale)
    await initI18n();

    // Load saved settings
    const stored = await chrome.storage.local.get(['backendUrl', 'isCapturing']);
    backendUrl = stored.backendUrl || 'wss://api.aurameet.live/ws';
    backendUrlInput.value = backendUrl;

    // Sync language selectors with persisted values
    if (uiLanguageSelect) uiLanguageSelect.value = getLocale();
    if (transcriptionLanguageSelect) transcriptionLanguageSelect.value = getTranscriptionLanguage();

    // Check current capture status
    chrome.runtime.sendMessage({ type: 'GET_STATUS' }, (response) => {
        if (response?.isCapturing) {
            setCapturingState(true);
        }
    });

    // Set up tab navigation
    initTabs();
});

// ─── Auth Flow ─────────────────────────────────────────────────

const loginScreen = document.getElementById('login-screen');
const appScreen = document.getElementById('app-screen');
const googleSigninBtn = document.getElementById('google-signin-btn');
const userInfo = document.getElementById('user-info');
const userAvatar = document.getElementById('user-avatar');
const userName = document.getElementById('user-name');
const signoutBtn = document.getElementById('signout-btn');

/**
 * Show login or main app based on current auth state.
 */
async function checkAuthAndRender() {
    const user = await getUser();
    if (!user) {
        loginScreen.style.display = 'flex';
        appScreen.style.display = 'none';
        return;
    }
    const isPro = await getIsPro();
    showApp(user, isPro);
}

function showApp(user, isPro = false) {
    loginScreen.style.display = 'none';
    appScreen.style.display = 'block';
    if (user?.avatar_url) {
        userAvatar.src = user.avatar_url;
        userAvatar.style.display = 'inline-block';
    }
    if (user?.name) {
        userName.textContent = user.name.split(' ')[0];
    }
    userInfo.style.display = 'flex';

    // Pro gate — lock Copilot tab for free users
    const copilotTab = document.querySelector('[data-tab="copilot"]');
    if (copilotTab && !isPro) {
        copilotTab.classList.add('tab--locked');
        copilotTab.title = 'Upgrade to Aura Pro to use Ask Aura';
        copilotTab.addEventListener('click', (e) => {
            e.stopImmediatePropagation();
            chrome.tabs.create({ url: 'https://aurameet.live/pricing' });
        }, { capture: true });
    }
}

if (googleSigninBtn) {
    googleSigninBtn.addEventListener('click', async () => {
        googleSigninBtn.disabled = true;
        googleSigninBtn.textContent = 'Signing in...';
        try {
            const { user, isPro } = await signIn();
            showApp(user, isPro);
        } catch (err) {
            googleSigninBtn.disabled = false;
            googleSigninBtn.innerHTML = `<span style="color:#EF4444">⚠️ ${err.message}</span>`;
            setTimeout(() => {
                googleSigninBtn.innerHTML = 'Continue with Google';
                googleSigninBtn.disabled = false;
            }, 3000);
        }
    });
}

if (signoutBtn) {
    signoutBtn.addEventListener('click', async () => {
        await signOut();
        userInfo.style.display = 'none';
        loginScreen.style.display = 'flex';
        appScreen.style.display = 'none';
    });
}

// ─── Dashboard Navigation ──────────────────

if (dashboardBtn) {
    dashboardBtn.addEventListener('click', () => {
        chrome.tabs.create({ url: 'https://aurameet.live' });
    });
}

// ─── Tab Navigation ────────────────────────

function initTabs() {
    const tabs = document.querySelectorAll('.tab');
    tabs.forEach((tab) => {
        tab.addEventListener('click', () => {
            // Update active tab
            tabs.forEach((t) => t.classList.remove('tab--active'));
            tab.classList.add('tab--active');

            // Show correct panel
            const target = tab.dataset.tab;
            transcriptPanel.classList.toggle('tab-panel--active', target === 'transcript');
            insightsPanel.classList.toggle('tab-panel--active', target === 'insights');
            copilotPanel.classList.toggle('tab-panel--active', target === 'copilot');
            summaryPanel.classList.toggle('tab-panel--active', target === 'summary');

            // Focus chat input when switching to copilot
            if (target === 'copilot') {
                setTimeout(() => chatInput.focus(), 100);
            }
        });
    });
}

// ─── Capture Controls ──────────────────────

captureBtn.addEventListener('click', async () => {
    captureBtn.disabled = true;

    if (isCapturing) {
        // Stop
        const result = await chrome.runtime.sendMessage({ type: 'STOP_CAPTURE' });
        if (result?.success) {
            setCapturingState(false);
            statusText.textContent = t('captureStopped');
        } else {
            statusText.textContent = t('captureError') + ': ' + (result?.error || 'Unknown');
        }
    } else {
        // Start
        statusText.textContent = t('captureStarting');
        const result = await chrome.runtime.sendMessage({
            type: 'START_CAPTURE',
            backendUrl,
        });
        if (result?.success) {
            setCapturingState(true);
            statusText.textContent = t('captureActive');
        } else {
            statusText.textContent = t('captureError') + ': ' + (result?.error || 'Unknown');
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
        captureLabel.textContent = t('captureStop');
        transcriptSection.style.display = 'flex';
        tabNav.style.display = 'flex';
    } else {
        captureBtn.classList.remove('capture-btn--recording');
        captureIcon.textContent = '🎙️';
        captureLabel.textContent = t('captureStart');
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

        case 'COPILOT_RESPONSE':
            handleCopilotResponse(message);
            break;

        case 'MEETING_SUMMARY':
            handleMeetingSummary(message);
            break;

        case 'CONNECTION_STATUS':
            updateConnectionBadge(message.status);
            break;

        case 'COST_UPDATE':
            handleCostUpdate(message);
            break;

        case 'BUDGET_EXCEEDED':
            handleBudgetExceeded(message);
            break;
    }
});

/**
 * Display transcript text with timestamps and live partial indicator.
 * Partials update in-place at the bottom; finals are timestamped segments.
 * @param {{ text: string, partial: boolean, speaker?: string, speaker_color?: string }} message
 */
let lastTranscriptText = '';
let segmentCount = 0;

function handleTranscript(message) {
    if (message.partial) {
        // Live partial: update the "typing" element at bottom
        let liveEl = transcriptBox.querySelector('.transcript-live');
        if (!liveEl) {
            liveEl = document.createElement('div');
            liveEl.className = 'transcript-live';
            liveEl.innerHTML = '<span class="live-dot"></span><span class="live-text"></span>';
            transcriptBox.appendChild(liveEl);
        }
        liveEl.querySelector('.live-text').textContent = message.text;
    } else {
        // Finalized segment
        const trimmed = message.text.trim();
        if (!trimmed || trimmed === lastTranscriptText) return;
        lastTranscriptText = trimmed;

        // Remove live partial
        const liveEl = transcriptBox.querySelector('.transcript-live');
        if (liveEl) liveEl.remove();

        // Create timestamped segment
        segmentCount++;
        const seg = document.createElement('div');
        seg.className = 'transcript-segment';

        // Timestamp
        const now = new Date();
        const timeStr = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
        const ts = document.createElement('span');
        ts.className = 'segment-time';
        ts.textContent = timeStr;
        seg.appendChild(ts);

        // Text content
        const textEl = document.createElement('p');
        textEl.className = 'segment-text';
        textEl.textContent = trimmed;
        seg.appendChild(textEl);

        transcriptBox.appendChild(seg);
    }

    // Smart auto-scroll: only scroll if user is near the bottom
    const isNearBottom = (transcriptBox.scrollHeight - transcriptBox.scrollTop - transcriptBox.clientHeight) < 100;
    if (isNearBottom) {
        const last = transcriptBox.lastElementChild;
        if (last) last.scrollIntoView({ behavior: 'smooth', block: 'end' });
    }
}

/**
 * Display an AI insight card.
 * @param {{ title: string, analysis: string, category: string }} message
 */
function handleInsight(message) {
    insights.push(message);

    // Show the feed, hide empty state
    if (insightsEmpty) insightsEmpty.style.display = 'none';
    if (insightsFeed) insightsFeed.style.display = 'block';

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

    // Update tab badge with count
    const insightsTab = document.querySelector('[data-tab="insights"]');
    if (insightsTab) {
        insightsTab.textContent = `🔮 Insights (${insights.length})`;
    }
}

/**
 * Handle screening status.
 * @param {{ relevant: boolean, reason: string }} message
 */
function handleScreening(message) {
    if (message.relevant) {
        statusText.textContent = t('screeningRelevant');
    } else {
        statusText.textContent = t('screeningWaiting');
    }
}

// ─── Copilot Chat ──────────────────────────

/** Currently active meeting ID (set after saving a meeting). */
let activeMeetingId = null;

/**
 * Send a copilot query — uses REST API (POST /api/meetings/:id/copilot).
 */
async function sendCopilotQuery() {
    const question = chatInput.value.trim();
    if (!question || copilotWaiting) return;

    const welcome = chatMessages.querySelector('.chat-welcome');
    if (welcome) welcome.remove();

    addChatBubble(question, 'user');
    showTypingIndicator();
    copilotWaiting = true;
    chatSendBtn.disabled = true;
    chatInput.value = '';
    chatInput.focus();

    try {
        const { apiFetch } = await import('../auth/auth.js');
        const meetingId = activeMeetingId || 'live';
        const data = await apiFetch(`/api/meetings/${meetingId}/copilot`, {
            method: 'POST',
            body: JSON.stringify({ question }),
        });
        removeTypingIndicator();
        copilotWaiting = false;
        chatSendBtn.disabled = false;
        addChatBubble(data.answer || data.response || '', 'ai');
    } catch (err) {
        removeTypingIndicator();
        copilotWaiting = false;
        chatSendBtn.disabled = false;
        addChatBubble('⚠️ ' + err.message, 'error');
    }
}

/**
 * Handle copilot response from backend.
 * @param {{ answer: string, error: boolean }} message
 */
function handleCopilotResponse(message) {
    removeTypingIndicator();
    copilotWaiting = false;
    chatSendBtn.disabled = false;

    if (message.error) {
        addChatBubble(message.answer, 'error');
    } else {
        addChatBubble(message.answer, 'ai');
    }

    chatInput.focus();
}

/**
 * Add a chat bubble to the messages area.
 * @param {string} text - Message text
 * @param {'user' | 'ai' | 'error'} sender
 */
function addChatBubble(text, sender) {
    const bubble = document.createElement('div');
    bubble.className = `chat-bubble chat-bubble--${sender}`;

    if (sender === 'ai') {
        bubble.innerHTML = `
      <span class="chat-bubble__label">${t('copilotLabel')}</span>
      <div class="chat-bubble__content">${simpleMarkdown(text)}</div>
    `;
    } else if (sender === 'error') {
        bubble.innerHTML = `
      <span class="chat-bubble__label">${t('copilotError')}</span>
      <div class="chat-bubble__content">${escapeHtml(text)}</div>
    `;
    } else {
        bubble.textContent = text;
    }

    chatMessages.appendChild(bubble);
    chatMessages.scrollTop = chatMessages.scrollHeight;
}

/**
 * Show the typing indicator animation.
 */
function showTypingIndicator() {
    const indicator = document.createElement('div');
    indicator.className = 'typing-indicator';
    indicator.id = 'typing-indicator';
    indicator.innerHTML = `
    <span class="typing-dot"></span>
    <span class="typing-dot"></span>
    <span class="typing-dot"></span>
  `;
    chatMessages.appendChild(indicator);
    chatMessages.scrollTop = chatMessages.scrollHeight;
}

/**
 * Remove the typing indicator.
 */
function removeTypingIndicator() {
    const indicator = document.getElementById('typing-indicator');
    if (indicator) indicator.remove();
}

// Chat input events
chatSendBtn.addEventListener('click', sendCopilotQuery);
chatInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        sendCopilotQuery();
    }
});

// ─── Post-Meeting Summary ──────────────────

const summaryEmpty = document.getElementById('summary-empty');
const summaryLoading = document.getElementById('summary-loading');
const summaryContent = document.getElementById('summary-content');
const summaryTitle = document.getElementById('summary-title');
const summaryText = document.getElementById('summary-text');
const summaryCards = document.getElementById('summary-cards');
const generateSummaryBtn = document.getElementById('generate-summary-btn');
const copySummaryBtn = document.getElementById('copy-summary-btn');

/**
 * Request summary generation — uses REST API (POST /api/meetings/:id/summary).
 */
async function generateSummary() {
    if (!activeMeetingId) {
        summaryEmpty.style.display = 'none';
        summaryLoading.style.display = 'flex';
        summaryContent.style.display = 'none';

        try {
            const { apiFetch } = await import('../auth/auth.js');
            const data = await apiFetch(`/api/meetings/${activeMeetingId}/summary`, {
                method: 'POST',
            });
            summaryLoading.style.display = 'none';
            lastSummaryData = data.summary || data;
            renderSummary(lastSummaryData);
        } catch (err) {
            summaryLoading.style.display = 'none';
            summaryEmpty.style.display = 'flex';
            summaryEmpty.querySelector('.summary-empty__text').innerHTML = `⚠️ ${err.message}`;
        }
        return;
    }
    // Fallback: ask via service worker (WS, legacy)
    summaryEmpty.style.display = 'none';
    summaryLoading.style.display = 'flex';
    summaryContent.style.display = 'none';
    chrome.runtime.sendMessage({ type: 'GENERATE_SUMMARY' });
}

/**
 * Handle summary response from backend.
 * @param {{ summary: object, error: boolean }} message
 */
function handleMeetingSummary(message) {
    summaryLoading.style.display = 'none';

    if (message.error) {
        summaryEmpty.style.display = 'flex';
        const text = summaryEmpty.querySelector('.summary-empty__text');
        text.innerHTML = `⚠️ ${escapeHtml(message.summary?.summary || 'Error generating summary')}`;
        return;
    }

    lastSummaryData = message.summary;
    renderSummary(message.summary);
}

/**
 * Render structured summary with cards.
 * @param {object} data - Meeting summary data
 */
function renderSummary(data) {
    summaryContent.style.display = 'block';
    summaryTitle.textContent = data.title || 'Meeting Summary';
    summaryText.textContent = data.summary || '';
    summaryCards.innerHTML = '';

    // Key Topics
    if (data.key_topics?.length) {
        addCardGroup('🏷️ Key Topics', data.key_topics.map(t => ({
            text: t,
            cssClass: 'summary-card--topic',
        })));
    }

    // Decisions
    if (data.decisions?.length) {
        addCardGroup('📌 Decisions', data.decisions.map(d => ({
            text: d.what,
            meta: d.who ? `By: ${d.who}` : null,
            cssClass: 'summary-card--decision',
        })));
    }

    // Action Items
    if (data.action_items?.length) {
        addCardGroup('✅ Action Items', data.action_items.map(a => ({
            text: a.task,
            meta: [a.owner, a.deadline].filter(Boolean).join(' · ') || null,
            cssClass: 'summary-card--action',
        })));
    }

    // Risks
    if (data.risks?.length) {
        addCardGroup('⚠️ Risks', data.risks.map(r => ({
            text: r.description,
            meta: r.severity ? `Severity: ${r.severity}` : null,
            cssClass: `summary-card--risk-${r.severity || 'medium'}`,
        })));
    }

    // Next Steps
    if (data.next_steps?.length) {
        addCardGroup('🚀 Next Steps', data.next_steps.map(s => ({
            text: s,
            cssClass: 'summary-card--topic',
        })));
    }
}

/**
 * Add a group of cards to the summary.
 * @param {string} title - Group title
 * @param {Array<{text: string, meta?: string, cssClass: string}>} items
 */
function addCardGroup(title, items) {
    const group = document.createElement('div');
    group.className = 'summary-card-group';
    group.innerHTML = `<h4 class="summary-card-group__title">${escapeHtml(title)}</h4>`;

    items.forEach(item => {
        const card = document.createElement('div');
        card.className = `summary-card ${item.cssClass}`;
        card.innerHTML = escapeHtml(item.text)
            + (item.meta ? `<span class="summary-card__meta">${escapeHtml(item.meta)}</span>` : '');
        group.appendChild(card);
    });

    summaryCards.appendChild(group);
}

/**
 * Convert summary data to markdown for clipboard.
 * @param {object} data
 * @returns {string}
 */
function summaryToMarkdown(data) {
    let md = `# ${data.title || 'Meeting Summary'}\n\n`;
    md += `${data.summary || ''}\n\n`;

    if (data.key_topics?.length) {
        md += `## Key Topics\n`;
        data.key_topics.forEach(t => { md += `- ${t}\n`; });
        md += '\n';
    }

    if (data.decisions?.length) {
        md += `## Decisions\n`;
        data.decisions.forEach(d => {
            md += `- **${d.what}**${d.who ? ` (${d.who})` : ''}\n`;
        });
        md += '\n';
    }

    if (data.action_items?.length) {
        md += `## Action Items\n`;
        data.action_items.forEach(a => {
            md += `- [ ] ${a.task}`;
            if (a.owner) md += ` — @${a.owner}`;
            if (a.deadline) md += ` (${a.deadline})`;
            md += '\n';
        });
        md += '\n';
    }

    if (data.risks?.length) {
        md += `## Risks\n`;
        data.risks.forEach(r => {
            const badge = { high: '🔴', medium: '🟡', low: '🟢' }[r.severity] || '⚪';
            md += `- ${badge} ${r.description}\n`;
        });
        md += '\n';
    }

    if (data.next_steps?.length) {
        md += `## Next Steps\n`;
        data.next_steps.forEach(s => { md += `- ${s}\n`; });
    }

    return md;
}

/**
 * Copy summary as markdown to clipboard.
 */
async function copySummaryAsMarkdown() {
    if (!lastSummaryData) return;

    const md = summaryToMarkdown(lastSummaryData);
    await navigator.clipboard.writeText(md);

    // Visual feedback
    copySummaryBtn.textContent = t('summaryCopied');
    copySummaryBtn.classList.add('summary-copy-btn--copied');
    setTimeout(() => {
        copySummaryBtn.textContent = t('summaryCopy');
        copySummaryBtn.classList.remove('summary-copy-btn--copied');
    }, 2000);
}

// Summary button events
generateSummaryBtn.addEventListener('click', generateSummary);
copySummaryBtn.addEventListener('click', copySummaryAsMarkdown);

// ─── Connection Badge ──────────────────────

/**
 * Update connection badge.
 * @param {'connected' | 'connecting' | 'disconnected'} status
 */
function updateConnectionBadge(status) {
    connBadge.className = `badge badge--${status}`;
    const text = connBadge.querySelector('.badge-text');
    const labels = {
        connected: t('connLive'),
        connecting: t('connConnecting'),
        disconnected: t('connOffline'),
    };
    text.textContent = labels[status] || t('connOffline');
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
    backendUrl = backendUrlInput.value.trim() || 'wss://api.aurameet.live/ws';
    await chrome.storage.local.set({ backendUrl });

    // Save language selections
    if (uiLanguageSelect) {
        await setLocale(uiLanguageSelect.value);
    }
    if (transcriptionLanguageSelect) {
        await setTranscriptionLanguage(transcriptionLanguageSelect.value);
    }

    settingsModal.style.display = 'none';
    statusText.textContent = t('settingsSaved');
});

// ─── Cost Tracking ─────────────────────────

/**
 * Handle cost update from backend.
 * @param {{ total_cost_usd: number, budget_usd: number, budget_remaining_usd: number, budget_pct: number }} message
 */
function handleCostUpdate(message) {
    costBar.style.display = 'block';

    const cost = (message.total_cost_usd || 0).toFixed(3);
    const remaining = (message.budget_remaining_usd || 0).toFixed(2);
    const pct = Math.min((message.budget_pct || 0) * 100, 100);

    costValue.textContent = `$${cost}`;
    costBudget.textContent = `$${remaining} left`;
    costFill.style.width = `${pct}%`;

    // Color coding: green < 50%, yellow < 80%, red >= 80%
    if (pct >= 80) {
        costFill.className = 'cost-bar__fill cost-bar__fill--danger';
        costValue.className = 'cost-bar__value cost-bar__value--danger';
    } else if (pct >= 50) {
        costFill.className = 'cost-bar__fill cost-bar__fill--warning';
        costValue.className = 'cost-bar__value cost-bar__value--warning';
    } else {
        costFill.className = 'cost-bar__fill';
        costValue.className = 'cost-bar__value';
    }
}

/**
 * Handle budget exceeded notification.
 * @param {{ message: string }} message
 */
function handleBudgetExceeded(message) {
    costFill.style.width = '100%';
    costFill.className = 'cost-bar__fill cost-bar__fill--danger';
    costValue.className = 'cost-bar__value cost-bar__value--danger';
    costBudget.textContent = '⚠️ Budget exceeded';
    statusText.textContent = '🚫 ' + (message.message || 'Budget limit reached');
}

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

/**
 * Convert simple markdown to HTML for AI responses.
 * Supports: **bold**, - bullet lists, and line breaks.
 * @param {string} text
 * @returns {string}
 */
function simpleMarkdown(text) {
    let html = escapeHtml(text);
    // **bold**
    html = html.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
    // - bullet items (line by line)
    html = html.replace(/^- (.+)$/gm, '<li>$1</li>');
    html = html.replace(/(<li>.*<\/li>)/gs, '<ul>$1</ul>');
    // Clean double <ul> nesting
    html = html.replace(/<\/ul>\s*<ul>/g, '');
    // Newlines → <br>
    html = html.replace(/\n/g, '<br>');
    // Clean <br> inside <ul>
    html = html.replace(/<ul><br>/g, '<ul>');
    html = html.replace(/<br><\/ul>/g, '</ul>');
    return html;
}
