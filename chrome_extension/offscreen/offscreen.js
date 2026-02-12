/**
 * MeetMind Chrome Extension — Offscreen Document.
 *
 * Runs in a DOM context (required for MediaRecorder).
 * Receives MediaStream via streamId, records audio,
 * and streams to the MeetMind backend via WebSocket.
 *
 * Uses stop/start recording to ensure each webm blob
 * has a complete container header for ffmpeg conversion.
 */

/** @type {MediaRecorder|null} */
let mediaRecorder = null;

/** @type {WebSocket|null} */
let ws = null;

/** @type {MediaStream|null} */
let mediaStream = null;

/** @type {number|null} */
let recordingInterval = null;

/** Recording cycle duration in ms (5s for better transcription). */
const CYCLE_DURATION_MS = 5000;

// ─── Message Handling ──────────────────────

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    switch (message.type) {
        case 'OFFSCREEN_START':
            startProcessing(message.streamId, message.backendUrl)
                .then(() => sendResponse({ success: true }))
                .catch(err => sendResponse({ success: false, error: err.message }));
            return true;

        case 'OFFSCREEN_STOP':
            stopProcessing();
            sendResponse({ success: true });
            return false;

        default:
            return false;
    }
});

// ─── Audio Processing ──────────────────────

/**
 * Start capturing and streaming audio.
 * @param {string} streamId Tab capture stream ID
 * @param {string} backendUrl WebSocket URL
 */
async function startProcessing(streamId, backendUrl) {
    // Get the MediaStream from the tab
    mediaStream = await navigator.mediaDevices.getUserMedia({
        audio: {
            mandatory: {
                chromeMediaSource: 'tab',
                chromeMediaSourceId: streamId,
            },
        },
        video: false,
    });

    // Play audio back so the tab isn't silenced during capture
    const audioPlayback = document.createElement('audio');
    audioPlayback.srcObject = mediaStream;
    audioPlayback.play();

    // Connect WebSocket
    connectWebSocket(backendUrl);

    // Start the recording cycle
    startRecordingCycle();
}

/**
 * Start a stop/start MediaRecorder cycle.
 * Each cycle produces a complete webm blob with headers.
 */
function startRecordingCycle() {
    if (!mediaStream) return;

    startNewRecording();

    // Every CYCLE_DURATION_MS, stop recording (triggers ondataavailable)
    // then start a new recording for the next cycle
    recordingInterval = setInterval(() => {
        if (mediaRecorder && mediaRecorder.state === 'recording') {
            mediaRecorder.stop(); // triggers ondataavailable with complete webm
        }
        // Start a new recording for the next interval
        startNewRecording();
    }, CYCLE_DURATION_MS);
}

/**
 * Create and start a new MediaRecorder instance.
 */
function startNewRecording() {
    if (!mediaStream || mediaStream.getTracks().every(t => t.readyState === 'ended')) {
        return;
    }

    mediaRecorder = new MediaRecorder(mediaStream, {
        mimeType: getSupportedMimeType(),
    });

    mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0 && ws?.readyState === WebSocket.OPEN) {
            ws.send(event.data);
        }
    };

    mediaRecorder.start(); // No timeslice — entire recording until stop()
}

/**
 * Stop everything cleanly.
 */
function stopProcessing() {
    // Stop recording cycle
    if (recordingInterval) {
        clearInterval(recordingInterval);
        recordingInterval = null;
    }

    // Stop recorder
    if (mediaRecorder && mediaRecorder.state !== 'inactive') {
        mediaRecorder.stop();
    }
    mediaRecorder = null;

    // Stop all tracks
    if (mediaStream) {
        mediaStream.getTracks().forEach(track => track.stop());
        mediaStream = null;
    }

    // Close WebSocket
    if (ws) {
        ws.close(1000, 'User stopped capture');
        ws = null;
    }
}

// ─── WebSocket ─────────────────────────────

/**
 * Connect to the MeetMind backend.
 * @param {string} url WebSocket URL
 */
function connectWebSocket(url) {
    ws = new WebSocket(url);

    ws.onopen = () => {
        console.log('[MeetMind Offscreen] WebSocket connected');
        notifyServiceWorker('CONNECTION_STATUS', { status: 'connected' });
    };

    ws.onmessage = (event) => {
        try {
            const message = JSON.parse(event.data);
            handleBackendMessage(message);
        } catch {
            console.warn('[MeetMind Offscreen] Non-JSON message:', event.data);
        }
    };

    ws.onerror = (error) => {
        console.error('[MeetMind Offscreen] WebSocket error:', error);
        notifyServiceWorker('CONNECTION_STATUS', { status: 'disconnected' });
    };

    ws.onclose = () => {
        console.log('[MeetMind Offscreen] WebSocket closed');
        notifyServiceWorker('CONNECTION_STATUS', { status: 'disconnected' });
    };

    notifyServiceWorker('CONNECTION_STATUS', { status: 'connecting' });
}

/**
 * Handle messages from the backend.
 * @param {object} message Parsed JSON from backend
 */
function handleBackendMessage(message) {
    switch (message.type) {
        case 'connected':
            notifyServiceWorker('CONNECTION_STATUS', { status: 'connected' });
            break;

        case 'transcript_ack':
            // Backend transcribed audio — forward text to popup
            if (message.text) {
                notifyServiceWorker('TRANSCRIPT', {
                    text: message.text,
                    partial: message.partial || false,
                });
            }
            break;

        case 'screening':
            notifyServiceWorker('SCREENING', {
                relevant: message.relevant,
                reason: message.reason,
            });
            break;

        case 'analysis':
            if (message.insight) {
                notifyServiceWorker('INSIGHT', {
                    title: message.insight.title,
                    analysis: message.insight.analysis,
                    recommendation: message.insight.recommendation,
                    category: message.insight.category,
                });
            }
            break;

        case 'pong':
            break;
    }
}

// ─── Utilities ─────────────────────────────

/**
 * Forward a message through the service worker to the popup.
 * @param {string} type Message type
 * @param {object} data Additional data
 */
function notifyServiceWorker(type, data = {}) {
    chrome.runtime.sendMessage({ type, ...data }).catch(() => {
        // Service worker or popup might be unavailable
    });
}

/**
 * Get a supported audio MIME type.
 * @returns {string}
 */
function getSupportedMimeType() {
    const types = [
        'audio/webm;codecs=opus',
        'audio/webm',
        'audio/ogg;codecs=opus',
    ];

    for (const type of types) {
        if (MediaRecorder.isTypeSupported(type)) {
            return type;
        }
    }

    return ''; // Let browser pick default
}
