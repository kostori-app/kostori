<script setup>
import { computed } from 'vue';
import Card from '../components/Card.vue';
import StatTile from '../components/StatTile.vue';
import AppButton from '../components/AppButton.vue';
import { api } from '../api.js';
import { run } from '../toast.js';

const props = defineProps({
  overview: { type: Object, default: null },
  loading: { type: Boolean, default: false },
});
const emit = defineEmits(['refresh']);

const ov = computed(() => props.overview || {});
const has = computed(() => ov.value.app != null);

function uptime(seconds) {
  const s = Number(seconds) || 0;
  const d = Math.floor(s / 86400);
  const h = Math.floor((s % 86400) / 3600);
  const m = Math.floor((s % 3600) / 60);
  if (d) return `${d} 天 ${h} 小时`;
  if (h) return `${h} 小时 ${m} 分`;
  return `${m} 分钟`;
}

function detectIp() {
  return run(() => api.publicIp(), {
    success: (r) => `公网地址：${r.url}`,
    failure: (e) => e?.message,
  });
}
</script>

<template>
  <div class="stack">
    <Card title="服务状态" :subtitle="has ? `Kostori ${ov.version} · 端口 ${ov.port}` : ''">
      <template #actions>
        <AppButton size="sm" :busy="loading" @click="emit('refresh')">刷新</AppButton>
      </template>

      <div v-if="!has" class="empty">正在读取服务状态…</div>

      <template v-else>
        <div class="tiles">
          <StatTile
            label="在线客户端"
            :value="ov.clients"
            tone="accent"
            :sub="`直连同步 ${ov.directSyncMembers ?? 0} 人`"
          />
          <StatTile label="房间" :value="ov.rooms" :sub="`大厅 ${String(ov.lobbyId || '').slice(0, 8)}…`" />
          <StatTile
            label="黑名单"
            :value="ov.blacklist"
            :tone="ov.blacklist > 0 ? 'warn' : 'default'"
          />
          <StatTile label="运行时长" :value="uptime(ov.uptime)" />
        </div>

        <dl class="meta">
          <div><dt>监听地址</dt><dd class="mono">{{ has ? `0.0.0.0:${ov.port}` : '' }}</dd></div>
          <div><dt>鉴权</dt><dd>{{ ov.authMode === 'fixed' ? '固定密钥' : '随机密钥' }}</dd></div>
          <div><dt>管理鉴权</dt><dd>{{ ov.adminAuthMode === 'fixed' ? '固定密钥' : '随机密钥' }}</dd></div>
        </dl>
      </template>
    </Card>

    <Card title="公网访问" subtitle="由服务端探测，避免浏览器跨域">
      <div class="row wrap">
        <AppButton variant="ghost" @click="detectIp">自动获取公网地址</AppButton>
        <span class="faint">
          仅在你已自行做端口映射时有用；未映射时该地址无法访问。
        </span>
      </div>
    </Card>
  </div>
</template>

<style scoped>
.tiles {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  gap: 12px;
}

.meta {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 12px;
  margin-top: 18px;
  padding-top: 16px;
  border-top: 1px solid var(--border);
}

.meta dt {
  font-size: 11px;
  color: var(--text-faint);
  text-transform: uppercase;
  letter-spacing: 0.6px;
}

.meta dd {
  font-size: 13px;
  margin-top: 3px;
}
</style>
