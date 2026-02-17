import es from './es.json';
import en from './en.json';
import pt from './pt.json';

const translations = { es, en, pt };

export function t(locale, key) {
    const keys = key.split('.');
    let value = translations[locale] || translations.es;
    for (const k of keys) {
        value = value?.[k];
    }
    return value || key;
}

export function getLocaleFromUrl(url) {
    const [, locale] = url.pathname.split('/');
    if (locale in translations) return locale;
    return 'es';
}

export const locales = ['es', 'en', 'pt'];
export const localeNames = { es: '🇪🇸 ES', en: '🇺🇸 EN', pt: '🇧🇷 PT' };
