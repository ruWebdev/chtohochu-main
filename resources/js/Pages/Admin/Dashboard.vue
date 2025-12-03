<template>
  <AdminLayout :title="title">
    <section>
      <p>{{ description }}</p>
    </section>
  </AdminLayout>
</template>

<script setup>
import AdminLayout from '@/Layouts/AdminLayout.vue';

const props = defineProps({
  title: { type: String, default: '' },
  description: { type: String, default: '' }
});
</script>
