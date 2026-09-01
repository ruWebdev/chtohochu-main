<template>
  <div class="layout landing-layout">
    <header class="header">
      <h1>{{ title }}</h1>
    </header>
    <main>
      <slot />
    </main>
  </div>
</template>

<script setup>
const props = defineProps({
  title: { type: String, default: '' }
});
</script>
