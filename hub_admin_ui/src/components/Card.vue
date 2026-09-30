<script setup>
/** 卡片容器：统一标题栏 + 内容区。 */
defineProps({
  title: { type: String, default: '' },
  subtitle: { type: String, default: '' },
  padded: { type: Boolean, default: true },
});
</script>

<template>
  <section class="card">
    <header v-if="title || $slots.actions" class="head">
      <div class="grow">
        <h2 v-if="title" class="title">{{ title }}</h2>
        <p v-if="subtitle" class="sub truncate">{{ subtitle }}</p>
      </div>
      <div v-if="$slots.actions" class="row wrap"><slot name="actions" /></div>
    </header>
    <div :class="{ body: padded }">
      <slot />
    </div>
  </section>
</template>

<style scoped>
.card {
  background: linear-gradient(180deg, var(--surface), var(--surface-2));
  border: 1px solid var(--border);
  border-radius: var(--r-lg);
  box-shadow: var(--shadow);
  overflow: hidden;
}

.head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 14px 18px;
  border-bottom: 1px solid var(--border);
  background: rgba(255, 255, 255, 0.015);
}

.title {
  font-size: 14px;
  font-weight: 600;
}

.sub {
  font-size: 12px;
  color: var(--text-muted);
  margin-top: 2px;
}

.body {
  padding: 18px;
}
</style>
