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
      });
      return false;

    case 'INSIGHT':
    case 'TRANSCRIPT':
    case 'SCREENING':
    case 'CONNECTION_STATUS':
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
    // Get the active tab
    const [tab] = await chrome.tabs.query({
      active: true,
      currentWindow: true,
    });

    if (!tab?.id) {
      return { success: false, error: 'No active tab found' };
    }

    // Get a MediaStream from the tab
    const streamId = await chrome.tabCapture.getMediaStreamId({
      targetTabId: tab.id,
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
    capturedTabId = tab.id;

    // Store state
    await chrome.storage.local.set({ isCapturing: true, capturedTabId: tab.id });

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
  const contexts = await chrome.runtime.getContexts({
    contextTypes: ['OFFSCREEN_DOCUMENT'],
  });

  if (contexts.length > 0) {
    return; // Already exists
  }

  await chrome.offscreen.createDocument({
    url: 'offscreen/offscreen.html',
    reasons: ['USER_MEDIA'],
    justification: 'MeetMind needs to process tab audio via MediaRecorder',
  });
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
