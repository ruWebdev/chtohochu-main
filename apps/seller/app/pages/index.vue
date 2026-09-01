<script setup lang="ts">
definePageMeta({ middleware: 'auth' });
useHead({ title: 'Кабинет продавца — ЧтоХочу' });
</script>

<template>
  <main class="seller-dashboard">
    <h1>Кабинет продавца</h1>
    <p>Скелет приложения. Функциональность будет добавлена в следующих задачах.</p>
  </main>
</template>

<style scoped>
.seller-dashboard {
  font-family: system-ui, sans-serif;
  padding: 2rem 1.5rem;
}
</style>
