# Aura Meet Website — aurameet.live

Ultra-modern landing page for the Aura Meet app, built with **Astro 6**.

## Quick Start

```bash
# Install dependencies
npm install

# Start dev server (http://localhost:4321)
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview
```

## Tech Stack

| Tech | Purpose |
|------|---------|
| **Astro 6** | Static Site Generator (0KB JS) |
| **Vanilla CSS** | Design system with glassmorphism |
| **Inter** | Google Font |
| **@astrojs/sitemap** | Auto-generated sitemap.xml |

## Project Structure

```
src/
├── i18n/           # Translation files (ES/EN/PT)
│   ├── es.json     # Spanish (default)
│   ├── en.json     # English
│   ├── pt.json     # Portuguese
│   └── index.js    # i18n utility
├── layouts/
│   └── Layout.astro   # Base HTML (SEO, fonts, Schema.org)
├── components/        # Reusable sections
│   ├── Nav.astro      # Navbar + language switcher
│   ├── Hero.astro     # Hero with phone mockup
│   ├── AppShowcase.astro  # App screen gallery
│   ├── Features.astro # Feature cards
│   ├── HowItWorks.astro   # 3-step flow
│   ├── FAQ.astro      # FAQ accordion
│   ├── Pricing.astro  # Free vs Pro plans
│   ├── CTA.astro      # Call to action
│   └── Footer.astro   # Footer with legal links
├── pages/
│   ├── index.astro    # Landing (Spanish)
│   ├── en/index.astro # Landing (English)
│   ├── pt/index.astro # Landing (Portuguese)
│   ├── privacy.astro  # Privacy Policy
│   ├── terms.astro    # Terms of Service
│   ├── support.astro  # Support page
│   └── delete-account.astro  # Account deletion
└── styles/
    └── global.css     # Design system
```

## How to Edit

### Change text content
Edit the JSON files in `src/i18n/`:
- `es.json` — Spanish
- `en.json` — English
- `pt.json` — Portuguese

### Add a new language
1. Create `src/i18n/xx.json` (copy from `en.json`)
2. Add the locale to `astro.config.mjs` → `i18n.locales`
3. Create `src/pages/xx/index.astro` (copy from `en/index.astro`)
4. Update `src/i18n/index.js` with the new locale

### Change colors / design
Edit CSS custom properties in `src/styles/global.css` under `:root`.

### Update legal pages
Edit the HTML directly in `src/pages/privacy.astro`, `terms.astro`, etc.

### Add store links
Replace the `href="#"` in `Hero.astro` and `CTA.astro` with actual App Store / Google Play URLs.

## Deployment

```bash
# Build static site
npm run build

# Upload to server
rsync -avz dist/ user@your-server:/var/www/aurameet.live/

# Caddy config
# aurameet.live {
#   root * /var/www/aurameet.live
#   file_server
# }
```

### DNS (Route 53)
Add an A record: `aurameet.live` → EC2 Elastic IP

## SEO Checklist

- [x] `<title>` and `<meta description>` per page
- [x] Canonical URLs
- [x] hreflang tags (ES/EN/PT + x-default)
- [x] Open Graph + Twitter Cards
- [x] Schema.org: Organization, SoftwareApplication, HowTo, FAQPage
- [x] Auto-generated sitemap.xml
- [x] robots.txt
- [x] Semantic HTML5
- [x] 0KB JavaScript (perfect Core Web Vitals)
