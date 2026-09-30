<script setup>
import { onMounted, ref } from 'vue';
import Card from '../components/Card.vue';
import AppButton from '../components/AppButton.vue';
import FormField from '../components/FormField.vue';
import StatusBadge from '../components/StatusBadge.vue';
import { api } from '../api.js';
import { run } from '../toast.js';

const lan = ref(null);
const busy = ref(false);
const pinEnabled = ref(false);
const pin = ref('');

const STATE = {
  idle: '未启动',
  listening: '等待连接',
  connected: '已连接',
  error: '出错',
  pinRequired: '等待 PIN',
};

async function load() {
  const res = await run(() => api.lan());
  if (res.ok) {
    lan.value = res.result;
    pinEnabled.value = !!res.result.pinEnabled;
  }
}

onMounted(load);

async function save() {
  busy.value = true;
  const res = await run(() => api.saveLanPin(pinEnabled.value, pin.value), {
    success: '已保存',
    failure: (e) => e?.message,
  });
  busy.value = false;
  if (res.ok) {
    pin.value = '';
    load();
  }
}
</script>

<template>
  <div class="stack">
    <div v-if="!lan" class="empty">正在读取状态…</div>

    <template v-else>
      <Card title="LAN 远程控制" subtitle="同一局域网内用手机/平板控制播放">
        <template #actions>
          <AppButton size="sm" :busy="busy" @click="load">刷新</AppButton>
        </template>

        <div class="status">
          <StatusBadge
            :status="lan.listening ? 'online' : 'offline'"
            :label="STATE[lan.state] || lan.state"
          />
          <div class="facts">
            <div><dt>端口</dt><dd class="mono">{{ lan.port }}</dd></div>
            <div><dt>当前连接</dt><dd>{{ lan.connectionCount }}</dd></div>
            <div>
              <dt>PIN 验证</dt>
              <dd :class="lan.pinEnabled ? 'ok' : 'warn'">
                {{ lan.pinEnabled ? '已开启' : '未开启' }}
              </dd>
            </div>
          </div>
        </div>

        <p v-if="lan.lastError" class="err">{{ lan.lastError }}</p>

        <ul v-if="lan.connectedDeviceIds?.length" class="devices">
          <li v-for="id in lan.connectedDeviceIds" :key="id" class="mono">{{ id }}</li>
        </ul>

        <p class="faint tiny">
          服务需要在应用的「局域网」页面手动开启（播放与导航回调由该页面注册）。
          绑定在 0.0.0.0 上，请勿将端口映射到公网。
        </p>
      </Card>

      <Card title="连接 PIN" subtitle="开启后新连接必须先输入正确 PIN 才能控制">
        <div class="stack">
          <label class="check">
            <input v-model="pinEnabled" type="checkbox" />
            <span>要求 PIN 验证</span>
          </label>
          <FormField
            v-model="pin"
            type="password"
            label="PIN（4-6 位数字）"
            mono
            placeholder="留空则不修改"
            :disabled="!pinEnabled"
            inputmode="numeric"
          />
          <p class="faint tiny">
            逐连接限 3 次尝试，并有跨连接的总闸门：10 分钟内累计失败 20 次将锁定 5 分钟。
            配置会持久化，无头模式（--service lan）同样生效。
          </p>
          <div>
            <AppButton variant="primary" :busy="busy" @click="save">保存 PIN 设置</AppButton>
          </div>
        </div>
      </Card>
    </template>
  </div>
</template>

<style scoped>
.status {
  display: flex;
  align-items: center;
  gap: 20px;
  flex-wrap: wrap;
}

.facts {
  display: flex;
  gap: 24px;
  flex-wrap: wrap;
}

.facts dt {
  font-size: 11px;
  color: var(--text-faint);
  text-transform: uppercase;
}
.facts dd {
  font-size: 15px;
  margin-top: 2px;
  font-variant-numeric: tabular-nums;
}

.ok {
  color: var(--ok);
}
.warn {
  color: var(--warn);
}

.devices {
  list-style: none;
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-top: 14px;
}
.devices li {
  font-size: 11px;
  padding: 3px 8px;
  border-radius: 999px;
  background: var(--surface-3);
  color: var(--text-muted);
}

.err {
  margin-top: 12px;
  font-size: 12.5px;
  color: var(--danger);
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

.tiny {
  font-size: 11.5px;
  line-height: 1.55;
  margin-top: 4px;
}
</style>
