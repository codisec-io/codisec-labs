// @ts-check
import { defineConfig } from 'astro/config';

import sitemap from '@astrojs/sitemap';

// Site 100% estático por decisão de segurança (ver docs/SECURITY.md) —
// zero backend/servidor de aplicação nosso exposto pela internet.
// https://astro.build/config
export default defineConfig({
  site: 'https://codisec.com.br',
  output: 'static',
  integrations: [sitemap()]
});