<template>
  <LandingLayout :title="title">
    <section class="landing-hero">
      <header>
        <h1 class="landing-hero__title">{{ title }}</h1>
        <p class="landing-hero__subtitle" v-if="subtitle">
          {{ subtitle }}
        </p>
      </header>

      <section v-if="user">
        <div v-if="user.avatar" class="mb-4">
          <img :src="user.avatar" :alt="user.name" class="mx-auto rounded-full w-24 h-24 object-cover" />
        </div>
        <h2 class="text-xl font-semibold mb-2">{{ user.name }}</h2>
        <p v-if="user.about" class="text-gray-600 mb-2">
          {{ user.about }}
        </p>
        <p v-if="publicWishlistsCount > 0" class="text-gray-500 mb-4">
          Открытых списков желаний: {{ publicWishlistsCount }}
        </p>
      </section>

      <section class="mt-6">
        <p class="landing-hero__subtitle mb-4">
          Установите приложение «Что Хочу», чтобы создавать свои списки желаний и покупок,
          приглашать друзей и отмечать исполненные желания.
        </p>
        <div class="flex flex-col items-center gap-3">
          <a :href="deeplink" class="btn btn-primary">Открыть в приложении</a>
          <a :href="storeUrl" class="btn btn-secondary">Установить приложение</a>
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
