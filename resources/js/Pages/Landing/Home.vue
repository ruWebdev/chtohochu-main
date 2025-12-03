<template>
  <LandingLayout :title="title">
    <section class="landing-hero">
      <h1 class="landing-hero__title">
        {{ title }}
      </h1>
      <p class="landing-hero__subtitle">
        {{ description }}
      </p>
      <p class="landing-hero__soon">
        {{ soon }}
      </p>
    </section>
  </LandingLayout>
</template>

<script setup>
import LandingLayout from '@/Layouts/LandingLayout.vue';

const props = defineProps({
  title: { type: String, default: '' },
  description: { type: String, default: '' },
  soon: { type: String, default: '' }
});
</script>
