<script setup>
import { onMounted, ref } from 'vue';
import Card from '../components/Card.vue';
import AppButton from '../components/AppButton.vue';
import { api } from '../api.js';
import { run } from '../toast.js';

const q = ref('');
const room = ref('');
const rooms = ref([]);
const results = ref([]);
const pinned = ref([]);
const truncated = ref(false);
const searched = ref(false);
const busy = ref(false);

async function loadRooms() {
  const res = await run(() => api.rooms(), { failure: () => '' });
  if (res.ok) rooms.value = res.result.items || res.result.rooms || [];
}

onMounted(async () => {
  await loadRooms();
  loadPinned();
});

async function search() {
  if (!q.value.trim()) return;
  busy.value = true;
  const res = await run(() => api.search(q.value.trim(), room.value || undefined), {
    failure: (e) => e?.message,
  });
  busy.value = false;
  if (res.ok) {
    results.value = res.result.results || [];
    truncated.value = !!res.result.truncated;
    searched.value = true;
  }
}

async function loadPinned() {
  const res = await run(() => api.pinned(room.value || undefined), { failure: () => '' });
  if (res.ok) pinned.value = res.result.messages || [];
}

const when = (iso) => {
  const d = new Date(iso);
  return `${d.getMonth() + 1}/${d.getDate()} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
};

const textOf = (m) =>
  (m.segments || [])
    .filter((s) => s.type === 'text')
    .map((s) => s.data?.text || '')
    .join('');
</script>

<template>
  <div class="stack">
    <Card title="消息检索" subtitle="在房间历史中按关键词查找">
      <form class="bar" @submit.prevent="search">
        <input v-model="q" class="in" placeholder="输入关键词后回车" />
        <select v-model="room" class="sel" @change="loadPinned">
          <option value="">全部房间</option>
          <option v-for="r in rooms" :key="r.roomId" :value="r.roomId">{{ r.roomName }}</option>
        </select>
        <AppButton type="submit" variant="primary" :busy="busy" :disabled="!q.trim()">
          搜索
        </AppButton>
      </form>

      <p v-if="truncated" class="faint tiny">结果过多，仅显示前 200 条，请补充关键词。</p>

      <div v-if="searched && !results.length" class="empty">没有匹配的消息</div>

      <ul v-else-if="results.length" class="hits">
        <li v-for="(m, i) in results" :key="m.messageId || i">
          <div class="meta">
            <strong>{{ m.sender?.displayName || '未知' }}</strong>
            <span class="faint">{{ m.roomName }}</span>
            <span class="mono faint">{{ when(m.sentAt) }}</span>
          </div>
          <p class="text">{{ textOf(m) }}</p>
        </li>
      </ul>
    </Card>

    <Card title="置顶消息" subtitle="由房间管理员置顶的内容">
      <template #actions>
        <AppButton size="sm" @click="loadPinned">刷新</AppButton>
      </template>

      <div v-if="!pinned.length" class="empty">暂无置顶消息</div>

      <ul v-else class="hits">
        <li v-for="(m, i) in pinned" :key="m.messageId || i">
          <div class="meta">
            <strong>{{ m.sender?.displayName || '未知' }}</strong>
            <span class="faint">{{ m.roomName }}</span>
            <span class="mono faint">{{ when(m.sentAt) }}</span>
          </div>
          <p class="text">{{ textOf(m) }}</p>
        </li>
      </ul>
    </Card>
  </div>
</template>

<style scoped>
.bar {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.in,
.sel {
  padding: 8px 10px;
  border-radius: var(--r-sm);
  border: 1px solid var(--border);
  background: #0e1526;
  color: var(--text);
  font: inherit;
  font-size: 13px;
}
.in {
  flex: 1;
  min-width: 180px;
}
.in:focus,
.sel:focus {
  outline: none;
  border-color: var(--accent);
}

.hits {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin-top: 14px;
  max-height: 50vh;
  overflow: auto;
}

.hits li {
  padding: 10px 12px;
  border-radius: var(--r-sm);
  border: 1px solid var(--border);
  background: rgba(255, 255, 255, 0.02);
}

.meta {
  display: flex;
  align-items: baseline;
  gap: 8px;
  font-size: 12px;
}

.text {
  margin-top: 4px;
  font-size: 13px;
  word-break: break-word;
  white-space: pre-wrap;
}

.tiny {
  font-size: 11.5px;
  margin-top: 8px;
}
</style>
