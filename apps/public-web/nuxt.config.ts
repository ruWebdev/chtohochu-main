export default defineNuxtConfig({
  compatibilityDate: '2025-01-01',
  devtools: { enabled: true },
  ssr: true,
  app: {
    head: {
      title: 'ЧтоХочу',
      htmlAttrs: { lang: 'ru' },
      meta: [
        { charset: 'utf-8' },
        { name: 'viewport', content: 'width=device-width, initial-scale=1' },
      ],
    },
  },
  runtimeConfig: {
    public: {
      apiBase: process.env.NUXT_PUBLIC_API_BASE || 'https://api.chtohochu.test/api/v1',
    },
  },
});
