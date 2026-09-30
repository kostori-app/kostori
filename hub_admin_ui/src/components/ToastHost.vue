<script setup>
import { useToasts } from '../toast.js';

const toasts = useToasts();
</script>

<template>
  <div class="toasts">
    <TransitionGroup name="toast">
      <div v-for="t in toasts" :key="t.id" class="toast" :class="t.level">
        {{ t.message }}
      </div>
    </TransitionGroup>
  </div>
</template>

<style scoped>
.toasts {
  position: fixed;
  right: 20px;
  bottom: 20px;
  z-index: 200;
  display: flex;
  flex-direction: column;
  gap: 8px;
  max-width: min(420px, calc(100vw - 40px));
  pointer-events: none;
}

.toast {
  padding: 10px 14px;
  border-radius: var(--r-sm);
  background: var(--surface-2);
  border: 1px solid var(--border-strong);
  box-shadow: var(--shadow);
  font-size: 13px;
  line-height: 1.5;
  word-break: break-word;
}

.toast.ok {
  border-color: rgba(52, 211, 153, 0.5);
  background: linear-gradient(var(--ok-soft), var(--ok-soft)), var(--surface-2);
}
.toast.err {
  border-color: rgba(248, 113, 113, 0.5);
  background: linear-gradient(var(--danger-soft), var(--danger-soft)), var(--surface-2);
}

.toast-enter-active,
.toast-leave-active {
  transition: opacity 0.18s ease, transform 0.18s ease;
}
.toast-enter-from,
.toast-leave-to {
  opacity: 0;
  transform: translateX(12px);
}
</style>
