<script setup>
defineProps({
  variant: { type: String, default: 'default' }, // default | primary | ghost | danger
  size: { type: String, default: 'md' }, // sm | md
  disabled: { type: Boolean, default: false },
  busy: { type: Boolean, default: false },
  type: { type: String, default: 'button' },
});
</script>

<template>
  <button
    :type="type"
    class="btn"
    :class="[variant, size]"
    :disabled="disabled || busy"
  >
    <span v-if="busy" class="spin" />
    <slot />
  </button>
</template>

<style scoped>
.btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  border-radius: var(--r-sm);
  border: 1px solid var(--border-strong);
  background: var(--surface-3);
  color: var(--text);
  font: inherit;
  font-size: 13px;
  padding: 7px 13px;
  cursor: pointer;
  transition: background 0.14s ease, border-color 0.14s ease, opacity 0.14s ease;
  white-space: nowrap;
}

.btn:hover:not(:disabled) {
  background: #26345c;
  border-color: #3d4f80;
}
.btn:active:not(:disabled) {
  transform: translateY(1px);
}
.btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn.sm {
  font-size: 12px;
  padding: 4px 9px;
}

.btn.primary {
  background: linear-gradient(135deg, var(--accent), var(--accent-2));
  border-color: transparent;
  color: #fff;
  font-weight: 500;
}
.btn.primary:hover:not(:disabled) {
  filter: brightness(1.1);
}

.btn.ghost {
  background: transparent;
  border-color: var(--border);
  color: var(--text-muted);
}
.btn.ghost:hover:not(:disabled) {
  color: var(--text);
  background: var(--surface-3);
}

.btn.danger {
  background: var(--danger-soft);
  border-color: rgba(248, 113, 113, 0.4);
  color: #fca5a5;
}
.btn.danger:hover:not(:disabled) {
  background: rgba(248, 113, 113, 0.24);
}

.spin {
  width: 11px;
  height: 11px;
  border: 2px solid currentColor;
  border-right-color: transparent;
  border-radius: 50%;
  animation: spin 0.7s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}
</style>
