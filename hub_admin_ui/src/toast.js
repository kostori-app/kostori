import { ref } from 'vue';

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
 * 包一次异步操作：自动 toast 成功/失败，失败返回 { ok: false } 而不抛出，
 * 免得每个 handler 都写一遍 try/catch。
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
