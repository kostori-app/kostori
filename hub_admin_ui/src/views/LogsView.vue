<script setup>
import { onActivated, onDeactivated, onMounted, onUnmounted, ref, watch } from 'vue';
import Card from '../components/Card.vue';
import AppButton from '../components/AppButton.vue';
import { api } from '../api.js';
import { run } from '../toast.js';

const logs = ref([]);
const level = ref('');
const auto = ref(true);
const loading = ref(false);
let timer = null;

const LEVELS = [
  { value: '', label: '全部' },
  { value: 'error', label: '错误' },
  { value: 'warning', label: '警告' },
  { value: 'info', label: '信息' },
];

async function load() {
  loading.value = true;
  const res = await run(() => api.logs({ limit: 300, level: level.value || undefined }), {
    failure: () => '',
  });
  if (res.ok) logs.value = res.result.logs || [];
  loading.value = false;
}

function stop() {
  if (timer) clearInterval(timer);
  timer = null;
}

function schedule() {
  stop();
  if (auto.value) timer = setInterval(load, 4000);
}

onMounted(load);

// 视图被 KeepAlive 缓存：切走只是「停用」而不是「卸载」，
// 只在 onMounted 起定时器的话，离开日志页后仍会一直每 4 秒轮询。
onActivated(schedule);
onDeactivated(stop);
onUnmounted(stop);

watch([level, auto], () => {
  load();
  if (auto.value) schedule();
  else stop();
});

const badge = (l) =>
  l === 'error' ? 'err' : l === 'warning' ? 'warn' : 'info';
</script>

<template>
  <Card title="运行日志" :subtitle="`最近 ${logs.length} 条`">
    <template #actions>
      <select v-model="level" class="sel">
        <option v-for="l in LEVELS" :key="l.value" :value="l.value">{{ l.label }}</option>
      </select>
      <label class="auto">
        <input v-model="auto" type="checkbox" />
        <span>自动刷新</span>
      </label>
      <AppButton size="sm" :busy="loading" @click="load">刷新</AppButton>
    </template>

    <div v-if="!logs.length" class="empty">暂无日志</div>

    <ul v-else class="log">
      <li v-for="(l, i) in logs" :key="i">
        <span class="lv" :class="badge(l.level)">{{ l.level }}</span>
        <span class="mono ts">{{ l.time.slice(11, 19) }}</span>
        <span class="ti truncate">{{ l.title }}</span>
        <span class="ct">{{ l.content }}</span>
      </li>
    </ul>
  </Card>
</template>

<style scoped>
.sel {
  padding: 5px 8px;
  border-radius: var(--r-sm);
  border: 1px solid var(--border);
  background: #0e1526;
  color: var(--text);
  font: inherit;
  font-size: 12.5px;
}

.auto {
  display: flex;
  align-items: center;
  gap: 5px;
  font-size: 12px;
  color: var(--text-muted);
  cursor: pointer;
}
.auto input {
  accent-color: var(--accent);
}

.log {
  list-style: none;
  max-height: 62vh;
  overflow: auto;
  font-family: var(--mono);
  font-size: 12px;
  /* 日志内容不换行，窄屏下横向滚动而不是撑破布局 */
  overflow-x: auto;
}

.log li {
  display: grid;
  grid-template-columns: 62px 66px 130px minmax(0, 1fr);
  gap: 8px;
  padding: 3px 6px;
  border-radius: 4px;
  align-items: baseline;
}
.log li:hover {
  background: rgba(255, 255, 255, 0.03);
}

.lv {
  font-size: 10px;
  text-transform: uppercase;
}
.lv.err {
  color: var(--danger);
}
.lv.warn {
  color: var(--warn);
}
.lv.info {
  color: var(--text-faint);
}

.ts {
  color: var(--text-faint);
}

.ti {
  color: var(--accent);
}

.ct {
  color: var(--text-muted);
  word-break: break-word;
}

@media (max-width: 860px) {
  .log li {
    grid-template-columns: 58px 1fr;
  }
  .ti {
    display: none;
  }
}
</style>
