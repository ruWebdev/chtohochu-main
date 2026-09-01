<script setup lang="ts">
useHead({ title: 'ЧтоХочу — Главная' });
</script>

<template>
  <main class="landing-page">
    <section class="hero">
      <h1>ЧтоХочу</h1>
      <p>Создавайте списки желаний и делитесь ими с друзьями</p>
    </section>
  </main>
</template>

<style scoped>
.landing-page {
  font-family: system-ui, sans-serif;
}
.hero {
  text-align: center;
  padding: 4rem 1.5rem;
}
.hero h1 {
  font-size: 3rem;
  margin-bottom: 1rem;
}
.hero p {
  font-size: 1.25rem;
  color: #6b7280;
}
</style>
