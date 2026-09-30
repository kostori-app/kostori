<script setup>
/** 登录门：需要管理层令牌。令牌存 localStorage，刷新免登录。 */
import { ref } from 'vue';
import { api, setToken, getToken } from '../api.js';

const emit = defineEmits(['authenticated']);
const token = ref(getToken());
const busy = ref(false);
const error = ref('');

async function submit() {
  if (!token.value.trim()) {
    error.value = '请输入管理层令牌';
    return;
  }
  busy.value = true;
  error.value = '';
  // 先拿令牌去探一个必须用管理层鉴权的接口，验证有效性
  const previous = getToken();
  setToken(token.value.trim());
  try {
    await api.keys();
    emit('authenticated');
  } catch (e) {
    setToken(previous);
    error.value = e?.status === 401 ? '令牌无效，请检查后重试' : e?.message || '验证失败';
  } finally {
    busy.value = false;
  }
}
</script>

<template>
  <div class="gate">
    <form class="panel" @submit.prevent="submit">
      <div class="logo">◆</div>
      <h1>Kostori Hub</h1>
      <p class="muted">管理后台需要<strong>管理层令牌</strong>（设置页可见）</p>

      <input
        v-model="token"
        class="key"
        type="password"
        placeholder="输入管理层令牌"
        spellcheck="false"
        autocomplete="off"
        autofocus
      />

      <p v-if="error" class="err">{{ error }}</p>

      <button class="go" type="submit" :disabled="busy">
        {{ busy ? '验证中…' : '进入' }}
      </button>
    </form>
  </div>
</template>

<style scoped>
.gate {
  min-height: 100vh;
  display: grid;
  place-items: center;
  padding: 24px;
}

.panel {
  width: 100%;
  max-width: 380px;
  padding: 32px 28px;
  border-radius: var(--r-lg);
  border: 1px solid var(--border);
  background: linear-gradient(180deg, var(--surface), var(--surface-2));
  box-shadow: var(--shadow-lg);
  text-align: center;
}

.logo {
  font-size: 30px;
  background: linear-gradient(135deg, var(--accent), var(--accent-2));
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
}

h1 {
  font-size: 18px;
  margin: 8px 0 6px;
}

.muted {
  font-size: 12.5px;
  line-height: 1.6;
}

.key {
  width: 100%;
  margin: 18px 0 10px;
  padding: 10px 12px;
  border-radius: var(--r-sm);
  border: 1px solid var(--border);
  background: #0e1526;
  color: var(--text);
  font-family: var(--mono);
  font-size: 13px;
}
.key:focus {
  outline: none;
  border-color: var(--accent);
  box-shadow: 0 0 0 3px var(--accent-soft);
}

.err {
  font-size: 12px;
  color: var(--danger);
  margin-bottom: 8px;
}

.go {
  width: 100%;
  padding: 10px;
  border: 0;
  border-radius: var(--r-sm);
  background: linear-gradient(135deg, var(--accent), var(--accent-2));
  color: #fff;
  font: inherit;
  font-weight: 500;
  cursor: pointer;
}
.go:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
</style>
