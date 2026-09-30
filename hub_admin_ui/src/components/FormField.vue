<script setup>
import { useId } from 'vue';

const model = defineModel({ type: [String, Number, Boolean] });
defineProps({
  label: { type: String, default: '' },
  hint: { type: String, default: '' },
  type: { type: String, default: 'text' },
  placeholder: { type: String, default: '' },
  mono: { type: Boolean, default: false },
  min: { type: [String, Number], default: undefined },
  max: { type: [String, Number], default: undefined },
  step: { type: [String, Number], default: undefined },
  disabled: { type: Boolean, default: false },
});
const id = useId();
</script>

<template>
  <label class="field" :for="id">
    <span v-if="label" class="label">{{ label }}</span>
    <input
      :id="id"
      v-model="model"
      :type="type"
      :placeholder="placeholder"
      :min="min"
      :max="max"
      :step="step"
      :disabled="disabled"
      :class="{ mono }"
      spellcheck="false"
      autocomplete="off"
    />
    <span v-if="hint" class="hint">{{ hint }}</span>
  </label>
</template>

<style scoped>
.field {
  display: flex;
  flex-direction: column;
  gap: 5px;
  min-width: 0;
}

.label {
  font-size: 12px;
  color: var(--text-muted);
  font-weight: 500;
}

input {
  width: 100%;
  padding: 8px 10px;
  border-radius: var(--r-sm);
  border: 1px solid var(--border);
  background: #0e1526;
  color: var(--text);
  font: inherit;
  font-size: 13px;
  transition: border-color 0.14s ease, box-shadow 0.14s ease;
}

input.mono {
  font-family: var(--mono);
  font-size: 12px;
}

input:focus {
  outline: none;
  border-color: var(--accent);
  box-shadow: 0 0 0 3px var(--accent-soft);
}

input:disabled {
  opacity: 0.55;
  cursor: not-allowed;
}

input::placeholder {
  color: var(--text-faint);
}

.hint {
  font-size: 11px;
  color: var(--text-faint);
  line-height: 1.45;
}
</style>
