/**
 * Aura Meet Chrome Extension — i18n System.
 *
 * Mirrors the Flutter app's ARB translation files (EN/ES/PT).
 * Persists language choice in chrome.storage.local.
 * Auto-detects browser language on first use.
 */

// ─── Translation Dictionaries ──────────────

const translations = {
    en: {
        // Header
        appTitle: 'Aura Meet',

        // Capture
        captureStart: 'Start Capture',
        captureStop: 'Stop Capture',
        captureReady: 'Ready to capture tab audio',
        captureStarting: 'Starting capture...',
        captureActive: 'Capturing tab audio',
        captureError: 'Error',
        captureStopped: 'Capture stopped',

        // Tabs
        tabTranscript: '📝 Transcript',
        tabInsights: '🔮 Insights',
        tabAura: '🧠 Aura',
        tabSummary: '📊 Summary',

        // Insights
        insightsEmpty: 'Aura is listening...',
        insightsEmptyHint: 'Insights will appear here.',

        // Copilot
        copilotWelcome: "Hi, I'm Aura.",
        copilotWelcomeHint: 'Ask me anything about this meeting.',
        copilotPlaceholder: 'Ask Aura...',
        copilotLabel: '🧠 Aura',
        copilotError: '⚠️ Error',

        // Summary
        summaryEmpty: 'Generate a meeting summary',
        summaryEmptyHint: 'after capturing transcript.',
        summaryGenerate: '✨ Generate Summary',
        summaryAnalyzing: 'Analyzing meeting...',
        summaryCopy: '📋 Copy as Markdown',
        summaryCopied: '✅ Copied!',
        summaryTitle: 'Meeting Summary',
        summaryTopics: '🏷️ Key Topics',
        summaryDecisions: '📌 Decisions',
        summaryActions: '✅ Action Items',
        summaryRisks: '⚠️ Risks',
        summaryNextSteps: '🚀 Next Steps',

        // Cost
        costSession: '💰 Session',
        costLeft: 'left',
        costExceeded: '⚠️ Budget exceeded',
        costLimit: '🚫 Budget limit reached',

        // Connection
        connLive: 'Live',
        connConnecting: 'Connecting',
        connOffline: 'Offline',

        // Settings
        settingsTitle: 'Settings',
        settingsBackendUrl: 'Backend URL',
        settingsLanguage: 'Language',
        settingsTranscriptionLang: 'Transcription Language',
        settingsSave: 'Save',
        settingsCancel: 'Cancel',
        settingsSaved: 'Settings saved ✓',

        // Screening
        screeningRelevant: '🟢 AI detected relevant content',
        screeningWaiting: '💤 Waiting for relevant discussion...',

        // Footer
        footerVersion: 'v0.4.0',
    },

    es: {
        appTitle: 'Aura Meet',

        captureStart: 'Iniciar Captura',
        captureStop: 'Detener Captura',
        captureReady: 'Listo para capturar audio de pestaña',
        captureStarting: 'Iniciando captura...',
        captureActive: 'Capturando audio de pestaña',
        captureError: 'Error',
        captureStopped: 'Captura detenida',

        tabTranscript: '📝 Transcripción',
        tabInsights: '🔮 Hallazgos',
        tabAura: '🧠 Aura',
        tabSummary: '📊 Resumen',

        insightsEmpty: 'Aura está escuchando...',
        insightsEmptyHint: 'Los hallazgos aparecerán aquí.',

        copilotWelcome: 'Hola, soy Aura.',
        copilotWelcomeHint: 'Pregúntame lo que quieras sobre esta reunión.',
        copilotPlaceholder: 'Pregunta a Aura...',
        copilotLabel: '🧠 Aura',
        copilotError: '⚠️ Error',

        summaryEmpty: 'Generar resumen de reunión',
        summaryEmptyHint: 'después de capturar la transcripción.',
        summaryGenerate: '✨ Generar Resumen',
        summaryAnalyzing: 'Analizando reunión...',
        summaryCopy: '📋 Copiar como Markdown',
        summaryCopied: '✅ ¡Copiado!',
        summaryTitle: 'Resumen de Reunión',
        summaryTopics: '🏷️ Temas Principales',
        summaryDecisions: '📌 Decisiones',
        summaryActions: '✅ Action Items',
        summaryRisks: '⚠️ Riesgos',
        summaryNextSteps: '🚀 Próximos Pasos',

        costSession: '💰 Sesión',
        costLeft: 'restante',
        costExceeded: '⚠️ Presupuesto excedido',
        costLimit: '🚫 Límite de presupuesto alcanzado',

        connLive: 'En Vivo',
        connConnecting: 'Conectando',
        connOffline: 'Desconectado',

        settingsTitle: 'Configuración',
        settingsBackendUrl: 'URL del Backend',
        settingsLanguage: 'Idioma',
        settingsTranscriptionLang: 'Idioma de Transcripción',
        settingsSave: 'Guardar',
        settingsCancel: 'Cancelar',
        settingsSaved: 'Configuración guardada ✓',

        screeningRelevant: '🟢 IA detectó contenido relevante',
        screeningWaiting: '💤 Esperando discusión relevante...',

        footerVersion: 'v0.4.0',
    },

    pt: {
        appTitle: 'Aura Meet',

        captureStart: 'Iniciar Captura',
        captureStop: 'Parar Captura',
        captureReady: 'Pronto para capturar áudio da aba',
        captureStarting: 'Iniciando captura...',
        captureActive: 'Capturando áudio da aba',
        captureError: 'Erro',
        captureStopped: 'Captura parada',

        tabTranscript: '📝 Transcrição',
        tabInsights: '🔮 Insights',
        tabAura: '🧠 Aura',
        tabSummary: '📊 Resumo',

        insightsEmpty: 'Aura está ouvindo...',
        insightsEmptyHint: 'Os insights aparecerão aqui.',

        copilotWelcome: 'Olá, sou Aura.',
        copilotWelcomeHint: 'Pergunte qualquer coisa sobre esta reunião.',
        copilotPlaceholder: 'Pergunte ao Aura...',
        copilotLabel: '🧠 Aura',
        copilotError: '⚠️ Erro',

        summaryEmpty: 'Gerar resumo da reunião',
        summaryEmptyHint: 'após capturar a transcrição.',
        summaryGenerate: '✨ Gerar Resumo',
        summaryAnalyzing: 'Analisando reunião...',
        summaryCopy: '📋 Copiar como Markdown',
        summaryCopied: '✅ Copiado!',
        summaryTitle: 'Resumo da Reunião',
        summaryTopics: '🏷️ Tópicos Principais',
        summaryDecisions: '📌 Decisões',
        summaryActions: '✅ Action Items',
        summaryRisks: '⚠️ Riscos',
        summaryNextSteps: '🚀 Próximos Passos',

        costSession: '💰 Sessão',
        costLeft: 'restante',
        costExceeded: '⚠️ Orçamento excedido',
        costLimit: '🚫 Limite de orçamento atingido',

        connLive: 'Ao Vivo',
        connConnecting: 'Conectando',
        connOffline: 'Desconectado',

        settingsTitle: 'Configurações',
        settingsBackendUrl: 'URL do Backend',
        settingsLanguage: 'Idioma',
        settingsTranscriptionLang: 'Idioma da Transcrição',
        settingsSave: 'Salvar',
        settingsCancel: 'Cancelar',
        settingsSaved: 'Configurações salvas ✓',

        screeningRelevant: '🟢 IA detectou conteúdo relevante',
        screeningWaiting: '💤 Aguardando discussão relevante...',

        footerVersion: 'v0.4.0',
    },
};

// ─── Supported Languages ───────────────────

const supportedLocales = [
    { code: 'en', flag: '🇺🇸', name: 'English' },
    { code: 'es', flag: '🇪🇸', name: 'Español' },
    { code: 'pt', flag: '🇧🇷', name: 'Português' },
];

const transcriptionLanguages = [
    { code: 'auto', flag: '🌐', name: 'Auto-detect' },
    { code: 'en', flag: '🇺🇸', name: 'English' },
    { code: 'es', flag: '🇪🇸', name: 'Español' },
    { code: 'pt', flag: '🇧🇷', name: 'Português' },
    { code: 'fr', flag: '🇫🇷', name: 'Français' },
    { code: 'de', flag: '🇩🇪', name: 'Deutsch' },
    { code: 'it', flag: '🇮🇹', name: 'Italiano' },
    { code: 'ja', flag: '🇯🇵', name: '日本語' },
    { code: 'ko', flag: '🇰🇷', name: '한국어' },
    { code: 'zh', flag: '🇨🇳', name: '中文' },
];

// ─── State ─────────────────────────────────

let currentLocale = 'en';
let currentTranscriptionLang = 'auto';

// ─── Core Functions ────────────────────────

/**
 * Get a translated string by key.
 * Falls back to English, then to the key itself.
 * @param {string} key
 * @returns {string}
 */
function t(key) {
    return translations[currentLocale]?.[key]
        ?? translations.en[key]
        ?? key;
}

/**
 * Apply translations to all elements with data-i18n attribute.
 * Supports:
 *   data-i18n="key"              → sets textContent
 *   data-i18n-placeholder="key"  → sets placeholder
 *   data-i18n-title="key"        → sets title attribute
 */
function applyTranslations() {
    document.querySelectorAll('[data-i18n]').forEach((el) => {
        const key = el.getAttribute('data-i18n');
        if (key) el.textContent = t(key);
    });

    document.querySelectorAll('[data-i18n-placeholder]').forEach((el) => {
        const key = el.getAttribute('data-i18n-placeholder');
        if (key) el.placeholder = t(key);
    });

    document.querySelectorAll('[data-i18n-title]').forEach((el) => {
        const key = el.getAttribute('data-i18n-title');
        if (key) el.title = t(key);
    });
}

/**
 * Detect the best locale from browser settings.
 * @returns {string} locale code (en, es, pt)
 */
function detectLocale() {
    const browserLangs = navigator.languages || [navigator.language || 'en'];
    for (const lang of browserLangs) {
        const code = lang.split('-')[0].toLowerCase();
        if (translations[code]) return code;
    }
    return 'en';
}

/**
 * Initialize i18n: load persisted locale or auto-detect.
 * @returns {Promise<void>}
 */
async function initI18n() {
    const stored = await chrome.storage.local.get(['uiLocale', 'transcriptionLanguage']);

    currentLocale = stored.uiLocale || detectLocale();
    currentTranscriptionLang = stored.transcriptionLanguage || 'auto';

    applyTranslations();
}

/**
 * Change the UI language and persist it.
 * @param {string} locale - en, es, or pt
 */
async function setLocale(locale) {
    if (!translations[locale]) return;
    currentLocale = locale;
    await chrome.storage.local.set({ uiLocale: locale });
    applyTranslations();
}

/**
 * Change the transcription language and persist it.
 * @param {string} langCode - auto, en, es, pt, etc.
 */
async function setTranscriptionLanguage(langCode) {
    currentTranscriptionLang = langCode;
    await chrome.storage.local.set({ transcriptionLanguage: langCode });
}

/**
 * Get the current transcription language code.
 * @returns {string}
 */
function getTranscriptionLanguage() {
    return currentTranscriptionLang;
}

/**
 * Get the current UI locale.
 * @returns {string}
 */
function getLocale() {
    return currentLocale;
}
