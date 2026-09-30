<script setup>
import { ref } from 'vue';
import Card from '../components/Card.vue';
import AppButton from '../components/AppButton.vue';
import StatusBadge from '../components/StatusBadge.vue';
import { api } from '../api.js';
import { run } from '../toast.js';

const props = defineProps({
  clients: { type: Array, default: () => [] },
  loading: { type: Boolean, default: false },
});
const emit = defineEmits(['refresh']);

const filter = ref('');

const visible = () => {
  const q = filter.value.trim().toLowerCase();
  if (!q) return props.clients;
  return props.clients.filter(
    (c) =>
      (c.name || '').toLowerCase().includes(q) ||
      (c.userId || '').toLowerCase().includes(q),
  );
};

async function act(fn, success) {
  const res = await run(() => fn(), {
    success,
    failure: (e) => e?.message || '操作失败',
  });
  if (res.ok) emit('refresh');
  return res;
}

function mute(c) {
  const raw = prompt(`禁言 ${c.name || c.userId} 多少秒？`, '300');
  if (raw === null) return;
  const seconds = Number(raw);
  if (!Number.isFinite(seconds) || seconds <= 0) {
    alert('请输入正整数秒数');
    return;
  }
  act(() => api.muteClient(c.userId, seconds), `已禁言 ${seconds} 秒`);
}

function kick(c) {
  if (!confirm(`确定将 ${c.name || c.userId} 踢出服务器？`)) return;
  act(() => api.kickClient(c.userId), '已踢出');
}

function ban(c) {
  if (!confirm(`封禁 ${c.name || c.userId}？\n封禁后该用户无法再连接，并会被立即踢出。`)) return;
  act(() => api.banClient(c.userId), '已封禁');
}

function unban(c) {
  act(() => api.unbanClient(c.userId), '已解除封禁');
}

function toggleAdmin(c) {
  const next = !c.isGlobalAdmin;
  if (next && !confirm(`授予 ${c.name || c.userId} 全局管理员？\n对方将能封禁、踢出和管理全部成员。`)) return;
  act(() => api.setClientAdmin(c.userId, next), next ? '已授予管理员' : '已撤销管理员');
}
</script>

<template>
  <Card
    title="在线客户端"
    :subtitle="`共 ${clients.length} 个连接`"
  >
    <template #actions>
      <input v-model="filter" class="search" placeholder="按昵称或 ID 过滤" />
      <AppButton size="sm" :busy="loading" @click="emit('refresh')">刷新</AppButton>
    </template>

    <div v-if="!visible().length" class="empty">
      {{ clients.length ? '没有匹配的客户端' : '当前没有客户端连接' }}
    </div>

    <div v-else class="list">
      <article v-for="c in visible()" :key="c.userId" class="client">
        <div class="avatar" :style="c.avatarUrl ? { backgroundImage: `url(${c.avatarUrl})` } : {}">
          {{ (c.name || c.userId || '?').slice(0, 1).toUpperCase() }}
        </div>

        <div class="info grow">
          <div class="row wrap">
            <strong class="truncate">{{ c.name || c.userId }}</strong>
            <StatusBadge :status="c.isMuted ? 'busy' : c.onlineStatus" :label="c.isMuted ? '禁言中' : c.onlineStatus" />
            <span v-if="c.isGlobalAdmin" class="crown">管理员</span>
            <span v-if="c.isBlacklisted" class="banned">已封禁</span>
            <span v-if="c.isBot" class="bot">bot</span>
          </div>
          <p class="faint mono truncate">{{ c.userId }}</p>
          <p v-if="c.biography" class="truncate bio">{{ c.biography }}</p>
          <p class="faint room">
            {{ c.currentRoomName || c.currentRoomId }}
            <span v-if="c.peerCandidates?.length" class="faint">
              · {{ c.peerCandidates.length }} 个直连地址
            </span>
          </p>
        </div>

        <div class="ops row wrap">
          <AppButton
            size="sm"
            variant="ghost"
            :disabled="c.isMuted"
            @click="mute(c)"
          >
            禁言
          </AppButton>
          <AppButton
            size="sm"
            variant="ghost"
            :disabled="!c.isMuted"
            @click="act(() => api.unmuteClient(c.userId), '已解除禁言')"
          >
            解除
          </AppButton>
          <AppButton size="sm" variant="ghost" @click="kick(c)">踢出</AppButton>
          <AppButton
            size="sm"
            :variant="c.isBlacklisted ? 'ghost' : 'danger'"
            @click="c.isBlacklisted ? unban(c) : ban(c)"
          >
            {{ c.isBlacklisted ? '解封' : '封禁' }}
          </AppButton>
          <AppButton size="sm" variant="ghost" @click="toggleAdmin(c)">
            {{ c.isGlobalAdmin ? '撤管理' : '设管理' }}
          </AppButton>
        </div>
      </article>
    </div>
  </Card>
</template>

<style scoped>
.search {
  padding: 5px 10px;
  border-radius: var(--r-sm);
  border: 1px solid var(--border);
  background: #0e1526;
  color: var(--text);
  font: inherit;
  font-size: 12.5px;
  width: 190px;
}
.search:focus {
  outline: none;
  border-color: var(--accent);
}

.list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.client {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 12px;
  border-radius: var(--r);
  border: 1px solid var(--border);
  background: rgba(255, 255, 255, 0.02);
}

.avatar {
  width: 38px;
  height: 38px;
  flex: none;
  border-radius: 10px;
  display: grid;
  place-items: center;
  font-weight: 600;
  font-size: 15px;
  color: #fff;
  background: linear-gradient(135deg, var(--accent), var(--accent-2));
  background-size: cover;
  background-position: center;
  text-shadow: 0 1px 3px rgba(0, 0, 0, 0.4);
}

.info {
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.bio,
.room {
  font-size: 12px;
  color: var(--text-muted);
  margin: 0;
}

.crown {
  font-size: 10px;
  padding: 1px 6px;
  border-radius: 999px;
  background: var(--warn-soft);
  color: var(--warn);
}

.banned {
  font-size: 10px;
  padding: 1px 6px;
  border-radius: 999px;
  background: var(--danger-soft);
  color: var(--danger);
}

.bot {
  font-size: 9px;
  color: var(--accent-2);
}

.ops {
  flex: none;
  justify-content: flex-end;
  max-width: 260px;
}

@media (max-width: 720px) {
  .client {
    flex-direction: column;
  }
  .ops {
    max-width: none;
    justify-content: flex-start;
  }
}
</style>
