<script setup>
/**
 * 管理后台外壳：侧边导航 + 视图切换。
 * 轮询：活跃数据 5s；标签页隐藏时暂停，避免后台空转。
 */
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { api, onUnauthorizedOnce, setToken, getToken } from './api.js';
import { run } from './toast.js';
import ToastHost from './components/ToastHost.vue';
import LoginGate from './views/LoginGate.vue';
import OverviewView from './views/OverviewView.vue';
import StatsView from './views/StatsView.vue';
import RoomsView from './views/RoomsView.vue';
import ClientsView from './views/ClientsView.vue';
import SearchView from './views/SearchView.vue';
import LogsView from './views/LogsView.vue';
import ConfigView from './views/ConfigView.vue';
import UploadView from './views/UploadView.vue';
import IntegrationsView from './views/IntegrationsView.vue';
import LanView from './views/LanView.vue';
import AiView from './views/AiView.vue';

const authed = ref(!!getToken());
const tab = ref('overview');
const online = ref(false);

const overview = ref(null);
const stats = ref(null);
const rooms = ref([]);
const clients = ref([]);

const NAV = [
  { key: 'overview', label: '概览', group: '运行' },
  { key: 'stats', label: '统计', group: '运行' },
  { key: 'logs', label: '日志', group: '运行' },
  { key: 'rooms', label: '房间', group: '内容' },
  { key: 'clients', label: '客户端', group: '内容' },
  { key: 'search', label: '检索', group: '内容' },
  { key: 'integrations', label: '集成', group: '设置' },
  { key: 'upload', label: '上传', group: '设置' },
  { key: 'ai', label: 'AI 机器人', group: '设置' },
  { key: 'lan', label: 'LAN 控制', group: '设置' },
  { key: 'config', label: '服务配置', group: '设置' },
];

const groups = computed(() => {
  const map = new Map();
  for (const item of NAV) {
    if (!map.has(item.group)) map.set(item.group, []);
    map.get(item.group).push(item);
  }
  return [...map.entries()];
});

const VIEWS = {
  overview: OverviewView,
  stats: StatsView,
  rooms: RoomsView,
  clients: ClientsView,
  search: SearchView,
  logs: LogsView,
  config: ConfigView,
  upload: UploadView,
  integrations: IntegrationsView,
  lan: LanView,
  ai: AiView,
};
const current = computed(() => VIEWS[tab.value]);

let ticker = null;

async function refreshLive() {
  if (document.hidden || !authed.value) return;
  const [o, c] = await Promise.all([
    run(() => api.overview(), { failure: () => '' }),
    run(() => api.clients(), { failure: () => '' }),
  ]);
  if (o.ok) {
    overview.value = o.result;
    online.value = true;
  } else if (o.error?.status === 0) {
    online.value = false;
  }
  if (c.ok) clients.value = c.result.items || [];
}

async function refreshRooms() {
  if (document.hidden || !authed.value) return;
  const res = await run(() => api.rooms(), { failure: () => '' });
  if (res.ok) rooms.value = res.result.items || [];
}

async function refreshStats() {
  if (document.hidden || !authed.value) return;
  const res = await run(() => api.stats(), { failure: () => '' });
  if (res.ok) stats.value = res.result;
}

async function refreshAll() {
  await refreshLive();
  await Promise.all([refreshRooms(), refreshStats()]);
}

function startPolling() {
  stopPolling();
  ticker = setInterval(refreshLive, 5000);
}

function stopPolling() {
  if (ticker) clearInterval(ticker);
  ticker = null;
}

function onVisibility() {
  if (document.hidden) stopPolling();
  else if (authed.value) {
    refreshAll();
    startPolling();
  }
}

onMounted(async () => {
  onUnauthorizedOnce(() => {
    authed.value = false;
  });
  if (authed.value) {
    await refreshAll();
    startPolling();
  }
  document.addEventListener('visibilitychange', onVisibility);
});

onBeforeUnmount(() => {
  stopPolling();
  document.removeEventListener('visibilitychange', onVisibility);
});

function signOut() {
  if (!confirm('退出管理后台？令牌会从本机清除。')) return;
  setToken('');
  authed.value = false;
  stopPolling();
}
</script>

<template>
  <LoginGate v-if="!authed" @authenticated="authed = true; refreshAll(); startPolling()" />

  <div v-else class="shell">
    <aside class="side">
      <div class="brand">
        <span class="mark">◆</span>
        <div class="grow">
          <div class="b-name">Kostori Hub</div>
          <div class="b-ver faint">{{ overview?.version || '' }}</div>
        </div>
      </div>

      <nav>
        <div v-for="[group, items] in groups" :key="group" class="group">
          <div class="g-label">{{ group }}</div>
          <button
            v-for="item in items"
            :key="item.key"
            class="nav"
            :class="{ on: tab === item.key }"
            @click="tab = item.key"
          >
            {{ item.label }}
          </button>
        </div>
      </nav>

      <div class="side-foot">
        <span class="dot" :class="online ? 'ok' : 'off'" />
        <span class="faint tiny">{{ online ? '已连接' : '连接中断' }}</span>
        <button class="out ghost" @click="signOut">退出</button>
      </div>
    </aside>

    <main class="main">
      <KeepAlive>
        <component
          :is="current"
          :overview="overview"
          :stats="stats"
          :rooms="rooms"
          :clients="clients"
          :lobby-id="overview?.lobbyId || ''"
          @refresh="refreshAll"
        />
      </KeepAlive>
    </main>
  </div>

  <ToastHost />
</template>

<style scoped>
.shell {
  display: grid;
  grid-template-columns: var(--sidebar-w) 1fr;
  min-height: 100vh;
}

.side {
  display: flex;
  flex-direction: column;
  gap: 18px;
  padding: 16px 12px;
  border-right: 1px solid var(--border);
  background: rgba(11, 15, 26, 0.7);
  backdrop-filter: blur(8px);
  position: sticky;
  top: 0;
  height: 100vh;
}

.brand {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 0 6px;
}

.mark {
  font-size: 20px;
  background: linear-gradient(135deg, var(--accent), var(--accent-2));
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
}

.b-name {
  font-size: 14px;
  font-weight: 600;
}
.b-ver {
  font-size: 11px;
}

nav {
  display: flex;
  flex-direction: column;
  gap: 14px;
  overflow-y: auto;
  flex: 1;
}

.g-label {
  font-size: 10px;
  text-transform: uppercase;
  letter-spacing: 1px;
  color: var(--text-faint);
  padding: 0 8px 5px;
}

.nav {
  display: block;
  width: 100%;
  text-align: left;
  padding: 7px 10px;
  border: 0;
  border-radius: var(--r-sm);
  background: transparent;
  color: var(--text-muted);
  font: inherit;
  font-size: 13px;
  cursor: pointer;
  transition: background 0.13s ease, color 0.13s ease;
}
.nav:hover {
  background: rgba(255, 255, 255, 0.045);
  color: var(--text);
}
.nav.on {
  background: var(--accent-soft);
  color: var(--accent);
  font-weight: 500;
}

.side-foot {
  display: flex;
  align-items: center;
  gap: 7px;
  padding: 0 6px;
}

.dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  flex: none;
}
.dot.ok {
  background: var(--ok);
  box-shadow: 0 0 6px var(--ok);
}
.dot.off {
  background: var(--text-faint);
}

.tiny {
  font-size: 11px;
}

.out {
  margin-left: auto;
  padding: 3px 8px;
  border-radius: var(--r-sm);
  border: 1px solid var(--border);
  background: transparent;
  color: var(--text-muted);
  font: inherit;
  font-size: 11.5px;
  cursor: pointer;
}
.out:hover {
  color: var(--text);
  border-color: var(--border-strong);
}

.main {
  padding: 22px 24px 48px;
  min-width: 0;
}

@media (max-width: 860px) {
  .shell {
    grid-template-columns: 1fr;
  }
  .side {
    position: static;
    height: auto;
    flex-direction: row;
    align-items: center;
    gap: 12px;
    overflow-x: auto;
    border-right: 0;
    border-bottom: 1px solid var(--border);
  }
  nav {
    flex-direction: row;
    gap: 6px;
    overflow-x: auto;
  }
  .g-label {
    display: none;
  }
  .nav {
    width: auto;
    white-space: nowrap;
  }
  .side-foot {
    display: none;
  }
  .main {
    padding: 16px 14px 40px;
  }
}
</style>
