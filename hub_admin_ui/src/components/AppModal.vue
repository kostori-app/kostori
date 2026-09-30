<script setup>
import { onBeforeUnmount, onMounted, ref } from 'vue';

/**
 * 模态框。用原生 <dialog> 以获得焦点陷阱与 Esc 关闭，
 * 不用的话长表单在键盘操作下很难用。
 */
defineProps({
  title: { type: String, default: '' },
  width: { type: String, default: '520px' },
});
const emit = defineEmits(['close']);
const el = ref(null);

onMounted(() => {
  el.value?.showModal?.();
});
onBeforeUnmount(() => {
  el.value?.close?.();
});

function onCancel(e) {
  e.preventDefault();
  emit('close');
}
</script>

<template>
  <dialog ref="el" class="modal" :style="{ maxWidth: width }" @cancel="onCancel">
    <header class="head">
      <h2 class="title">{{ title }}</h2>
      <button class="x" type="button" aria-label="关闭" @click="emit('close')">×</button>
    </header>
    <div class="body"><slot /></div>
    <footer v-if="$slots.footer" class="foot"><slot name="footer" /></footer>
  </dialog>
</template>

<style scoped>
.modal {
  width: calc(100vw - 32px);
  padding: 0;
  border: 1px solid var(--border-strong);
  border-radius: var(--r-lg);
  background: var(--surface);
  color: var(--text);
  box-shadow: var(--shadow-lg);
}

.modal::backdrop {
  background: rgba(4, 7, 15, 0.72);
  backdrop-filter: blur(3px);
}

.head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 14px 18px;
  border-bottom: 1px solid var(--border);
}

.title {
  font-size: 14px;
  font-weight: 600;
}

.x {
  background: none;
  border: 0;
  color: var(--text-muted);
  font-size: 20px;
  line-height: 1;
  cursor: pointer;
  padding: 0 4px;
}
.x:hover {
  color: var(--text);
}

.body {
  padding: 18px;
  max-height: min(70vh, 640px);
  overflow: auto;
}

.foot {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  padding: 14px 18px;
  border-top: 1px solid var(--border);
}
</style>
