<template>
  <LandingLayout :title="title">
    <section class="landing-hero space-y-6">
      <header class="space-y-2">
        <h1 class="landing-hero__title">{{ title }}</h1>
        <p class="landing-hero__subtitle" v-if="subtitle">
          {{ subtitle }}
        </p>
      </header>

      <section v-if="user" class="space-y-3">
        <div v-if="user.avatar" class="flex justify-center">
          <img :src="user.avatar" :alt="user.name" class="rounded-full w-24 h-24 object-cover shadow-md" />
        </div>
        <h2 class="text-xl font-semibold text-gray-900 text-center">{{ user.name }}</h2>
        <p v-if="user.about" class="text-gray-600 text-sm text-center">
          {{ user.about }}
        </p>
        <p v-if="publicWishlistsCount > 0" class="text-gray-500 text-sm text-center">
          Открытых списков желаний: {{ publicWishlistsCount }}
        </p>
      </section>

      <section class="pt-4 border-t border-gray-200 space-y-3">
        <p class="text-sm text-gray-600 text-center">
          Установите приложение «Что Хочу», чтобы создавать списки желаний и покупок и
          делиться ими с друзьями.
        </p>
        <div class="flex flex-col items-stretch gap-2">
          <a :href="deeplink" class="btn btn-primary w-full text-center">Открыть в приложении</a>
          <a :href="storeUrl" class="btn btn-secondary w-full text-center">Установить приложение</a>
        </div>
      </section>
    </section>
  </LandingLayout>
</template>

<script setup>
import { computed } from 'vue';
import { usePage } from '@inertiajs/vue3';
import LandingLayout from '@/Layouts/LandingLayout.vue';

const page = usePage();
const props = page.props;

const user = computed(() => props.user || null);
const publicWishlistsCount = computed(() => props.public_wishlists_count || 0);

const appStoreUrl = computed(() => props.app_store_url || '');
const playStoreUrl = computed(() => props.play_store_url || '');

const deeplink = computed(() => props.deeplink || '#');
const storeUrl = computed(() => props.play_store_url || props.app_store_url || '#');

const title = computed(() => {
  if (!user.value) return 'Приглашение в «Что Хочу»';
  return `${user.value.name} приглашает вас в «Что Хочу»`;
});

const subtitle = computed(() => {
  if (!user.value) return '';
  return 'Сохраняйте идеи подарков и ведите общие списки вместе.';
});
</script>
