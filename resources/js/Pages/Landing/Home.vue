<template>
  <LandingLayout :title="title">
    <section>
      <p>{{ description }}</p>
    </section>
  </LandingLayout>
</template>

<script setup>
import LandingLayout from '@/Layouts/LandingLayout.vue';

const props = defineProps({
  title: { type: String, default: '' },
  description: { type: String, default: '' }
});
</script>
