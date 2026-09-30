/**
 * 后端 API 客户端。
 *
 * 全部走同源相对路径：不硬编码 9100/9200，否则在设置页改端口后页面就废了。
 */

const TOKEN_KEY = 'hub_admin_token';

export function getToken() {
  return localStorage.getItem(TOKEN_KEY) || '';
}

export function setToken(value) {
  if (value) localStorage.setItem(TOKEN_KEY, value);
  else localStorage.removeItem(TOKEN_KEY);
}

/** 401 时广播，由根组件切回登录态 */
const onUnauthorized = new Set();
export function onUnauthorizedOnce(fn) {
  onUnauthorized.add(fn);
  return () => onUnauthorized.delete(fn);
}

export class ApiError extends Error {
  constructor(message, status, body) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.body = body;
  }
}

async function request(method, path, { body, signal } = {}) {
  const headers = { Accept: 'application/json' };
  const token = getToken();
  if (token) headers.Authorization = `Bearer ${token}`;
  if (body !== undefined) headers['Content-Type'] = 'application/json';

  let res;
  try {
    res = await fetch(path, {
      method,
      headers,
      signal,
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch (e) {
    if (e?.name === 'AbortError') throw e;
    throw new ApiError('无法连接到 Hub 服务，请确认它仍在运行', 0, null);
  }

  const text = await res.text();
  let data = null;
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      data = null; // 非 JSON（网关错误页之类）
    }
  }

  if (res.status === 401) {
    for (const fn of onUnauthorized) fn();
  }
  if (!res.ok) {
    const message =
      data?.error || data?.message || `请求失败（HTTP ${res.status}）`;
    throw new ApiError(message, res.status, data);
  }
  return data;
}

const get = (path, opts) => request('GET', path, opts);
const post = (path, body, opts) => request('POST', path, { ...opts, body: body ?? {} });
const put = (path, body, opts) => request('PUT', path, { ...opts, body: body ?? {} });
const del = (path, opts) => request('DELETE', path, opts);

const enc = encodeURIComponent;

export const api = {
  overview: () => get('/api/admin/overview'),
  stats: () => get('/api/admin/stats'),

  rooms: () => get('/api/admin/rooms'),
  roomMessages: (roomId, limit = 100) =>
    get(`/api/admin/rooms/${enc(roomId)}/messages?limit=${limit}`),
  sendRoomMessage: (roomId, text, asBot) =>
    post(`/api/admin/rooms/${enc(roomId)}/message`, { text, asBot }),
  deleteRoom: (roomId) => del(`/api/admin/rooms/${enc(roomId)}`),

  clients: () => get('/api/admin/clients'),
  muteClient: (id, seconds) => post(`/api/admin/clients/${enc(id)}/mute`, { seconds }),
  unmuteClient: (id) => post(`/api/admin/clients/${enc(id)}/unmute`),
  kickClient: (id) => post(`/api/admin/clients/${enc(id)}/kick`),
  banClient: (id) => post(`/api/admin/clients/${enc(id)}/ban`),
  unbanClient: (id) => post(`/api/admin/clients/${enc(id)}/unban`),
  setClientAdmin: (id, value) => post(`/api/admin/clients/${enc(id)}/admin`, { value }),

  search: (q, room) => {
    const params = new URLSearchParams({ q });
    if (room) params.set('room', room);
    return get(`/api/admin/search?${params}`);
  },
  pinned: (room) =>
    get(`/api/admin/pinned${room ? `?room=${enc(room)}` : ''}`),

  logs: ({ limit = 200, level } = {}) => {
    const params = new URLSearchParams({ limit: String(limit) });
    if (level) params.set('level', level);
    return get(`/api/admin/logs?${params}`);
  },

  config: () => get('/api/admin/config'),
  saveConfig: (patch) => post('/api/admin/config', patch),
  keys: () => get('/api/admin/keys'),
  rotateKey: (admin) => post('/api/admin/keys/rotate', { admin: !!admin }),
  publicIp: () => get('/api/admin/public-ip'),
  restart: () => post('/api/admin/restart'),

  uploadConfig: () => get('/api/admin/upload'),
  saveUploadConfig: (patch) => post('/api/admin/upload', patch),

  webhooks: () => get('/api/admin/webhooks'),
  addWebhook: (name, roomId) => post('/api/admin/webhooks', { name, roomId }),
  deleteWebhook: (id) => del(`/api/admin/webhooks/${enc(id)}`),

  subscriptions: () => get('/api/admin/subscriptions'),
  addSubscription: (payload) => post('/api/admin/subscriptions', payload),
  deleteSubscription: (id) => del(`/api/admin/subscriptions/${enc(id)}`),

  satoriBots: () => get('/api/admin/satori-bots'),
  addSatoriBot: (payload) => post('/api/admin/satori-bots', payload),
  updateSatoriBot: (id, patch) => put(`/api/admin/satori-bots/${enc(id)}`, patch),
  deleteSatoriBot: (id) => del(`/api/admin/satori-bots/${enc(id)}`),
  rotateSatoriToken: (id) => post(`/api/admin/satori-bots/${enc(id)}/rotate-token`),

  lan: () => get('/api/admin/lan'),
  saveLanPin: (enabled, pin) => post('/api/admin/lan/pin', { enabled, pin }),

  ai: () => get('/api/admin/ai'),
  saveAi: (patch) => post('/api/admin/ai', patch),
};
