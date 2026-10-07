<script setup lang="ts">
import {
  formatWishPrice,
  isSafeExternalLink,
  shareOgImage,
  sharePageDescription,
  sharePageTitle,
} from '~/utils/share';
import type { ShareResponse, SharedWish } from '~/utils/share';

/**
 * Публичный read-only viewer share-ссылки `/s/{token}`.
 *
 * Единственный источник данных — публичный endpoint
 * `GET {apiBase}/share/{token}` (без авторизации). SSR: useFetch
 * с await — HTML и OG-meta отдаются сервером для preview
 * в мессенджерах.
 */
const route = useRoute();
const config = useRuntimeConfig();
const requestUrl = useRequestURL();

const { data, pending, error, refresh } = await useFetch<ShareResponse>(
  () => `${config.public.apiBase}/share/${route.params.token}`,
);

// Единое состояние «ссылка недействительна»: невалидный токен,
// revoked/expired share, удалённые Wish/WishList — backend отдаёт
// одинаковый 404, причину не раскрываем.
const isInvalidLink = computed(() => error.value?.statusCode === 404);

const requestEvent = useRequestEvent();
if (isInvalidLink.value && requestEvent) {
  setResponseStatus(requestEvent, 404);
}

useSeoMeta({
  title: () => (data.value ? sharePageTitle(data.value) : 'ЧтоХочу'),
  description: () =>
    data.value
      ? sharePageDescription(data.value)
      : 'ЧтоХочу — списки желаний',
  ogTitle: () => (data.value ? sharePageTitle(data.value) : 'ЧтоХочу'),
  ogDescription: () =>
    data.value ? sharePageDescription(data.value) : undefined,
  ogImage: () => (data.value ? (shareOgImage(data.value) ?? undefined) : undefined),
  ogUrl: () => requestUrl.href,
  ogType: 'website',
  ogSiteName: 'ЧтоХочу',
  ogLocale: 'ru_RU',
});

const wish = computed<SharedWish | null>(() =>
  data.value?.type === 'wish' ? data.value.data : null,
);
</script>

<template>
  <div class="share-page">
    <header class="share-header">
      <a class="share-logo" href="/">ЧтоХочу</a>
    </header>

    <main class="share-main">
      <!-- Loading: минимальный skeleton (показывается при client-side retry) -->
      <div v-if="pending" class="share-card share-skeleton" aria-busy="true">
        <div class="sk-line sk-short" />
        <div class="sk-line sk-title" />
        <div class="sk-block" />
      </div>

      <!-- 404: единое «недействительная ссылка» без раскрытия причины -->
      <div v-else-if="isInvalidLink" class="share-card share-state">
        <h1 class="share-state-title">Ссылка недействительна</h1>
        <p class="share-state-text">
          Возможно, желание было удалено или ссылка больше не&nbsp;доступна.
        </p>
      </div>

      <!-- Сетевая/серверная ошибка — с повтором -->
      <div v-else-if="error" class="share-card share-state">
        <h1 class="share-state-title">Не удалось загрузить</h1>
        <p class="share-state-text">
          Проверьте подключение к&nbsp;интернету и&nbsp;попробуйте ещё раз.
        </p>
        <button class="share-retry" type="button" @click="refresh()">
          Повторить
        </button>
      </div>

      <!-- Wish -->
      <div v-else-if="wish" class="share-card share-wish">
        <p v-if="wish.owner?.name" class="share-owner">
          {{ wish.owner.name }} хочет
        </p>
        <h1 class="share-wish-title">{{ wish.title }}</h1>
        <p v-if="formatWishPrice(wish.price)" class="share-wish-price">
          {{ formatWishPrice(wish.price) }}
        </p>
        <div class="share-wish-image">
          <img v-if="wish.image_url" :src="wish.image_url" :alt="wish.title" />
          <div v-else class="share-image-placeholder" aria-hidden="true">🎁</div>
        </div>
        <a
          v-if="isSafeExternalLink(wish.link)"
          class="share-cta"
          :href="wish.link!"
          target="_blank"
          rel="noopener noreferrer nofollow"
        >Открыть товар</a>
      </div>

      <!-- WishList -->
      <div v-else-if="data?.type === 'wish_list'" class="share-card share-list">
        <p v-if="data.data.owner.name" class="share-owner">
          {{ data.data.owner.name }}
        </p>
        <h1 class="share-wish-title">{{ data.data.title }}</h1>
        <div v-if="data.data.wishes.length" class="share-wishes">
          <SharedWishCard
            v-for="(w, i) in data.data.wishes"
            :key="i"
            :wish="w"
          />
        </div>
        <p v-else class="share-empty">Список пока пуст</p>
      </div>
    </main>

    <footer class="share-footer">
      ЧтоХочу — сохраняй желания и&nbsp;делись ими с&nbsp;близкими
    </footer>
  </div>
</template>

<style scoped>
.share-page {
  min-height: 100dvh;
  display: flex;
  flex-direction: column;
}

.share-header {
  padding: 1rem 1.25rem;
  text-align: center;
}

.share-logo {
  font-size: 1.25rem;
  font-weight: 800;
  color: var(--ch-brand);
  text-decoration: none;
  letter-spacing: -0.01em;
}

.share-main {
  flex: 1;
  width: 100%;
  max-width: var(--ch-content-width);
  margin: 0 auto;
  padding: 0.5rem 1rem 2.5rem;
}

.share-card {
  background: var(--ch-surface);
  border: 1px solid var(--ch-border);
  border-radius: var(--ch-radius-lg);
  padding: 1.5rem;
}

.share-owner {
  margin: 0 0 0.25rem;
  font-size: 0.875rem;
  font-weight: 600;
  color: var(--ch-text-muted);
}

.share-wish-title {
  margin: 0;
  font-size: 1.5rem;
  font-weight: 800;
  letter-spacing: -0.01em;
  overflow-wrap: break-word;
}

.share-wish-price {
  margin: 0.5rem 0 0;
  font-size: 1.125rem;
  font-weight: 700;
  color: var(--ch-brand-text);
}

.share-wish-image {
  margin-top: 1.25rem;
  border-radius: var(--ch-radius-sm);
  overflow: hidden;
  background: var(--ch-surface-muted);
  aspect-ratio: 4 / 3;
  display: flex;
  align-items: center;
  justify-content: center;
}

.share-wish-image img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.share-image-placeholder {
  font-size: 3rem;
  opacity: 0.6;
}

.share-cta {
  display: block;
  margin-top: 1.25rem;
  padding: 0.875rem 1rem;
  text-align: center;
  font-weight: 700;
  color: #fff;
  background: var(--ch-brand);
  border-radius: var(--ch-radius-sm);
  text-decoration: none;
}

.share-cta:hover {
  filter: brightness(1.05);
}

/* WishList */
.share-wishes {
  margin-top: 1.25rem;
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.share-empty {
  margin: 1.5rem 0 0.5rem;
  text-align: center;
  color: var(--ch-text-muted);
}

/* States */
.share-state {
  text-align: center;
  padding: 2.5rem 1.5rem;
}

.share-state-title {
  margin: 0;
  font-size: 1.375rem;
  font-weight: 800;
}

.share-state-text {
  margin: 0.75rem 0 0;
  color: var(--ch-text-secondary);
}

.share-retry {
  margin-top: 1.25rem;
  padding: 0.75rem 1.5rem;
  font: inherit;
  font-weight: 700;
  color: #fff;
  background: var(--ch-brand);
  border: 0;
  border-radius: var(--ch-radius-sm);
  cursor: pointer;
}

/* Skeleton */
.share-skeleton {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.sk-line,
.sk-block {
  border-radius: 8px;
  background: var(--ch-surface-muted);
  animation: sk-pulse 1.4s ease-in-out infinite;
}

.sk-line {
  height: 0.875rem;
}

.sk-short {
  width: 30%;
}

.sk-title {
  width: 70%;
  height: 1.25rem;
}

.sk-block {
  height: 12rem;
  border-radius: var(--ch-radius-sm);
}

@keyframes sk-pulse {
  0%,
  100% {
    opacity: 1;
  }
  50% {
    opacity: 0.5;
  }
}

@media (prefers-reduced-motion: reduce) {
  .sk-line,
  .sk-block {
    animation: none;
  }
}

.share-footer {
  padding: 1rem;
  text-align: center;
  font-size: 0.8125rem;
  color: var(--ch-text-muted);
}

@media (min-width: 768px) {
  .share-wish-title {
    font-size: 1.75rem;
  }

  .share-card {
    padding: 2rem;
  }
}
</style>
