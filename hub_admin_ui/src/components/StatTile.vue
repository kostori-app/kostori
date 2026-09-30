<script setup>
/** 统计磁贴。 */
defineProps({
  label: { type: String, required: true },
  value: { type: [String, Number], default: '—' },
  tone: { type: String, default: 'default' }, // default|ok|warn|accent
  sub: { type: String, default: '' },
});
</script>

<template>
  <div class="tile" :class="tone">
    <div class="value">{{ value }}</div>
    <div class="label">{{ label }}</div>
    <div v-if="sub" class="sub">{{ sub }}</div>
  </div>
</template>

<style scoped>
.tile {
  padding: 14px 16px;
  border-radius: var(--r);
  border: 1px solid var(--border);
  background: linear-gradient(180deg, var(--surface-2), rgba(26, 35, 64, 0.4));
  min-width: 0;
}

.value {
  font-size: 24px;
  font-weight: 700;
  line-height: 1.15;
  letter-spacing: -0.5px;
  font-variant-numeric: tabular-nums;
}

.label {
  margin-top: 4px;
  font-size: 12px;
  color: var(--text-muted);
}

.sub {
  margin-top: 3px;
  font-size: 11px;
  color: var(--text-faint);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.ok .value {
  color: var(--ok);
}
.warn .value {
  color: var(--warn);
}
.accent .value {
  color: var(--accent);
}
</style>
