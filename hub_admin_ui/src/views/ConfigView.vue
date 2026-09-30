<script setup>
import { onMounted, reactive, ref } from 'vue';
import Card from '../components/Card.vue';
import AppButton from '../components/AppButton.vue';
import FormField from '../components/FormField.vue';
import { api } from '../api.js';
import { run, toast } from '../toast.js';

const config = ref(null);
const keys = ref(null);
const busy = ref(false);
const loaded = ref(false);

const form = reactive({
  pingIntervalMs: 30000,
  hubPort: 9100,
  hubBindMode: 'ipv4',
  hubNoAuth: false,
  webAdminPort: 9200,
  webAdminBindMode: 'ipv4',
  publicBaseUrl: '',
  tlsEnabled: false,
  tlsCertificatePath: '',
  tlsPrivateKeyPath: '',
  tlsPassword: '',
});

// 首屏加载不弹 toast：连接状态由侧栏统一显示
async function load() {
  const [c, k] = await Promise.all([
    run(() => api.config(), { failure: () => '' }),
    run(() => api.keys(), { failure: () => '' }),
  ]);
  if (!c.ok) return;
  config.value = c.result;
  if (k.ok) keys.value = k.result;

  const upload = c.result.upload || {};
  Object.assign(form, {
    pingIntervalMs: c.result.pingIntervalMs ?? 30000,
    hubPort: c.result.hubPort ?? 9100,
    hubBindMode: c.result.hubBindMode ?? 'ipv4',
    hubNoAuth: !!c.result.hubNoAuth,
    webAdminPort: c.result.webAdminPort ?? 9200,
    webAdminBindMode: c.result.webAdminBindMode ?? 'ipv4',
    publicBaseUrl: upload.publicBaseUrl ?? '',
    tlsEnabled: !!c.result.tls?.enabled,
    tlsCertificatePath: c.result.tls?.certificatePath ?? '',
    tlsPrivateKeyPath: c.result.tls?.privateKeyPath ?? '',
    tlsPassword: '',
  });
  loaded.value = true;
}

onMounted(load);

// 端口/绑定/TLS 在 HubService.init() 一次性读取，心跳间隔在建定时器时被捕获，
// 其余项实时生效
const NEEDS_RESTART = {
  hubPort: 'Hub 端口',
  hubBindMode: 'Hub 绑定',
  webAdminPort: '管理端口',
  webAdminBindMode: '管理端口绑定',
  tlsEnabled: 'TLS 开关',
  tlsCertificatePath: '证书路径',
  tlsPrivateKeyPath: '私钥路径',
  tlsPassword: '证书密码',
  pingIntervalMs: '心跳间隔',
};

async function save() {
  busy.value = true;
  const res = await run(() => api.saveConfig({ ...form }), {
    success: (r) => {
      const changed = r?.changed || [];
      if (!changed.length) return '已保存（无变更）';
      const restart = changed.filter((k) => NEEDS_RESTART[k]);
      const base = `已保存：${changed.join('、')}`;
      return restart.length
        ? `${base}（${restart.map((k) => NEEDS_RESTART[k]).join('、')} 需重启 Hub 生效）`
        : `${base}，已即时生效`;
    },
    failure: (e) => `保存失败：${e?.message}`,
  });
  busy.value = false;
  if (res.ok) load();
}

async function rotate(admin) {
  const what = admin ? '管理层' : '用户层';
  if (
    !confirm(
      `轮换${what}令牌？\n\n当前所有使用该令牌的客户端与脚本会立刻失效，需要重新配置。`,
    )
  ) {
    return;
  }
  busy.value = true;
  const res = await run(() => api.rotateKey(admin), {
    success: '已轮换',
    failure: (e) => `轮换失败：${e?.message}`,
  });
  busy.value = false;
  if (res.ok) load();
}

async function restart() {
  if (!confirm('重启 Hub 服务？\n所有连接会断开，房间配置会重新载入。')) return;
  busy.value = true;
  const res = await run(() => api.restart(), { success: '正在重启…' });
  busy.value = false;
  if (res.ok) {
    // 服务回来之前不要继续操作
    setTimeout(() => window.location.reload(), 2500);
  }}

async function autoIp() {
  const res = await run(() => api.publicIp(), { failure: (e) => e?.message });
  if (res.ok) {
    form.publicBaseUrl = res.result.url.replace(/:\d+$/, '');
    toast(`已填入 ${form.publicBaseUrl}，记得保存`);
  }
}
</script>

<template>
  <div class="stack">
    <div v-if="!loaded" class="empty">正在读取配置…</div>

    <template v-else>
      <Card title="服务" subtitle="端口、绑定与 TLS 在 Hub 启动时读取，改动后需重启 Hub">
        <div class="form">
          <FormField v-model="form.hubPort" type="number" label="Hub 端口" :min="1024" :max="65535" />
          <label class="field">
            <span class="label">Hub 绑定</span>
            <select v-model="form.hubBindMode">
              <option value="ipv4">IPv4 (0.0.0.0)</option>
              <option value="ipv6">IPv6 (::)</option>
              <option value="both">IPv4 + IPv6</option>
            </select>
          </label>
          <FormField v-model="form.webAdminPort" type="number" label="管理页端口" :min="1024" :max="65535" />
          <label class="field">
            <span class="label">管理页绑定</span>
            <select v-model="form.webAdminBindMode">
              <option value="ipv4">IPv4 (0.0.0.0)</option>
              <option value="ipv6">IPv6 (::)</option>
              <option value="both">IPv4 + IPv6</option>
            </select>
          </label>
          <FormField
            v-model="form.pingIntervalMs"
            type="number"
            label="心跳间隔 (ms)"
            :min="10000"
            :max="120000"
            :step="1000"
            hint="同时是判定客户端掉线的超时时间"
          />
        </div>

        <label class="check danger-zone">
          <input v-model="form.hubNoAuth" type="checkbox" />
          <span>
            <strong>关闭鉴权</strong>
            <em>任何能连到该端口的人都可以读写全部数据、发消息。仅在完全可信的网络里开启。</em>
          </span>
        </label>
      </Card>

      <Card title="API 令牌" subtitle="用户层令牌用于一般接口，管理层令牌可管理配置">
        <div v-if="keys" class="keys">
          <div class="key-row">
            <div>
              <div class="k-label">用户层令牌</div>
              <code>{{ keys.userKey }}</code>
              <div class="faint tiny">
                {{ keys.usingFixedKey ? '使用固定令牌' : '随机令牌，重启后变化' }}
              </div>
            </div>
            <AppButton size="sm" variant="ghost" :disabled="keys.usingFixedKey" @click="rotate(false)">
              轮换
            </AppButton>
          </div>
          <div class="key-row">
            <div>
              <div class="k-label">管理层令牌</div>
              <code>{{ keys.adminKey }}</code>
              <div class="faint tiny">
                {{ keys.usingAdminFixedKey ? '使用固定令牌' : '随机令牌，重启后变化' }}
              </div>
            </div>
            <AppButton size="sm" variant="ghost" :disabled="keys.usingAdminFixedKey" @click="rotate(true)">
              轮换
            </AppButton>
          </div>
        </div>
        <p class="faint tiny">
          令牌只显示打码值；完整值请在应用设置页查看。启用固定令牌后无法在此轮换。
        </p>
      </Card>

      <Card title="HTTPS / WSS" subtitle="需要同时提供证书链与私钥文件">
        <label class="check">
          <input v-model="form.tlsEnabled" type="checkbox" />
          <span><strong>启用 TLS</strong></span>
        </label>
        <div class="form">
          <FormField
            v-model="form.tlsCertificatePath"
            label="证书链路径"
            mono
            placeholder="/etc/letsencrypt/live/example.com/fullchain.pem"
            hint="Let's Encrypt 请用 fullchain.pem，否则部分客户端握手失败"
          />
          <FormField v-model="form.tlsPrivateKeyPath" label="私钥路径" mono placeholder="privkey.pem" />
          <FormField
            v-model="form.tlsPassword"
            type="password"
            label="私钥密码"
            placeholder="留空表示不修改"
            hint="不会回显；留空保存即保持原值"
          />
        </div>
      </Card>

      <Card title="图片外链" subtitle="用于把上传的图片地址拼成公网可访问的绝对地址">
        <FormField
          v-model="form.publicBaseUrl"
          label="公网基础地址"
          mono
          placeholder="http://192.168.1.10:9100"
        />
        <div class="row" style="margin-top: 10px">
          <AppButton size="sm" variant="ghost" @click="autoIp">自动探测本机公网地址</AppButton>
        </div>
      </Card>

      <div class="row wrap actions">
        <AppButton variant="primary" :busy="busy" @click="save">保存全部配置</AppButton>
        <AppButton variant="danger" :busy="busy" @click="restart">重启 Hub</AppButton>
      </div>
    </template>
  </div>
</template>

<style scoped>
.form {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
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
  align-items: flex-start;
  gap: 9px;
  margin-top: 16px;
  font-size: 13px;
  cursor: pointer;
}
.check input {
  margin-top: 2px;
  accent-color: var(--accent);
}
.check em {
  display: block;
  font-style: normal;
  font-size: 12px;
  color: var(--text-faint);
  margin-top: 3px;
  line-height: 1.5;
}

.danger-zone {
  padding: 12px;
  border-radius: var(--r-sm);
  border: 1px solid rgba(248, 113, 113, 0.3);
  background: var(--danger-soft);
}

.keys {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin-bottom: 12px;
}

.key-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 12px;
  border-radius: var(--r-sm);
  border: 1px solid var(--border);
  background: rgba(255, 255, 255, 0.02);
}

.k-label {
  font-size: 12px;
  color: var(--text-muted);
}

code {
  font-family: var(--mono);
  font-size: 13px;
  color: var(--accent);
}

.tiny {
  font-size: 11px;
  margin-top: 3px;
}

.actions {
  padding-top: 4px;
}
</style>
