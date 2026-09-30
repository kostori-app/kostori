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
import AiView from './views/AiView.vue';

const authed = ref(!!getToken());
const tab = ref('overview');
const online = ref(false);
const drawer = ref(false);

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
  ai: AiView,
};
const current = computed(() => VIEWS[tab.value]);
const currentLabel = computed(
  () => NAV.find((n) => n.key === tab.value)?.label ?? '',
);

/** 窄屏下选完就收起抽屉 */
function pick(key) {
  tab.value = key;
  drawer.value = false;
  window.scrollTo({ top: 0 });
}

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

  <div v-else class="shell" :class="{ 'drawer-open': drawer }">
    <header class="topbar">
      <button class="burger" aria-label="打开菜单" @click="drawer = true">
        <span /><span /><span />
      </button>
      <span class="mark">◆</span>
      <strong class="grow truncate">{{ currentLabel }}</strong>
      <span class="dot" :class="online ? 'ok' : 'off'" :title="online ? '已连接' : '连接中断'" />
    </header>

    <div v-if="drawer" class="scrim" @click="drawer = false" />

    <aside class="side">
      <div class="brand">
        <span class="mark">◆</span>
        <div class="grow">
          <div class="b-name">Kostori Hub</div>
          <div class="b-ver faint">{{ overview?.version || '' }}</div>
        </div>
        <button class="close" aria-label="关闭菜单" @click="drawer = false">×</button>
      </div>

      <nav>
        <div v-for="[group, items] in groups" :key="group" class="group">
          <div class="g-label">{{ group }}</div>
          <button
            v-for="item in items"
            :key="item.key"
            class="nav"
            :class="{ on: tab === item.key }"
            @click="pick(item.key)"
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

.topbar {
  display: none;
  position: sticky;
  top: 0;
  z-index: 60;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  background: rgba(11, 15, 26, 0.92);
  backdrop-filter: blur(10px);
  border-bottom: 1px solid var(--border);
  font-size: 14px;
}

.burger {
  display: flex;
  flex-direction: column;
  justify-content: center;
  gap: 4px;
  width: 40px;
  height: 40px;
  padding: 0 9px;
  border: 1px solid var(--border);
  border-radius: var(--r-sm);
  background: var(--surface-3);
  cursor: pointer;
  flex: none;
}
.burger span {
  display: block;
  height: 2px;
  border-radius: 2px;
  background: var(--text);
}

.close {
  display: none;
  background: none;
  border: 0;
  color: var(--text-muted);
  font-size: 22px;
  line-height: 1;
  cursor: pointer;
  padding: 0 6px;
  flex: none;
}
.close:hover {
  color: var(--text);
}

.scrim {
  position: fixed;
  inset: 0;
  z-index: 70;
  background: rgba(4, 7, 15, 0.6);
  backdrop-filter: blur(2px);
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

  .topbar {
    display: flex;
  }

  .side {
    position: fixed;
    top: 0;
    left: 0;
    bottom: 0;
    z-index: 80;
    width: 264px;
    height: 100dvh;
    transform: translateX(-100%);
    /* 收起时移出 tab 顺序，否则键盘能聚焦到屏幕外的导航项 */
    visibility: hidden;
    transition: transform 0.22s ease, visibility 0.22s ease;
    border-right: 1px solid var(--border-strong);
    box-shadow: var(--shadow-lg);
  }
  .drawer-open .side {
    transform: translateX(0);
    visibility: visible;
  }

  .close {
    display: block;
  }

  .nav {
    padding: 11px 12px;
    font-size: 14px;
    border-radius: var(--r);
  }

  .main {
    padding: 14px 12px 40px;
  }
}

@media (prefers-reduced-motion: reduce) {
  .side {
    transition: none;
  }
}
</style>
