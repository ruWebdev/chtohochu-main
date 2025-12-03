<template>
  <UserLayout :title="title">
    <section>
      <p>{{ description }}</p>
    </section>
  </UserLayout>
</template>

<script setup>
import UserLayout from '@/Layouts/UserLayout.vue';

const props = defineProps({
  title: { type: String, default: '' },
  description: { type: String, default: '' }
});
</script>
