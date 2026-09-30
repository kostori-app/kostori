<script setup>
import { onMounted, reactive, ref } from 'vue';
import Card from '../components/Card.vue';
import AppButton from '../components/AppButton.vue';
import FormField from '../components/FormField.vue';
import { api } from '../api.js';
import { run } from '../toast.js';

const form = reactive({
  enabled: false,
  provider: '',
  model: '',
  name: 'Kostori',
  triggerMode: 'mention',
  triggerPattern: '',
  minIntervalSec: 30,
  replyDm: false,
});
const preview = ref('');
const loaded = ref(false);
const busy = ref(false);

const TRIGGERS = [
  { value: 'mention', label: '仅在被 @ 时回复' },
  { value: 'keyword', label: '命中关键词时回复' },
  { value: 'always', label: '每条消息都尝试回复' },
];

async function load() {
  const res = await run(() => api.ai(), { failure: (e) => e?.message });
  if (!res.ok) return;
  Object.assign(form, {
    enabled: !!res.result.enabled,
    provider: res.result.provider ?? '',
    model: res.result.model ?? '',
    name: res.result.name ?? '',
    triggerMode: res.result.triggerMode ?? 'mention',
    triggerPattern: res.result.triggerPattern ?? '',
    minIntervalSec: res.result.minIntervalSec ?? 30,
    replyDm: !!res.result.replyDm,
  });
  preview.value = res.result.systemPromptPreview ?? '';
  loaded.value = true;
}

onMounted(load);

async function save() {
  busy.value = true;
  const res = await run(() => api.saveAi({ ...form }), {
    success: '已保存',
    failure: (e) => `保存失败：${e?.message}`,
  });
  busy.value = false;
  if (res.ok) load();
}
</script>

<template>
  <div class="stack">
    <div v-if="!loaded" class="empty">正在读取 AI 配置…</div>

    <template v-else>
      <Card title="AI 陪聊机器人" subtitle="启用后会作为成员出现在房间 @ 列表里">
        <div class="stack">
          <label class="check">
            <input v-model="form.enabled" type="checkbox" />
            <span><strong>启用内置 AI 机器人</strong></span>
          </label>

          <div class="form">
            <FormField v-model="form.name" label="显示名" />
            <FormField v-model="form.provider" label="Provider" mono placeholder="openai" />
            <FormField v-model="form.model" label="模型" mono placeholder="gpt-4o-mini" />
          </div>

          <label class="field">
            <span class="label">触发方式</span>
            <select v-model="form.triggerMode">
              <option v-for="t in TRIGGERS" :key="t.value" :value="t.value">{{ t.label }}</option>
            </select>
          </label>

          <FormField
            v-if="form.triggerMode === 'keyword'"
            v-model="form.triggerPattern"
            label="关键词"
            placeholder="用逗号分隔，例如：签到,打卡"
          />

          <div class="form">
            <FormField
              v-model="form.minIntervalSec"
              type="number"
              label="最小回复间隔 (秒)"
              :min="0"
            />
          </div>

          <label class="check">
            <input v-model="form.replyDm" type="checkbox" />
            <span>同时响应私聊消息</span>
          </label>
        </div>
      </Card>

      <Card v-if="preview" title="人设预览" subtitle="完整人设在应用设置页编辑">
        <p class="preview">{{ preview }}</p>
      </Card>

      <div class="row">
        <AppButton variant="primary" :busy="busy" @click="save">保存 AI 配置</AppButton>
      </div>
    </template>
  </div>
</template>

<style scoped>
.form {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 14px;
}

.field {
  display: flex;
  flex-direction: column;
  gap: 5px;
}

.label {
  font-size: 12px;
  color: var(--text-muted);
  font-weight: 500;
}

select {
  padding: 8px 10px;
  border-radius: var(--r-sm);
  border: 1px solid var(--border);
  background: #0e1526;
  color: var(--text);
  font: inherit;
  font-size: 13px;
}
select:focus {
  outline: none;
  border-color: var(--accent);
}

.check {
  display: flex;
  align-items: center;
  gap: 9px;
  font-size: 13px;
  cursor: pointer;
}
.check input {
  accent-color: var(--accent);
}

.preview {
  font-size: 12.5px;
  line-height: 1.6;
  color: var(--text-muted);
  white-space: pre-wrap;
}
</style>
