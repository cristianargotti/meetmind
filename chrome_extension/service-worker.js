/**
 * MeetMind Chrome Extension — Service Worker (MV3).
 *
 * Manages the extension lifecycle:
 *   - Tab audio capture via chrome.tabCapture
 *   - Offscreen Document creation for MediaRecorder
 *   - Message routing between popup ↔ offscreen
 */

/** @type {boolean} Whether we're currently capturing audio. */
let isCapturing = false;

/** @type {number|null} Tab ID currently being captured. */
let capturedTabId = null;

/** @type {number|null} Panel window ID for reuse. */
let panelWindowId = null;

/** @type {number|null} The tab the user was on when they clicked the icon. */
let sourceTabId = null;

// ─── Panel Window (movable + resizable) ────

chrome.action.onClicked.addListener(async (tab) => {
  // Remember which tab the user wants to capture
  sourceTabId = tab.id ?? null;

  // If panel already exists, focus it
  if (panelWindowId !== null) {
    try {
      const existing = await chrome.windows.get(panelWindowId);
      if (existing) {
        await chrome.windows.update(panelWindowId, { focused: true });
        return;
      }
    } catch (e) {
      panelWindowId = null;
    }
  }

  // Also check storage in case SW restarted and lost in-memory value
  const stored = await chrome.storage.local.get('panelWindowId');
  if (stored.panelWindowId) {
    try {
      const existing = await chrome.windows.get(stored.panelWindowId);
      if (existing) {
        panelWindowId = stored.panelWindowId;
        await chrome.windows.update(panelWindowId, { focused: true });
        return;
      }
    } catch (e) {
      // Window no longer exists
    }
  }

  const panelUrl = chrome.runtime.getURL('popup/popup.html');
  const panel = await chrome.windows.create({
    url: panelUrl,
    type: 'popup',
    width: 520,
    height: 650,
    top: 80,
    left: 900,
  });

  panelWindowId = panel.id ?? null;
  await chrome.storage.local.set({ panelWindowId });
});

// Clean up reference when panel is closed
chrome.windows.onRemoved.addListener((windowId) => {
  if (windowId === panelWindowId) {
    panelWindowId = null;
    chrome.storage.local.remove('panelWindowId');
  }
});

// ─── Message Handling ──────────────────────

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  switch (message.type) {
    case 'START_CAPTURE':
      handleStartCapture(message.backendUrl).then(result => {
        sendResponse(result);
      });
      return true; // async response

    case 'STOP_CAPTURE':
      handleStopCapture().then(result => {
        sendResponse(result);
      });
      return true;

    case 'GET_STATUS':
      sendResponse({
        isCapturing,
        capturedTabId,
        sourceTabId,
      });
      return false;

    case 'COPILOT_QUERY':
      // Forward copilot question from popup → offscreen (WebSocket)
      chrome.runtime.sendMessage({
        type: 'OFFSCREEN_COPILOT_QUERY',
        question: message.question,
      }).catch(() => {
        // Offscreen might not exist — send error back to popup
        chrome.runtime.sendMessage({
          type: 'COPILOT_RESPONSE',
          answer: '⚠️ Not connected. Start capture first.',
          error: true,
        }).catch(() => { });
      });
      return false;

    case 'GENERATE_SUMMARY':
      // Forward summary request from popup → offscreen (WebSocket)
      chrome.runtime.sendMessage({
        type: 'OFFSCREEN_GENERATE_SUMMARY',
      }).catch(() => {
        chrome.runtime.sendMessage({
          type: 'MEETING_SUMMARY',
          error: true,
          summary: { title: 'Error', summary: '⚠️ Not connected. Start capture first.' },
        }).catch(() => { });
      });
      return false;

    case 'INSIGHT':
    case 'TRANSCRIPT':
    case 'SCREENING':
    case 'COPILOT_RESPONSE':
    case 'MEETING_SUMMARY':
    case 'CONNECTION_STATUS':
    case 'COST_UPDATE':
    case 'BUDGET_EXCEEDED':
      // Forward from offscreen → popup
      chrome.runtime.sendMessage(message).catch(() => {
        // Popup might be closed — ignore
      });
      return false;

    default:
      return false;
  }
});

// ─── Tab Capture ───────────────────────────

/**
 * Start capturing audio from the active tab.
 * @param {string} backendUrl WebSocket backend URL
 * @returns {Promise<{success: boolean, error?: string}>}
 */
async function handleStartCapture(backendUrl) {
  if (isCapturing) {
    return { success: false, error: 'Already capturing' };
  }

  try {
    // Use the stored source tab (from icon click) instead of querying
    let targetTabId = sourceTabId;

    if (!targetTabId) {
      // Fallback: find the last focused normal window's active tab
      const windows = await chrome.windows.getAll({ windowTypes: ['normal'] });
      for (const win of windows) {
        if (win.focused) {
          const tabs = await chrome.tabs.query({ active: true, windowId: win.id });
          if (tabs[0]?.id) {
            targetTabId = tabs[0].id;
            break;
          }
        }
      }
    }

    if (!targetTabId) {
      return { success: false, error: 'No source tab found. Click the MeetMind icon while on the tab you want to capture.' };
    }

    // Get a MediaStream from the tab
    const streamId = await chrome.tabCapture.getMediaStreamId({
      targetTabId: targetTabId,
    });

    // Create offscreen document if needed
    await ensureOffscreenDocument();

    // Send stream ID to offscreen for processing
    await chrome.runtime.sendMessage({
      type: 'OFFSCREEN_START',
      streamId,
      backendUrl: backendUrl || 'ws://localhost:8000/ws',
    });

    isCapturing = true;
    capturedTabId = targetTabId;

    // Store state
    await chrome.storage.local.set({ isCapturing: true, capturedTabId: targetTabId });

    return { success: true };
  } catch (error) {
    console.error('[MeetMind SW] Capture error:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Stop the current audio capture.
 * @returns {Promise<{success: boolean}>}
 */
async function handleStopCapture() {
  if (!isCapturing) {
    return { success: true };
  }

  try {
    await chrome.runtime.sendMessage({ type: 'OFFSCREEN_STOP' });
  } catch {
    // Offscreen might already be closed
  }

  isCapturing = false;
  capturedTabId = null;
  await chrome.storage.local.set({ isCapturing: false, capturedTabId: null });

  // Close offscreen document
  try {
    await chrome.offscreen.closeDocument();
  } catch {
    // Might not exist
  }

  return { success: true };
}

// ─── Offscreen Document ────────────────────

/**
 * Ensure the offscreen document exists.
 * MV3 allows only one offscreen document at a time.
 */
async function ensureOffscreenDocument() {
  // Check if one already exists
  try {
    const contexts = await chrome.runtime.getContexts({
      contextTypes: ['OFFSCREEN_DOCUMENT'],
    });

    if (contexts.length > 0) {
      return; // Already exists
    }
  } catch (e) {
    // getContexts might fail — try to close stale doc first
    try {
      await chrome.offscreen.closeDocument();
    } catch {
      // No document to close
    }
  }

  try {
    await chrome.offscreen.createDocument({
      url: 'offscreen/offscreen.html',
      reasons: ['USER_MEDIA'],
      justification: 'MeetMind needs to process tab audio via MediaRecorder',
    });
  } catch (e) {
    if (e.message?.includes('single offscreen document')) {
      // Already exists — race condition, safe to ignore
      console.warn('[MeetMind SW] Offscreen document already exists, reusing.');
    } else {
      throw e;
    }
  }
}

// ─── Lifecycle ─────────────────────────────

// Restore state on service worker restart
chrome.storage.local.get(['isCapturing', 'capturedTabId'], (data) => {
  if (data.isCapturing) {
    // Service worker restarted mid-capture — mark as stopped
    // (MediaStream is lost when SW restarts)
    chrome.storage.local.set({ isCapturing: false, capturedTabId: null });
    isCapturing = false;
    capturedTabId = null;
  }
});

// Tab closed → stop capture
chrome.tabs.onRemoved.addListener((tabId) => {
  if (tabId === capturedTabId) {
    handleStopCapture();
  }
});
