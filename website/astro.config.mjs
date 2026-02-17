import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
    site: 'https://aurameet.live',
    output: 'static',
    integrations: [sitemap()],
    i18n: {
        defaultLocale: 'es',
        locales: ['es', 'en', 'pt'],
        routing: {
            prefixDefaultLocale: false,
        },
    },
    build: {
        assets: '_assets',
    },
});
