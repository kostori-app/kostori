<script setup>
/**
 * 集成：入站 Webhook / 订阅 / Satori 机器人。
 * 三块放一起，因为它们都是「让外部系统接入 Hub」的配置。
 */
import { onMounted, reactive, ref } from 'vue';
import Card from '../components/Card.vue';
import AppButton from '../components/AppButton.vue';
import AppModal from '../components/AppModal.vue';
import FormField from '../components/FormField.vue';
import StatusBadge from '../components/StatusBadge.vue';
import { api } from '../api.js';
import { run, toast } from '../toast.js';

const webhooks = ref([]);
const rooms = ref([]);
const subs = ref([]);
const bots = ref([]);
const loading = ref(false);
const busy = ref(false);

// ── 新建入站 Webhook ──
const hookModal = ref(false);
const hookForm = reactive({ name: '', roomId: '' });

// ── 新建订阅 ──
const subModal = ref(false);
const subForm = reactive({
  type: 'webhook',
  wsDirection: 'reverse',
  listenHost: '',
  listenPort: '',
  url: '',
  heartbeatMs: '',
  token: '',
  note: '',
});

// ── 新建 Satori 机器人 ──
const botModal = ref(false);
const botForm = reactive({ name: '', avatarUrl: '', biography: '' });

async function loadAll() {
  loading.value = true;
  const [w, s, b] = await Promise.all([
    run(() => api.webhooks()),
    run(() => api.subscriptions()),
    run(() => api.satoriBots()),
  ]);
  if (w.ok) {
    webhooks.value = w.result.items || [];
    rooms.value = w.result.rooms || [];
  }
  if (s.ok) subs.value = s.result.items || [];
  if (b.ok) bots.value = b.result.items || [];
  loading.value = false;
}

onMounted(loadAll);

function copy(text, label) {
  navigator.clipboard?.writeText(text).then(
    () => toast(`${label}已复制`),
    () => toast('复制失败，请手动选中', 'err'),
  );
}

function needsUrl() {
  return subForm.type === 'webhook' || subForm.type === 'ws';
}
function needsListen() {
  return subForm.type === 'http' || (subForm.type === 'ws' && subForm.wsDirection === 'forward');
}

async function createHook() {
  if (!hookForm.name.trim() || !hookForm.roomId) return;
  busy.value = true;
  const res = await run(() => api.addWebhook(hookForm.name.trim(), hookForm.roomId), {
    success: '已签发令牌',
    failure: (e) => e?.message,
  });
  busy.value = false;
  if (res.ok) {
    hookModal.value = false;
    hookForm.name = '';
    loadAll();
  }
}

function removeHook(h) {
  if (!confirm(`删除入站 Webhook「${h.name}」？\n该令牌会立即失效。`)) return;
  run(() => api.deleteWebhook(h.id), {
    success: '已删除',
    failure: (e) => e?.message,
  }).then((r) => r.ok && loadAll());
}

async function createSub() {
  busy.value = true;
  const payload = {
    type: subForm.type,
    wsDirection: subForm.type === 'ws' ? subForm.wsDirection : undefined,
    listenHost: needsListen() ? subForm.listenHost || undefined : undefined,
    listenPort: needsListen() && subForm.listenPort ? Number(subForm.listenPort) : undefined,
    url: needsUrl() ? subForm.url : undefined,
    heartbeatMs: subForm.heartbeatMs ? Number(subForm.heartbeatMs) : undefined,
    token: subForm.token || undefined,
    note: subForm.note,
  };
  const res = await run(() => api.addSubscription(payload), {
    success: '已添加',
    failure: (e) => e?.message,
  });
  busy.value = false;
  if (res.ok) {
    subModal.value = false;
    Object.assign(subForm, {
      type: 'webhook', wsDirection: 'reverse', listenHost: '',
      listenPort: '', url: '', heartbeatMs: '', token: '', note: '',
    });
    loadAll();
  }
}

function removeSub(s) {
  if (!confirm(`删除订阅「${s.note || s.id}」？`)) return;
  run(() => api.deleteSubscription(s.id), { success: '已删除' }).then(
    (r) => r.ok && loadAll(),
  );
}

async function createBot() {
  if (!botForm.name.trim()) return;
  busy.value = true;
  const res = await run(() => api.addSatoriBot({ ...botForm, name: botForm.name.trim() }), {
    success: '已创建',
    failure: (e) => e?.message,
  });
  busy.value = false;
  if (res.ok) {
    botModal.value = false;
    Object.assign(botForm, { name: '', avatarUrl: '', biography: '' });
    loadAll();
  }
}

function toggleBot(b) {
  run(() => api.updateSatoriBot(b.id, { enabled: !b.enabled }), {
    success: b.enabled ? '已停用' : '已启用',
  }).then((r) => r.ok && loadAll());
}

function rotateBot(b) {
  if (!confirm(`轮换「${b.name}」的令牌？\n旧令牌立即失效，需要在 Koishi 等客户端更新。`)) return;
  run(() => api.rotateSatoriToken(b.id), { success: '已轮换' }).then(
    (r) => r.ok && loadAll(),
  );
}

function removeBot(b) {
  if (!confirm(`删除机器人「${b.name}」？`)) return;
  run(() => api.deleteSatoriBot(b.id), { success: '已删除' }).then(
    (r) => r.ok && loadAll(),
  );
}

const TYPE_LABEL = { ws: 'WebSocket', webhook: 'Webhook', http: 'HTTP' };
</script>

<template>
  <div class="stack">
    <Card
      title="入站 Webhook"
      subtitle="外部服务用这里的令牌向房间发消息（POST /hub/webhook/<令牌>）"
    >
      <template #actions>
        <AppButton size="sm" variant="primary" @click="hookModal = true">签发令牌</AppButton>
        <AppButton size="sm" :busy="loading" @click="loadAll">刷新</AppButton>
      </template>

      <div v-if="!webhooks.length" class="empty">还没有入站 Webhook</div>

      <ul v-else class="items">
        <li v-for="h in webhooks" :key="h.id">
          <div class="grow">
            <div class="row wrap">
              <strong>{{ h.name }}</strong>
              <span class="faint">→ {{ h.roomName }}</span>
            </div>
            <code class="mono">{{ h.url }}</code>
          </div>
          <div class="row">
            <AppButton size="sm" variant="ghost" @click="copy(h.url, '地址')">复制地址</AppButton>
            <AppButton size="sm" variant="danger" @click="removeHook(h)">删除</AppButton>
          </div>
        </li>
      </ul>
    </Card>

    <Card title="订阅" subtitle="把房间事件主动推给外部系统，或监听外部系统">
      <template #actions>
        <AppButton size="sm" variant="primary" @click="subModal = true">添加订阅</AppButton>
      </template>

      <div v-if="!subs.length" class="empty">还没有订阅</div>

      <ul v-else class="items">
        <li v-for="s in subs" :key="s.id">
          <div class="grow">
            <div class="row wrap">
              <strong>{{ s.note || '未命名' }}</strong>
              <span class="kind">{{ TYPE_LABEL[s.type] || s.type }}</span>
              <span v-if="s.type === 'ws'" class="kind">{{ s.wsDirection === 'forward' ? 'Hub 监听' : 'Hub 连接' }}</span>
              <StatusBadge
                :status="s.status === 'running' ? 'online' : s.status === 'error' ? 'busy' : 'offline'"
                :label="s.status"
              />
            </div>
            <code class="mono">{{ s.summary || s.url || '—' }}</code>
          </div>
          <div class="row">
            <AppButton
              size="sm"
              variant="ghost"
              :disabled="!s.token"
              @click="copy(s.token, '令牌')"
            >
              复制令牌
            </AppButton>
            <AppButton size="sm" variant="danger" @click="removeSub(s)">删除</AppButton>
          </div>
        </li>
      </ul>
    </Card>

    <Card title="Satori 机器人" subtitle="为 Koishi 等第三方客户端分配独立身份与令牌">
      <template #actions>
        <AppButton size="sm" variant="primary" @click="botModal = true">新建机器人</AppButton>
      </template>

      <div v-if="!bots.length" class="empty">还没有机器人档案</div>

      <ul v-else class="items">
        <li v-for="b in bots" :key="b.id">
          <div class="grow">
            <div class="row wrap">
              <strong>{{ b.name }}</strong>
              <StatusBadge
                :status="b.enabled ? (b.online ? 'online' : 'away') : 'offline'"
                :label="b.enabled ? (b.online ? '在线' : '离线') : '已停用'"
              />
            </div>
            <p v-if="b.biography" class="faint truncate">{{ b.biography }}</p>
            <code class="mono">{{ b.token || '（无令牌）' }}</code>
          </div>
          <div class="row wrap">
            <AppButton size="sm" variant="ghost" :disabled="!b.token" @click="copy(b.token, '令牌')">
              复制令牌
            </AppButton>
            <AppButton size="sm" variant="ghost" @click="toggleBot(b)">
              {{ b.enabled ? '停用' : '启用' }}
            </AppButton>
            <AppButton size="sm" variant="ghost" @click="rotateBot(b)">轮换</AppButton>
            <AppButton size="sm" variant="danger" @click="removeBot(b)">删除</AppButton>
          </div>
        </li>
      </ul>
    </Card>

    <AppModal v-if="hookModal" title="签发入站 Webhook 令牌" @close="hookModal = false">
      <div class="stack">
        <FormField v-model="hookForm.name" label="备注名" placeholder="例如：CI 通知" />
        <label class="field">
          <span class="label">目标房间</span>
          <select v-model="hookForm.roomId">
            <option value="" disabled>选择一个房间</option>
            <option v-for="r in rooms" :key="r.roomId" :value="r.roomId">{{ r.roomName }}</option>
          </select>
        </label>
      </div>
      <template #footer>
        <AppButton variant="ghost" @click="hookModal = false">取消</AppButton>
        <AppButton
          variant="primary"
          :busy="busy"
          :disabled="!hookForm.name.trim() || !hookForm.roomId"
          @click="createHook"
        >
          签发
        </AppButton>
      </template>
    </AppModal>

    <AppModal v-if="subModal" title="添加订阅" width="580px" @close="subModal = false">
      <div class="stack">
        <div class="two">
          <label class="field">
            <span class="label">类型</span>
            <select v-model="subForm.type">
              <option value="webhook">Webhook（Hub 主动 POST）</option>
              <option value="ws">WebSocket</option>
              <option value="http">HTTP（Hub 监听）</option>
            </select>
          </label>
          <label v-if="subForm.type === 'ws'" class="field">
            <span class="label">方向</span>
            <select v-model="subForm.wsDirection">
              <option value="forward">正向：Hub 监听等待连接</option>
              <option value="reverse">反向：Hub 主动连接</option>
            </select>
          </label>
        </div>

        <FormField
          v-if="needsUrl()"
          v-model="subForm.url"
          label="目标 URL"
          mono
          placeholder="https://example.com/hook"
        />
        <div v-if="needsListen()" class="two">
          <FormField v-model="subForm.listenHost" label="监听地址" mono placeholder="0.0.0.0" />
          <FormField v-model="subForm.listenPort" type="number" label="监听端口" :min="0" :max="65535" />
        </div>
        <div class="two">
          <FormField v-model="subForm.heartbeatMs" type="number" label="心跳间隔 (ms)" placeholder="留空则不发心跳" />
          <FormField v-model="subForm.token" label="令牌" mono placeholder="可选" />
        </div>
        <FormField v-model="subForm.note" label="备注" placeholder="便于识别" />
        <p class="faint tiny">
          Webhook 订阅会向目标地址推送所有房间事件，内容为明文，请自行确保传输安全。
        </p>
      </div>
      <template #footer>
        <AppButton variant="ghost" @click="subModal = false">取消</AppButton>
        <AppButton
          variant="primary"
          :busy="busy"
          :disabled="needsUrl() && !subForm.url"
          @click="createSub"
        >
          添加
        </AppButton>
      </template>
    </AppModal>

    <AppModal v-if="botModal" title="新建 Satori 机器人" @close="botModal = false">
      <div class="stack">
        <FormField v-model="botForm.name" label="显示名" placeholder="例如：Koishi" />
        <FormField v-model="botForm.avatarUrl" label="头像 URL" mono placeholder="可选" />
        <FormField v-model="botForm.biography" label="简介" placeholder="可选" />
        <p class="faint tiny">创建后会自动生成 32 位专属令牌，可在列表里复制。</p>
      </div>
      <template #footer>
        <AppButton variant="ghost" @click="botModal = false">取消</AppButton>
        <AppButton variant="primary" :busy="busy" :disabled="!botForm.name.trim()" @click="createBot">
          创建
        </AppButton>
      </template>
    </AppModal>
  </div>
</template>

<style scoped>
.items {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.items li {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  border-radius: var(--r);
  border: 1px solid var(--border);
  background: rgba(255, 255, 255, 0.02);
}

.items code {
  display: block;
  margin-top: 4px;
  color: var(--accent);
  word-break: break-all;
}

.kind {
  font-size: 10px;
  padding: 1px 6px;
  border-radius: 999px;
  background: var(--surface-3);
  color: var(--text-muted);
}

.two {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
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

.tiny {
  font-size: 11.5px;
  line-height: 1.5;
}

@media (max-width: 720px) {
  .items li {
    flex-direction: column;
    align-items: stretch;
  }
  .two {
    grid-template-columns: 1fr;
  }
}
</style>
