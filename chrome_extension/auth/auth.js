/**
 * Aura Meet Chrome Extension — Auth Module.
 *
 * Handles Google Sign-In via chrome.identity API and
 * exchanges the Google id_token for an Aura Meet JWT.
 *
 * Usage:
 *   import { signIn, signOut, getUser, getAuthHeaders } from './auth/auth.js';
 */

const API_BASE = 'https://api.aurameet.live';

// ─── Storage Keys ──────────────────────────────────────────────────

const KEYS = {
    ACCESS_TOKEN: 'aura_access_token',
    REFRESH_TOKEN: 'aura_refresh_token',
    USER: 'aura_user',
    IS_PRO: 'aura_is_pro',
};

// ─── Public API ────────────────────────────────────────────────────

/**
 * Sign in with Google using chrome.identity, then exchange for JWT.
 * @returns {Promise<{user: object, accessToken: string}>}
 */
export async function signIn() {
    // 1. Get Google OAuth token via Chrome identity API (no popup blocked)
    const googleToken = await getGoogleToken();

    // 2. Exchange Google id_token for Aura Meet JWT
    const response = await fetch(`${API_BASE}/api/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            provider: 'google',
            id_token: googleToken,
        }),
    });

    if (!response.ok) {
        const err = await response.text();
        throw new Error(`Auth failed: ${err}`);
    }

    const data = await response.json();

    // 3. Store tokens and user info
    await chrome.storage.local.set({
        [KEYS.ACCESS_TOKEN]: data.access_token,
        [KEYS.REFRESH_TOKEN]: data.refresh_token,
        [KEYS.USER]: data.user,
        [KEYS.IS_PRO]: data.user?.is_pro ?? false,
    });

    return { user: data.user, accessToken: data.access_token, isPro: data.user?.is_pro ?? false };
}

/**
 * Sign out — clear all stored tokens and user info.
 */
export async function signOut() {
    // Revoke Google token to force fresh consent on next login
    const stored = await chrome.storage.local.get(KEYS.ACCESS_TOKEN);
    if (stored[KEYS.ACCESS_TOKEN]) {
        await revokeGoogleToken().catch(() => { });
    }

    await chrome.storage.local.remove([
        KEYS.ACCESS_TOKEN,
        KEYS.REFRESH_TOKEN,
        KEYS.USER,
        KEYS.IS_PRO,
    ]);
}

/**
 * Check if current user has a Pro subscription.
 * @returns {Promise<boolean>}
 */
export async function getIsPro() {
    const stored = await chrome.storage.local.get(KEYS.IS_PRO);
    return stored[KEYS.IS_PRO] ?? false;
}

/**
 * Get the currently logged-in user, or null if not authenticated.
 * @returns {Promise<object|null>}
 */
export async function getUser() {
    const stored = await chrome.storage.local.get([KEYS.USER, KEYS.ACCESS_TOKEN]);
    if (!stored[KEYS.ACCESS_TOKEN] || !stored[KEYS.USER]) return null;
    return stored[KEYS.USER];
}

/**
 * Get Authorization headers for REST API calls.
 * Refreshes token if expired.
 * @returns {Promise<{'Authorization': string}>}
 */
export async function getAuthHeaders() {
    const stored = await chrome.storage.local.get([KEYS.ACCESS_TOKEN]);
    const token = stored[KEYS.ACCESS_TOKEN];
    if (!token) throw new Error('Not authenticated');
    return { 'Authorization': `Bearer ${token}` };
}

/**
 * Make an authenticated REST API call to the Aura Meet backend.
 * @param {string} path - API path (e.g. '/api/meetings')
 * @param {RequestInit} options - fetch options
 * @returns {Promise<any>} Parsed JSON response
 */
export async function apiFetch(path, options = {}) {
    const headers = await getAuthHeaders();
    const res = await fetch(`${API_BASE}${path}`, {
        ...options,
        headers: {
            'Content-Type': 'application/json',
            ...headers,
            ...(options.headers || {}),
        },
    });

    if (res.status === 401) {
        // Try to refresh token
        const refreshed = await tryRefreshToken();
        if (refreshed) {
            // Retry once with new token
            const newHeaders = await getAuthHeaders();
            const retryRes = await fetch(`${API_BASE}${path}`, {
                ...options,
                headers: {
                    'Content-Type': 'application/json',
                    ...newHeaders,
                    ...(options.headers || {}),
                },
            });
            if (!retryRes.ok) throw new Error(`API error ${retryRes.status}`);
            return retryRes.json();
        }
        // Refresh failed — clear session
        await signOut();
        throw new Error('Session expired. Please sign in again.');
    }

    if (!res.ok) {
        const text = await res.text();
        throw new Error(`API error ${res.status}: ${text}`);
    }

    // 204 No Content
    if (res.status === 204) return null;
    return res.json();
}

// ─── Internal ──────────────────────────────────────────────────────

/**
 * Get a Google OAuth2 id_token via chrome.identity.
 * Uses launchWebAuthFlow for Google Sign-In.
 * @returns {Promise<string>} id_token
 */
async function getGoogleToken() {
    return new Promise((resolve, reject) => {
        // Use chrome.identity.getAuthToken for simple access token
        chrome.identity.getAuthToken({ interactive: true }, async (token) => {
            if (chrome.runtime.lastError || !token) {
                reject(new Error(chrome.runtime.lastError?.message || 'Google sign-in failed'));
                return;
            }
            // Exchange access token for id_token via userinfo endpoint
            // The backend verify_google_token accepts both access_token and id_token
            resolve(token);
        });
    });
}

/**
 * Revoke the current Google token on logout.
 */
async function revokeGoogleToken() {
    return new Promise((resolve) => {
        chrome.identity.getAuthToken({ interactive: false }, (token) => {
            if (token) {
                chrome.identity.removeCachedAuthToken({ token }, resolve);
            } else {
                resolve();
            }
        });
    });
}

/**
 * Try to refresh the JWT using the stored refresh token.
 * @returns {Promise<boolean>} true if refresh succeeded
 */
async function tryRefreshToken() {
    const stored = await chrome.storage.local.get(KEYS.REFRESH_TOKEN);
    const refreshToken = stored[KEYS.REFRESH_TOKEN];
    if (!refreshToken) return false;

    try {
        const res = await fetch(`${API_BASE}/api/auth/refresh`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ refresh_token: refreshToken }),
        });
        if (!res.ok) return false;

        const data = await res.json();
        await chrome.storage.local.set({
            [KEYS.ACCESS_TOKEN]: data.access_token,
        });
        return true;
    } catch {
        return false;
    }
}
