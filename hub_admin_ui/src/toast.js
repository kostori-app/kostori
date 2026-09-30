import { ref } from 'vue';

/** 全局轻量 toast。 */
const toasts = ref([]);
let seq = 0;

export function useToasts() {
  return toasts;
}

export function toast(message, level = 'info', timeout = 3200) {
  const id = ++seq;
  toasts.value.push({ id, message, level });
  if (timeout > 0) {
    setTimeout(() => {
      toasts.value = toasts.value.filter((t) => t.id !== id);
    }, timeout);
  }
}

export const toastOk = (m) => toast(m, 'ok');
export const toastErr = (m) => toast(m, 'err', 5200);

/**
 * 把一次异步操作包起来：自动 toast 成功/失败，失败时返回 false 而不是抛出。
 * 用于所有「点了按钮就发请求」的场景，避免每个 handler 重复写 try/catch。
 */
export async function run(fn, { success, failure } = {}) {
  try {
    const result = await fn();
    if (success) toastOk(typeof success === 'function' ? success(result) : success);
    return { ok: true, result };
  } catch (e) {
    const message = e?.message || String(e);
    if (failure) toast(typeof failure === 'function' ? failure(e) : failure);
    else toastErr(message);
    return { ok: false, error: e, message };
  }
}
