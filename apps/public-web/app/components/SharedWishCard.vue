<script setup lang="ts">
import { formatWishPrice, isSafeExternalLink } from '~/utils/share';
import type { SharedWish } from '~/utils/share';

/**
 * Компактная карточка желания внутри публичного списка.
 * Только публичная проекция: title, price, image_url, link.
 */
defineProps<{ wish: SharedWish }>();
</script>

<template>
  <article class="wish-card">
    <div class="wish-card-thumb">
      <img v-if="wish.image_url" :src="wish.image_url" :alt="wish.title" loading="lazy" />
      <div v-else class="wish-card-placeholder" aria-hidden="true">🎁</div>
    </div>
    <div class="wish-card-body">
      <h3 class="wish-card-title">{{ wish.title }}</h3>
      <p v-if="formatWishPrice(wish.price)" class="wish-card-price">
        {{ formatWishPrice(wish.price) }}
      </p>
      <a
        v-if="isSafeExternalLink(wish.link)"
        class="wish-card-link"
        :href="wish.link!"
        target="_blank"
        rel="noopener noreferrer nofollow"
      >Открыть товар</a>
    </div>
  </article>
</template>

<style scoped>
.wish-card {
  display: flex;
  gap: 0.875rem;
  padding: 0.875rem;
  background: var(--ch-surface);
  border: 1px solid var(--ch-border);
  border-radius: var(--ch-radius-sm);
  align-items: center;
}

.wish-card-thumb {
  flex: 0 0 4.5rem;
  width: 4.5rem;
  height: 4.5rem;
  border-radius: 10px;
  overflow: hidden;
  background: var(--ch-surface-muted);
  display: flex;
  align-items: center;
  justify-content: center;
}

.wish-card-thumb img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.wish-card-placeholder {
  font-size: 1.5rem;
  opacity: 0.6;
}

.wish-card-body {
  min-width: 0;
}

.wish-card-title {
  margin: 0;
  font-size: 1rem;
  font-weight: 600;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.wish-card-price {
  margin: 0.25rem 0 0;
  font-size: 0.875rem;
  color: var(--ch-text-secondary);
  font-weight: 600;
}

.wish-card-link {
  display: inline-block;
  margin-top: 0.375rem;
  font-size: 0.8125rem;
  font-weight: 600;
  color: var(--ch-brand-text);
  text-decoration: none;
}

.wish-card-link:hover {
  text-decoration: underline;
}
</style>
