/**
 * MeetMind Chrome Extension — Offscreen Document.
 *
 * Runs in a DOM context (required for audio capture).
 * Receives MediaStream via streamId, captures raw PCM audio
 * using AudioContext, and streams it to the MeetMind backend
 * via WebSocket as Float32 arrays — zero encoding overhead.
 */

/** @type {WebSocket|null} */
let ws = null;

/** @type {MediaStream|null} */
let mediaStream = null;

/** @type {AudioContext|null} */
let audioCtx = null;

/** @type {ScriptProcessorNode|null} */
let processor = null;

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

        case 'OFFSCREEN_COPILOT_QUERY':
            // Send copilot query through the active WebSocket
            if (ws?.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({
                    type: 'copilot_query',
                    question: message.question,
                }));
            } else {
                notifyServiceWorker('COPILOT_RESPONSE', {
                    answer: '⚠️ WebSocket not connected',
                    error: true,
                });
            }
            return false;

        case 'OFFSCREEN_GENERATE_SUMMARY':
            // Send summary request through the active WebSocket
            if (ws?.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({
                    type: 'generate_summary',
                }));
            } else {
                notifyServiceWorker('MEETING_SUMMARY', {
                    error: true,
                    summary: { title: 'Error', summary: '⚠️ WebSocket not connected' },
                });
            }
            return false;

        default:
            return false;
    }
});

// ─── Audio Processing ──────────────────────

/**
 * Start capturing and streaming raw PCM audio.
 * Uses AudioContext to capture 16kHz mono Float32 PCM
 * and send directly over WebSocket — zero encoding latency.
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

    // Start raw PCM streaming via AudioContext
    startPCMStreaming();
}

/**
 * Start capturing raw PCM from the MediaStream and sending
 * Float32 samples directly over WebSocket.
 *
 * AudioContext at 16kHz → ScriptProcessor (4096 samples = ~256ms)
 * → sends raw Float32Array binary → backend appends to numpy buffer.
 *
 * This eliminates:
 * - WebM encoding in browser (~50ms)
 * - ffmpeg subprocess spawn + decode on backend (~200-500ms)
 */
function startPCMStreaming() {
    if (!mediaStream) return;

    // Create AudioContext at Whisper's native sample rate
    audioCtx = new AudioContext({ sampleRate: 16000 });
    const source = audioCtx.createMediaStreamSource(mediaStream);

    // ScriptProcessor: 4096 samples at 16kHz = ~256ms per buffer
    processor = audioCtx.createScriptProcessor(4096, 1, 1);
    source.connect(processor);
    processor.connect(audioCtx.destination);

    processor.onaudioprocess = (event) => {
        if (ws?.readyState !== WebSocket.OPEN) return;

        const pcmData = event.inputBuffer.getChannelData(0);

        // Quick silence check (skip empty buffers)
        let sum = 0;
        for (let i = 0; i < pcmData.length; i += 64) {
            sum += pcmData[i] * pcmData[i];
        }
        const rms = Math.sqrt(sum / (pcmData.length / 64));
        if (rms < 0.001) return; // Silence — don't waste bandwidth

        // Send raw Float32 PCM directly (no encoding!)
        ws.send(pcmData.buffer.slice(0));
    };
}

/**
 * Stop everything cleanly.
 */
function stopProcessing() {
    // Stop audio processor
    if (processor) {
        processor.disconnect();
        processor = null;
    }

    // Close AudioContext
    if (audioCtx) {
        audioCtx.close().catch(() => { });
        audioCtx = null;
    }

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
                    speaker: message.speaker || 'unknown',
                    speaker_color: message.speaker_color || '#6B7280',
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

        case 'copilot_response':
            notifyServiceWorker('COPILOT_RESPONSE', {
                answer: message.answer,
                latency_ms: message.latency_ms,
                error: message.error || false,
            });
            break;

        case 'meeting_summary':
            notifyServiceWorker('MEETING_SUMMARY', {
                summary: message.summary,
                latency_ms: message.latency_ms,
                error: message.error || false,
            });
            break;

        case 'pong':
            break;

        case 'cost_update':
            notifyServiceWorker('COST_UPDATE', {
                total_cost_usd: message.total_cost_usd,
                budget_usd: message.budget_usd,
                budget_remaining_usd: message.budget_remaining_usd,
                budget_pct: message.budget_pct,
                total_requests: message.total_requests,
            });
            break;

        case 'budget_exceeded':
            notifyServiceWorker('BUDGET_EXCEEDED', {
                message: message.message,
            });
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


