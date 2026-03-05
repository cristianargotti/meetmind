/**
 * Aura Meet Chrome Extension — History & Actions module.
 * Loaded as ES module from popup.js.
 */

import { apiFetch } from '../auth/auth.js';

// ─── State ─────────────────────────────────────────────

let allMeetings = [];
let activeMeetingIdRef = null;

// ─── Init ──────────────────────────────────────────────

export function initHistory(setActiveMeetingId) {
    activeMeetingIdRef = setActiveMeetingId;

    const historyNav = document.getElementById('history-nav');
    const sectionHistory = document.getElementById('section-history');
    const sectionActions = document.getElementById('section-actions');

    if (!historyNav) return;

    // Sub-tab switching
    historyNav.querySelectorAll('.tab').forEach(tab => {
        tab.addEventListener('click', () => {
            historyNav.querySelectorAll('.tab').forEach(t => t.classList.remove('tab--active'));
            tab.classList.add('tab--active');
            const section = tab.dataset.section;
            sectionHistory.style.display = section === 'history' ? 'block' : 'none';
            sectionActions.style.display = section === 'actions' ? 'block' : 'none';
            if (section === 'history') loadHistory();
            if (section === 'actions') loadActions();
        });
    });

    // Load history on startup
    loadHistory();

    // Search filter
    const searchInput = document.getElementById('history-search');
    if (searchInput) {
        searchInput.addEventListener('input', () => {
            const q = searchInput.value.toLowerCase();
            renderMeetings(q ? allMeetings.filter(m => (m.title || '').toLowerCase().includes(q)) : allMeetings);
        });
    }
}

// ─── History ───────────────────────────────────────────

async function loadHistory() {
    const list = document.getElementById('history-list');
    const empty = document.getElementById('history-empty');
    if (!list) return;

    empty.style.display = 'none';
    list.innerHTML = '<div style="padding:24px;text-align:center;color:var(--text-tertiary);font-size:13px;">Loading...</div>';

    try {
        const data = await apiFetch('/api/meetings?limit=50&offset=0');
        allMeetings = data.meetings || [];
        renderMeetings(allMeetings);
    } catch (err) {
        list.innerHTML = `<div style="padding:24px;text-align:center;color:var(--danger);font-size:13px;">⚠️ ${err.message}</div>`;
    }
}

function renderMeetings(meetings) {
    const list = document.getElementById('history-list');
    const empty = document.getElementById('history-empty');
    list.innerHTML = '';

    if (!meetings.length) {
        empty.style.display = 'flex';
        list.appendChild(empty);
        return;
    }
    meetings.forEach(m => list.appendChild(buildMeetingCard(m)));
}

function buildMeetingCard(meeting) {
    const isCompleted = meeting.status === 'completed';
    const duration = meeting.duration_secs || 0;
    const durationStr = duration > 0 ? `${Math.floor(duration / 60)}m ${duration % 60}s` : '< 1m';

    let dateStr = '';
    if (meeting.started_at) {
        try {
            const dt = new Date(meeting.started_at);
            dateStr = dt.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
                + '  ·  '
                + dt.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' });
        } catch (_) { }
    }

    const card = document.createElement('div');
    card.className = 'meeting-card';
    card.innerHTML = `
        <div class="meeting-card__header">
            <span class="meeting-card__dot meeting-card__dot--${isCompleted ? 'completed' : 'active'}"></span>
            <span class="meeting-card__title">${esc(meeting.title || 'Untitled Meeting')}</span>
            <span class="meeting-card__chevron">›</span>
        </div>
        ${dateStr ? `<div class="meeting-card__date">📅 ${esc(dateStr)}</div>` : ''}
        <div class="meeting-card__stats">
            <span class="stat-chip"><span class="stat-chip__icon">⏱</span>${durationStr}</span>
            <span class="stat-chip"><span class="stat-chip__icon">📝</span>${meeting.total_segments || 0}</span>
            <span class="stat-chip"><span class="stat-chip__icon">💡</span>${meeting.total_insights || 0}</span>
        </div>`;

    card.addEventListener('click', () => openMeeting(meeting));
    return card;
}

function openMeeting(meeting) {
    if (activeMeetingIdRef) activeMeetingIdRef(meeting.id);

    // Show the live tabs for this meeting's AI features
    document.getElementById('history-nav').style.display = 'none';
    document.getElementById('section-history').style.display = 'none';
    document.getElementById('section-actions').style.display = 'none';
    document.getElementById('tab-nav').style.display = 'flex';

    // Default to Summary tab for a past meeting
    const summaryTab = document.querySelector('[data-tab="summary"]');
    if (summaryTab) summaryTab.click();
}

// ─── Actions ───────────────────────────────────────────

async function loadActions() {
    const list = document.getElementById('actions-list');
    const empty = document.getElementById('actions-empty');
    if (!list) return;

    empty.style.display = 'none';
    list.innerHTML = '<div style="padding:24px;text-align:center;color:var(--text-tertiary);font-size:13px;">Loading...</div>';

    try {
        const data = await apiFetch('/api/meetings?limit=10&offset=0');
        const meetings = (data.meetings || []).slice(0, 5);
        const allActions = [];

        for (const m of meetings) {
            try {
                const detail = await apiFetch(`/api/meetings/${m.id}`);
                (detail.summary?.action_items || []).forEach(item => {
                    allActions.push({ ...item, meetingTitle: m.title });
                });
            } catch (_) { }
        }

        const pending = allActions.filter(a => !a.done);
        list.innerHTML = '';
        if (!pending.length) {
            empty.style.display = 'flex';
            list.appendChild(empty);
            return;
        }
        pending.forEach((action, i) => list.appendChild(buildActionItem(action, i)));
    } catch (err) {
        list.innerHTML = `<div style="padding:24px;text-align:center;color:var(--danger);font-size:13px;">⚠️ ${err.message}</div>`;
    }
}

function buildActionItem(action, idx) {
    const item = document.createElement('div');
    item.className = 'action-item';
    const meta = [action.owner, action.deadline].filter(Boolean).join(' · ');
    item.innerHTML = `
        <div class="action-item__checkbox" id="act-cb-${idx}"></div>
        <div>
            <div class="action-item__text">${esc(action.task || action.text || '')}</div>
            ${meta ? `<div class="action-item__meta">${esc(meta)}</div>` : ''}
            <div class="action-item__meta" style="color:var(--text-tertiary)">${esc(action.meetingTitle || '')}</div>
        </div>`;

    item.querySelector(`#act-cb-${idx}`).addEventListener('click', function () {
        this.classList.add('action-item__checkbox--done');
        item.style.opacity = '0.4';
    });

    return item;
}

function esc(text) {
    const d = document.createElement('div');
    d.textContent = String(text);
    return d.innerHTML;
}
