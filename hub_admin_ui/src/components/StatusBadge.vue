<script setup>
defineProps({
  status: { type: String, default: 'online' }, // online|away|busy|offline
  label: { type: String, default: '' },
});
</script>

<template>
  <span class="badge" :class="status">
    <i class="dot" />
    {{ label || status }}
  </span>
</template>

<style scoped>
.badge {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 500;
  border: 1px solid var(--border);
  background: var(--surface-3);
  color: var(--text-muted);
  white-space: nowrap;
}

.dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: currentColor;
  flex: none;
}

.online {
  color: var(--ok);
  border-color: rgba(52, 211, 153, 0.35);
  background: var(--ok-soft);
}
.away {
  color: var(--warn);
  border-color: rgba(251, 191, 36, 0.35);
  background: var(--warn-soft);
}
.busy {
  color: var(--danger);
  border-color: rgba(248, 113, 113, 0.35);
  background: var(--danger-soft);
}
.offline {
  color: var(--text-faint);
}
</style>
