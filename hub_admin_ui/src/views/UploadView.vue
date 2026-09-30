<script setup>
import { onMounted, reactive, ref } from 'vue';
import Card from '../components/Card.vue';
import AppButton from '../components/AppButton.vue';
import FormField from '../components/FormField.vue';
import { api } from '../api.js';
import { run } from '../toast.js';

const form = reactive({
  mode: 'serverLocal',
  maxSizeMB: 5,
  localStorePath: '',
  publicBaseUrl: '',
  oss: {
    endpoint: '',
    bucket: '',
    accessKeyId: '',
    accessKeySecret: '',
    region: '',
    prefix: '',
    cdnDomain: '',
  },
});
const secretConfigured = ref(false);
const loaded = ref(false);
const busy = ref(false);

const MODES = [
  { value: 'serverLocal', label: '服务端本地磁盘', hint: '文件存到应用数据目录，由 Hub 直接提供' },
  { value: 'serverOss', label: '服务端代理 OSS', hint: '文件经 Hub 转发到对象存储' },
  { value: 'clientOss', label: '客户端直传 OSS', hint: '浏览器直传，Hub 不经手文件' },
];

async function load() {
  const res = await run(() => api.uploadConfig());
  if (!res.ok) return;
  const c = res.result;
  form.mode = c.mode;
  form.maxSizeMB = Math.round((c.maxSizeBytes || 0) / (1024 * 1024));
  form.localStorePath = c.localStorePath ?? '';
  form.publicBaseUrl = c.publicBaseUrl ?? '';
  const oss = c.oss || {};
  secretConfigured.value = !!oss.secretConfigured;
  Object.assign(form.oss, {
    endpoint: oss.endpoint ?? '',
    bucket: oss.bucket ?? '',
    accessKeyId: oss.accessKeyId ?? '',
    region: oss.region ?? '',
    prefix: oss.prefix ?? '',
    cdnDomain: oss.cdnDomain ?? '',
  });
  loaded.value = true;
}

onMounted(load);

async function save() {
  busy.value = true;
  const payload = {
    mode: form.mode,
    maxSizeBytes: Math.round(Number(form.maxSizeMB) * 1024 * 1024),
    localStorePath: form.localStorePath,
    publicBaseUrl: form.publicBaseUrl,
  };
  // 留空密钥表示保留原值，由后端处理
  payload.oss = { ...form.oss, accessKeySecret: form.oss.accessKeySecret };
  if (form.mode === 'serverLocal') payload.oss = null;

  const res = await run(() => api.saveUploadConfig(payload), {
    success: '已保存',
    failure: (e) => `保存失败：${e?.message}`,
  });
  busy.value = false;
  if (res.ok) {
    form.oss.accessKeySecret = '';
    load();
  }
}
</script>

<template>
  <div class="stack">
    <div v-if="!loaded" class="empty">正在读取上传配置…</div>

    <template v-else>
      <Card title="存储模式" subtitle="决定图片存在哪里、谁负责上传">
        <div class="modes">
          <label
            v-for="m in MODES"
            :key="m.value"
            class="mode"
            :class="{ on: form.mode === m.value }"
          >
            <input v-model="form.mode" type="radio" :value="m.value" />
            <span class="m-label">{{ m.label }}</span>
            <span class="m-hint">{{ m.hint }}</span>
          </label>
        </div>
      </Card>

      <Card title="限制与路径">
        <div class="form">
          <FormField
            v-model="form.maxSizeMB"
            type="number"
            label="单文件上限 (MB)"
            :min="1"
            :max="512"
            hint="同时是服务端请求体的硬上限，超过会直接返回 413"
          />
          <FormField
            v-model="form.localStorePath"
            label="本地存储根目录"
            mono
            placeholder="留空则使用应用数据目录"
            :disabled="form.mode !== 'serverLocal'"
          />
          <FormField
            v-model="form.publicBaseUrl"
            label="公网基础地址"
            mono
            placeholder="http://192.168.1.10:9100"
            hint="留空则返回相对路径，由客户端按连接地址补全"
          />
        </div>
      </Card>

      <Card
        v-if="form.mode !== 'serverLocal'"
        title="对象存储 (S3 / OSS / MinIO)"
        subtitle="密钥加密存储，不会回显"
      >
        <div class="form">
          <FormField
            v-model="form.oss.endpoint"
            label="Endpoint"
            mono
            placeholder="https://oss-cn-hangzhou.aliyuncs.com"
          />
          <FormField v-model="form.oss.bucket" label="Bucket" mono placeholder="kostori" />
          <FormField v-model="form.oss.accessKeyId" label="Access Key ID" mono />
          <FormField
            v-model="form.oss.accessKeySecret"
            type="password"
            label="Access Key Secret"
            :placeholder="secretConfigured ? '已配置，留空表示不修改' : '尚未配置'"
          />
          <FormField v-model="form.oss.region" label="Region" mono placeholder="可选" />
          <FormField v-model="form.oss.prefix" label="Key 前缀" mono placeholder="hub/" />
          <FormField v-model="form.oss.cdnDomain" label="CDN 域名" mono placeholder="可选" />
        </div>
      </Card>

      <div class="row">
        <AppButton variant="primary" :busy="busy" @click="save">保存上传配置</AppButton>
      </div>
    </template>
  </div>
</template>

<style scoped>
.modes {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 10px;
}

.mode {
  display: flex;
  flex-direction: column;
  gap: 3px;
  padding: 12px;
  border-radius: var(--r);
  border: 1px solid var(--border);
  background: rgba(255, 255, 255, 0.02);
  cursor: pointer;
  transition: border-color 0.14s ease, background 0.14s ease;
}
.mode:hover {
  border-color: var(--border-strong);
}
.mode.on {
  border-color: var(--accent);
  background: var(--accent-soft);
}
.mode input {
  accent-color: var(--accent);
  margin-bottom: 4px;
}

.m-label {
  font-size: 13px;
  font-weight: 500;
}

.m-hint {
  font-size: 11.5px;
  color: var(--text-faint);
  line-height: 1.45;
}

.form {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 14px;
}
</style>
