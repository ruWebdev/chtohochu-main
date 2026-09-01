<script setup lang="ts">
definePageMeta({ middleware: 'auth' });
useHead({ title: 'Админ-панель — ЧтоХочу' });
</script>

<template>
  <main class="admin-dashboard">
    <h1>Админ-панель</h1>
    <p>Скелет приложения. Функциональность будет добавлена в следующих задачах.</p>
  </main>
</template>

<style scoped>
.admin-dashboard {
  font-family: system-ui, sans-serif;
  padding: 2rem 1.5rem;
}
</style>
