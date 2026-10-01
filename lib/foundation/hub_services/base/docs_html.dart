part of 'package:kostori/foundation/hub_services/services.dart';

/// `/docs` 页面。样式与脚本都内联，避免额外资源请求与 CSP 配置。
/// 数据来自同源的 `/openapi.json`。
String _buildDocsHtml() {
  return r'''<!DOCTYPE html>
<html lang="zh" data-theme="light">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<link rel="icon" href="/icon" type="image/png">
<script>
  // 提前定色，避免深色偏好用户看到白闪
  document.documentElement.dataset.theme =
    localStorage.getItem('kostori-docs-theme') ?? 'light';
</script>
<style>
  *, *::before, *::after { box-sizing: border-box; }

  :root {
    --bg: #fafbfc;
    --surface: #ffffff;
    --surface-2: #f4f6f9;
    --surface-3: #eceff4;
    --text: #0f172a;
    --text-2: #475569;
    --text-3: #94a3b8;
    --line: #e6eaf0;
    --line-2: #d3dae4;
    --brand: #4f46e5;
    --brand-2: #4338ca;
    --brand-soft: #eef2ff;
    --get: #0f766e;
    --get-soft: #ccfbf1;
    --post: #b45309;
    --post-soft: #fef3c7;
    --put: #7c3aed;
    --put-soft: #ede9fe;
    --del: #b91c1c;
    --del-soft: #fee2e2;
    --ok: #047857;
    --ok-soft: #d1fae5;
    --warn: #b45309;
    --warn-soft: #fef3c7;
    --err: #b91c1c;
    --err-soft: #fee2e2;
    --radius: 10px;
    --radius-sm: 7px;
    --shadow: 0 1px 2px rgba(15,23,42,.05);
    --shadow-md: 0 4px 16px rgba(15,23,42,.08);
    --shadow-lg: 0 12px 40px rgba(15,23,42,.12);
    --mono: ui-monospace, SFMono-Regular, 'SF Mono', Menlo, Consolas, monospace;
  }

  :root[data-theme="dark"] {
    --bg: #0a0c10;
    --surface: #11141a;
    --surface-2: #171b23;
    --surface-3: #1f242e;
    --text: #e8ecf3;
    --text-2: #a3adbd;
    --text-3: #6b7688;
    --line: #232936;
    --line-2: #2f3745;
    --brand: #818cf8;
    --brand-2: #6366f1;
    --brand-soft: #1e1b3a;
    --get: #2dd4bf;
    --get-soft: #11312e;
    --post: #fbbf24;
    --post-soft: #33260c;
    --put: #c4b5fd;
    --put-soft: #251f3d;
    --del: #f87171;
    --del-soft: #3a1616;
    --ok: #34d399;
    --ok-soft: #0f2e26;
    --warn: #fbbf24;
    --warn-soft: #33260c;
    --err: #f87171;
    --err-soft: #3a1616;
    --shadow: 0 1px 2px rgba(0,0,0,.4);
    --shadow-md: 0 4px 16px rgba(0,0,0,.45);
    --shadow-lg: 0 12px 40px rgba(0,0,0,.6);
  }

  html { scroll-behavior: smooth; }

  body {
    margin: 0;
    height: 100vh;
    display: flex;
    overflow: hidden;
    background: var(--bg);
    color: var(--text);
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Inter, Roboto,
                 'Noto Sans', 'PingFang SC', 'Microsoft YaHei', sans-serif;
    font-size: 14px;
    line-height: 1.6;
    -webkit-font-smoothing: antialiased;
  }

  code, pre, .mono { font-family: var(--mono); font-variant-ligatures: none; }

  /* ── Sidebar ─────────────────────────────────────────────────────── */
  #sidebar {
    width: 288px;
    flex: 0 0 288px;
    display: flex;
    flex-direction: column;
    background: var(--surface);
    border-right: 1px solid var(--line);
  }

  .side-top { padding: 20px 20px 16px; }

  .brand { display: flex; align-items: center; gap: 11px; }
  .brand img {
    width: 32px; height: 32px; border-radius: 9px;
    box-shadow: var(--shadow);
  }
  .brand-name { font-size: 15px; font-weight: 650; letter-spacing: -.2px; }

  .brand-meta {
    display: flex; align-items: center; gap: 8px;
    margin-top: 12px; font-size: 12px; color: var(--text-3);
  }
  .chip {
    padding: 2px 8px; border-radius: 100px;
    background: var(--surface-2); border: 1px solid var(--line);
    font-size: 11px; font-weight: 550; color: var(--text-2);
  }
  .live-dot {
    width: 6px; height: 6px; border-radius: 50%;
    background: var(--ok); box-shadow: 0 0 0 3px var(--ok-soft);
  }

  .side-actions { display: flex; gap: 8px; padding: 0 20px 14px; }

  .icon-btn {
    width: 32px; height: 32px; display: grid; place-items: center;
    background: var(--surface-2); color: var(--text-2);
    border: 1px solid var(--line); border-radius: var(--radius-sm);
    cursor: pointer; font-size: 14px; line-height: 1;
    transition: background .14s, color .14s, border-color .14s;
  }
  .icon-btn:hover { background: var(--surface-3); color: var(--text); border-color: var(--line-2); }
  .icon-btn[hidden] { display: none; }

  #search-wrap { padding: 0 20px 14px; position: relative; }
  #search-wrap::before {
    content: '⌕'; position: absolute; left: 31px; top: 50%;
    transform: translateY(-50%); color: var(--text-3); font-size: 15px;
    pointer-events: none;
  }
  #q {
    width: 100%; padding: 9px 12px 9px 34px;
    background: var(--surface-2); color: var(--text);
    border: 1px solid var(--line); border-radius: var(--radius-sm);
    font-size: 13px; outline: none;
    transition: border-color .14s, box-shadow .14s, background .14s;
  }
  #q::placeholder { color: var(--text-3); }
  #q:focus {
    border-color: var(--brand); background: var(--surface);
    box-shadow: 0 0 0 3px var(--brand-soft);
  }

  #nav { flex: 1; overflow-y: auto; padding: 0 12px 24px; }

  .nav-group {
    padding: 14px 8px 6px;
    font-size: 10.5px; font-weight: 650; letter-spacing: .7px;
    text-transform: uppercase; color: var(--text-3);
  }
  .nav-item {
    display: flex; align-items: center; gap: 9px;
    padding: 7px 9px; margin-bottom: 1px;
    border-radius: var(--radius-sm);
    cursor: pointer; color: var(--text-2);
    font-size: 13px; text-decoration: none;
    transition: background .12s, color .12s;
  }
  .nav-item:hover { background: var(--surface-2); color: var(--text); }
  .nav-item.active { background: var(--brand-soft); color: var(--brand-2); font-weight: 550; }
  .nav-item.hidden { display: none; }
  .nav-path {
    flex: 1; overflow: hidden; text-overflow: ellipsis;
    white-space: nowrap; font-family: var(--mono); font-size: 12px;
  }
  .nav-count {
    font-size: 10px; font-weight: 600; color: var(--text-3);
    background: var(--surface-2); padding: 1px 6px; border-radius: 100px;
  }
  .nav-item.active .nav-count { background: var(--surface); color: var(--brand-2); }

  .badge {
    flex: 0 0 auto; width: 42px; text-align: center;
    font-size: 9.5px; font-weight: 700; letter-spacing: .4px;
    padding: 2px 0; border-radius: 4px;
  }
  .b-get  { background: var(--get-soft);  color: var(--get); }
  .b-post { background: var(--post-soft); color: var(--post); }
  .b-put  { background: var(--put-soft);  color: var(--put); }
  .b-del  { background: var(--del-soft);  color: var(--del); }
  .b-ws   { background: var(--brand-soft);color: var(--brand-2); }

  /* ── Main ────────────────────────────────────────────────────────── */
  #main { flex: 1; overflow-y: auto; scroll-padding-top: 24px; }

  #hero { padding: 40px 48px 28px; border-bottom: 1px solid var(--line); }
  #hero h1 {
    margin: 0 0 8px; font-size: 30px; font-weight: 680;
    letter-spacing: -.8px;
  }
  #hero > p { margin: 0 0 26px; color: var(--text-2); font-size: 14.5px; max-width: 62ch; }

  .facts { display: flex; gap: 10px; flex-wrap: wrap; margin-bottom: 22px; }
  .fact {
    display: flex; flex-direction: column; gap: 3px;
    padding: 12px 16px; min-width: 148px;
    background: var(--surface); border: 1px solid var(--line);
    border-radius: var(--radius); box-shadow: var(--shadow);
  }
  .fact .k {
    font-size: 10.5px; font-weight: 600; letter-spacing: .5px;
    text-transform: uppercase; color: var(--text-3);
  }
  .fact .v { font-size: 14px; font-weight: 560; font-family: var(--mono); }

  .auth-box {
    padding: 16px 18px;
    background: var(--surface); border: 1px solid var(--line);
    border-radius: var(--radius); box-shadow: var(--shadow);
  }
  .auth-box h4 {
    margin: 0 0 10px; font-size: 12px; font-weight: 620;
    letter-spacing: .3px; color: var(--text-2);
    text-transform: uppercase;
  }
  .auth-row {
    display: flex; align-items: center; gap: 10px; flex-wrap: wrap;
    padding: 6px 0; font-size: 13px;
  }
  .auth-row + .auth-row { border-top: 1px dashed var(--line); }
  .auth-row code {
    padding: 3px 8px; background: var(--surface-2);
    border: 1px solid var(--line); border-radius: 5px; font-size: 12.5px;
  }
  .auth-row .hint { color: var(--text-3); font-size: 12px; }

  #content { padding: 32px 48px 96px; max-width: 1080px; }

  .sec-title {
    display: flex; align-items: baseline; gap: 10px;
    margin: 40px 0 14px;
  }
  .sec-title:first-child { margin-top: 0; }
  .sec-title h2 {
    margin: 0; font-size: 12px; font-weight: 650;
    letter-spacing: .8px; text-transform: uppercase; color: var(--text-3);
  }
  .sec-title .count { font-size: 12px; color: var(--text-3); }

  /* ── Endpoint card ───────────────────────────────────────────────── */
  .ep {
    background: var(--surface); border: 1px solid var(--line);
    border-radius: var(--radius); margin-bottom: 10px;
    box-shadow: var(--shadow); overflow: hidden;
    transition: box-shadow .16s, border-color .16s;
    scroll-margin-top: 24px;
  }
  .ep:hover { box-shadow: var(--shadow-md); border-color: var(--line-2); }
  .ep.hidden { display: none; }

  .ep-head {
    display: flex; align-items: center; gap: 12px;
    padding: 14px 18px; cursor: pointer; user-select: none;
  }
  .ep-head:hover { background: var(--surface-2); }
  .ep-path {
    flex: 1; font-family: var(--mono); font-size: 13.5px;
    font-weight: 500; min-width: 0; overflow-wrap: anywhere;
  }
  .ep-sum {
    color: var(--text-2); font-size: 12.5px;
    white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
    max-width: 42%;
  }
  .caret {
    flex: 0 0 auto; color: var(--text-3); font-size: 11px;
    transition: transform .2s;
  }
  .ep.open .caret { transform: rotate(90deg); }

  .ep-body { display: grid; grid-template-rows: 0fr; transition: grid-template-rows .22s ease; }
  .ep.open .ep-body { grid-template-rows: 1fr; }
  .ep-body > div { overflow: hidden; }
  .ep-inner { padding: 4px 18px 18px; border-top: 1px solid var(--line); }

  .desc { margin: 14px 0 0; color: var(--text-2); font-size: 13.5px; }

  .lock {
    display: inline-flex; align-items: center; gap: 4px;
    font-size: 11px; color: var(--warn);
    background: var(--warn-soft); padding: 2px 7px; border-radius: 100px;
  }

  .tabs {
    display: flex; gap: 2px; margin: 18px 0 0;
    border-bottom: 1px solid var(--line);
  }
  .tab {
    padding: 8px 14px; border: 0; background: none; cursor: pointer;
    font-size: 13px; font-weight: 520; color: var(--text-3);
    border-bottom: 2px solid transparent; margin-bottom: -1px;
    font-family: inherit;
  }
  .tab:hover { color: var(--text-2); }
  .tab.on { color: var(--brand-2); border-bottom-color: var(--brand); }

  .pane { display: none; padding-top: 16px; }
  .pane.on { display: block; }

  .kv { margin-bottom: 14px; }
  .kv-label {
    margin-bottom: 6px; font-size: 10.5px; font-weight: 620;
    letter-spacing: .5px; text-transform: uppercase; color: var(--text-3);
  }
  .kv-val {
    padding: 9px 12px; background: var(--surface-2);
    border: 1px solid var(--line); border-radius: var(--radius-sm);
    font-family: var(--mono); font-size: 12.5px;
    overflow-x: auto; white-space: pre-wrap; word-break: break-all;
  }

  .field { margin-bottom: 12px; }
  .field label {
    display: block; margin-bottom: 5px;
    font-size: 11.5px; font-weight: 560; color: var(--text-2);
  }
  .req { color: var(--del); margin-left: 3px; }
  .field input {
    width: 100%; padding: 8px 11px;
    background: var(--surface); color: var(--text);
    border: 1px solid var(--line-2); border-radius: var(--radius-sm);
    font-size: 13px; font-family: var(--mono); outline: none;
    transition: border-color .14s, box-shadow .14s;
  }
  .field input:focus {
    border-color: var(--brand); box-shadow: 0 0 0 3px var(--brand-soft);
  }
  .field .note { margin-top: 4px; font-size: 11.5px; color: var(--text-3); }

  .btn-row { display: flex; gap: 8px; margin-top: 16px; align-items: center; }
  .btn {
    display: inline-flex; align-items: center; gap: 6px;
    padding: 8px 16px; border-radius: var(--radius-sm);
    font-size: 13px; font-weight: 560; font-family: inherit;
    cursor: pointer; border: 1px solid transparent;
    transition: filter .14s, background .14s;
  }
  .btn-primary { background: var(--brand); color: #fff; }
  .btn-primary:hover { background: var(--brand-2); }
  .btn-primary:disabled { opacity: .55; cursor: not-allowed; }
  .btn-ghost {
    background: var(--surface); color: var(--text-2); border-color: var(--line-2);
  }
  .btn-ghost:hover { background: var(--surface-2); color: var(--text); }

  .res {
    margin-top: 14px; border: 1px solid var(--line);
    border-radius: var(--radius); overflow: hidden;
  }
  .res-head {
    display: flex; align-items: center; gap: 10px;
    padding: 9px 13px; background: var(--surface-2);
    border-bottom: 1px solid var(--line); font-size: 12px;
  }
  .status-pill {
    padding: 2px 9px; border-radius: 100px;
    font-size: 11px; font-weight: 680; font-family: var(--mono);
  }
  .s-ok   { background: var(--ok-soft);   color: var(--ok); }
  .s-warn { background: var(--warn-soft); color: var(--warn); }
  .s-err  { background: var(--err-soft);  color: var(--err); }
  .res-meta { color: var(--text-3); font-family: var(--mono); font-size: 11.5px; }
  .res-copy {
    margin-left: auto; cursor: pointer; color: var(--text-2);
    font-size: 11.5px; padding: 2px 8px; border-radius: 5px;
    border: 1px solid var(--line-2); background: var(--surface);
  }
  .res-copy:hover { color: var(--text); background: var(--surface-3); }
  .res-body {
    padding: 13px; font-family: var(--mono); font-size: 12px;
    line-height: 1.65; overflow-x: auto; max-height: 460px;
    white-space: pre; color: var(--text);
  }
  .img-out { padding: 13px; text-align: center; background: var(--surface-2); }
  .img-out img {
    max-width: 100%; border-radius: var(--radius-sm);
    box-shadow: var(--shadow-md);
  }

  .k-json { color: var(--brand-2); }
  .s-json { color: var(--get); }
  .n-json { color: var(--post); }
  .b-json { color: var(--put); }

  .spin {
    width: 15px; height: 15px; border-radius: 50%;
    border: 2px solid var(--line-2); border-top-color: var(--brand);
    animation: sp .7s linear infinite;
  }
  @keyframes sp { to { transform: rotate(360deg); } }

  .empty { padding: 60px 20px; text-align: center; color: var(--text-3); }

  ::-webkit-scrollbar { width: 9px; height: 9px; }
  ::-webkit-scrollbar-track { background: transparent; }
  ::-webkit-scrollbar-thumb {
    background: var(--line-2); border-radius: 100px;
    border: 2px solid transparent; background-clip: content-box;
  }
  ::-webkit-scrollbar-thumb:hover { background: var(--text-3); background-clip: content-box; }

  #scrim { display: none; }

  @media (max-width: 900px) {
    #sidebar {
      position: fixed; inset: 0 auto 0 0; z-index: 30;
      transform: translateX(-100%);
      transition: transform .24s cubic-bezier(.32,.72,0,1);
      box-shadow: var(--shadow-lg);
    }
    body.nav-open #sidebar { transform: none; }
    body.nav-open #scrim {
      display: block; position: fixed; inset: 0; z-index: 20;
      background: rgba(15,23,42,.45); backdrop-filter: blur(2px);
    }
    #nav-toggle { display: grid !important; }
    #hero { padding: 28px 20px 22px; }
    #hero h1 { font-size: 24px; }
    #content { padding: 24px 20px 72px; }
    .fact { flex: 1 1 calc(50% - 5px); min-width: 0; }
    .ep-head { flex-wrap: wrap; gap: 8px; }
    .ep-sum { max-width: 100%; flex-basis: 100%; white-space: normal; }
  }

  @media (max-width: 520px) {
    .fact { flex-basis: 100%; }
    .auth-row { flex-direction: column; align-items: flex-start; gap: 5px; }
  }
</style>
</head>
<body>

<div id="scrim" onclick="document.body.classList.remove('nav-open')"></div>

<nav id="sidebar">
  <div class="side-top">
    <div class="brand">
      <img src="/icon" alt="" onerror="this.style.display='none'">
      <span class="brand-name">Kostori API</span>
    </div>
    <div class="brand-meta">
      <span class="chip" id="ver">v—</span>
      <span class="live-dot"></span>
      <span>Online</span>
    </div>
  </div>

  <div class="side-actions">
    <button class="icon-btn" id="nav-toggle" title="菜单" aria-label="切换导航">☰</button>
    <button class="icon-btn" id="theme-btn" title="切换主题" aria-label="切换主题">◐</button>
    <button class="icon-btn" id="expand-all" title="全部展开" aria-label="全部展开">⊞</button>
  </div>

  <div id="search-wrap">
    <input type="search" id="q" placeholder="搜索路径、说明…" autocomplete="off" spellcheck="false">
  </div>

  <div id="nav"></div>
</nav>

<main id="main">
  <header id="hero">
    <h1>Kostori API</h1>
    <p id="desc">本地服务接口 — 在浏览器中直接查看并试用各接口。</p>
    <div class="facts" id="facts"></div>
    <div class="auth-box">
      <h4>鉴权方式</h4>
      <div class="auth-row">
        <span class="chip">HTTP</span>
        <code>Authorization: Bearer &lt;key&gt;</code>
        <span class="hint">用户令牌或管理令牌</span>
      </div>
      <div class="auth-row">
        <span class="chip">WebSocket</span>
        <code>?token=&lt;key&gt;</code>
        <span class="hint">作为查询参数传入</span>
      </div>
    </div>
  </header>

  <div id="content">
    <div class="empty"><div class="spin" style="margin:0 auto 12px"></div>正在加载接口…</div>
  </div>
</main>

<script>
const $  = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];

const esc = (s) => String(s ?? '').replace(/[&<>"']/g,
  (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

const METHOD_CLASS = { GET: 'b-get', POST: 'b-post', PUT: 'b-put', DELETE: 'b-del', WS: 'b-ws' };

function highlight(text) {
  return esc(text).replace(
    /("(\\u[\w]{4}|\\[^u]|[^\\"])*"(\s*:)?|\b(true|false|null)\b|-?\d+(?:\.\d*)?(?:[eE][+-]?\d+)?)/g,
    (m) => {
      if (m.startsWith('"')) return `<span class="${m.endsWith(':') ? 'k-json' : 's-json'}">${m}</span>`;
      if (m === 'true' || m === 'false') return `<span class="b-json">${m}</span>`;
      if (m === 'null') return `<span class="n-json">${m}</span>`;
      return `<span class="n-json">${m}</span>`;
    });
}

function formatSize(b) {
  if (b < 1024) return b + ' B';
  if (b < 1048576) return (b / 1024).toFixed(1) + ' KB';
  return (b / 1048576).toFixed(2) + ' MB';
}

function applyTheme(t) {
  document.documentElement.dataset.theme = t;
  localStorage.setItem('kostori-docs-theme', t);
}

$('#theme-btn').addEventListener('click', () =>
  applyTheme(document.documentElement.dataset.theme === 'light' ? 'dark' : 'light'));

$('#nav-toggle').addEventListener('click', () =>
  document.body.classList.toggle('nav-open'));

// ── Load & render ──────────────────────────────────────────────────────────
(async () => {
  let spec;
  try {
    const res = await fetch(location.origin + '/openapi.json');
    if (!res.ok) throw new Error('HTTP ' + res.status);
    spec = await res.json();
  } catch (e) {
    $('#content').innerHTML =
      `<div class="empty">无法加载接口定义：${esc(e.message)}</div>`;
    return;
  }

  const info = spec.info ?? {};
  const server = spec.servers?.[0]?.url ?? location.origin;
  const routes = [];

  for (const [path, ops] of Object.entries(spec.paths ?? {})) {
    for (const [method, op] of Object.entries(ops)) {
      if (!['get', 'post', 'put', 'delete', 'patch', 'ws'].includes(method)) continue;
      routes.push({ method: method.toUpperCase(), path, op, id: method + ' ' + path });
    }
  }

  routes.sort((a, b) => a.path.localeCompare(b.path) || a.method.localeCompare(b.method));

  $('#ver').textContent = 'v' + (info.version ?? '?');
  // info.description 首行是简介，其余是 markdown 形式的鉴权说明，
  // 下方已有专门的鉴权卡片展示，避免重复
  $('#desc').textContent =
    (info.description ?? '本地服务接口 — 在浏览器中直接查看并试用各接口。').split('\n')[0].trim();

  const authCount = routes.filter((r) => r.op.security?.length).length;
  $('#facts').innerHTML = [
    ['Server', server],
    ['Endpoints', routes.length],
    ['Auth Required', authCount],
  ].map(([k, v]) =>
    `<div class="fact"><span class="k">${k}</span><span class="v">${esc(v)}</span></div>`
  ).join('');

  // ── Sidebar ─────────────────────────────────────────────────────────────
  const groups = new Map();
  for (const r of routes) {
    const seg = r.path.split('/')[1] || 'root';
    if (!groups.has(seg)) groups.set(seg, []);
    groups.get(seg).push(r);
  }

  let navHtml = '';
  for (const [seg, list] of groups) {
    navHtml += `<div class="nav-group">${esc(seg)} <span class="nav-count">${list.length}</span></div>`;
    for (const r of list) {
      navHtml += `<a class="nav-item" href="#${cssId(r.id)}" data-id="${cssId(r.id)}">`
        + `<span class="badge ${METHOD_CLASS[r.method] ?? 'b-get'}">${r.method === 'WS' ? 'WS' : r.method.slice(0, 3)}</span>`
        + `<span class="nav-path">${esc(r.path.replace(/^\//, ''))}</span></a>`;
    }
  }
  $('#nav').innerHTML = navHtml;

  // ── Cards ───────────────────────────────────────────────────────────────
  $('#content').innerHTML = routes.map(renderCard).join('')
    || '<div class="empty">没有接口</div>';

  $$('.ep').forEach((el) => {
    $('.ep-head', el).addEventListener('click', () => el.classList.toggle('open'));
  });
  $$('.tab').forEach((tab) => {
    tab.addEventListener('click', () => {
      const card = tab.closest('.ep');
      $$('.tab', card).forEach((t) => t.classList.toggle('on', t === tab));
      $$('.pane', card).forEach((p) =>
        p.classList.toggle('on', p.dataset.pane === tab.dataset.tab));
    });
  });

  $('#expand-all').addEventListener('click', () => {
    const anyClosed = $$('.ep:not(.open)').length;
    $$('.ep').forEach((el) => el.classList.toggle('open', anyClosed));
    $('#expand-all').textContent = anyClosed ? '⊟' : '⊞';
  });

  // Scroll-spy
  const spy = new IntersectionObserver((entries) => {
    for (const en of entries) {
      if (!en.isIntersecting) continue;
      const id = en.target.id;
      $$('.nav-item').forEach((n) =>
        n.classList.toggle('active', n.dataset.id === id));
    }
  }, { rootMargin: '-72px 0px -70% 0px', threshold: 0 });
  $$('.ep').forEach((el) => spy.observe(el));

  // ── Search ──────────────────────────────────────────────────────────────
  const filter = (q) => {
    const needle = q.trim().toLowerCase();
    let visible = 0;
    for (const r of routes) {
      const card = $('#' + cssId(r.id));
      const nav = $(`.nav-item[data-id="${cssId(r.id)}"]`);
      const hay = (r.path + ' ' + (r.op.summary || '') + ' ' + (r.op.description || '')).toLowerCase();
      const hit = !needle || hay.includes(needle);
      card?.classList.toggle('hidden', !hit);
      nav?.classList.toggle('hidden', !hit);
      if (hit) visible++;
    }
    $('#content').querySelectorAll('.sec-title').forEach((s) => {
      let n = 0;
      let el = s.nextElementSibling;
      while (el && !el.classList.contains('sec-title')) {
        if (el.classList.contains('ep') && !el.classList.contains('hidden')) n++;
        el = el.nextElementSibling;
      }
      s.style.display = n ? '' : 'none';
    });
    if (needle) {
      let empty = $('#content').querySelector('.empty');
      if (!visible) {
        if (!empty) {
          empty = document.createElement('div');
          empty.className = 'empty';
          empty.textContent = '没有匹配的接口';
          $('#content').appendChild(empty);
        }
        empty.style.display = '';
      } else if (empty) {
        empty.style.display = 'none';
      }
    }
  };
  $('#q').addEventListener('input', (e) => filter(e.target.value));

  document.addEventListener('keydown', (e) => {
    if (e.key === '/' && document.activeElement !== $('#q')) {
      e.preventDefault();
      $('#q').focus();
    }
    if (e.key === 'Escape') {
      document.body.classList.remove('nav-open');
      $('#q').blur();
    }
  });

  function cssId(s) { return s.replace(/[^a-zA-Z0-9]/g, '_'); }
})();

function renderCard(r) {
  const op = r.op;
  const id = r.method + ' ' + r.path;
  const domId = id.replace(/[^a-zA-Z0-9]/g, '_');
  const params = (op.parameters ?? []);
  const needsAuth = (op.security?.length ?? 0) > 0;

  const fields = params.map((p) => `
    <div class="field">
      <label>${esc(p.name)}${p.required ? '<span class="req">*</span>' : ''}</label>
      <input id="in_${domId}_${esc(p.name)}" placeholder="${esc(p.example ?? '')}"
             autocomplete="off" spellcheck="false">
      ${p.description ? `<div class="note">${esc(p.description)}</div>` : ''}
    </div>`).join('');

  return `<article class="ep" id="${domId}">
    <div class="ep-head">
      <span class="badge ${METHOD_CLASS[r.method] ?? 'b-get'}">${r.method === 'WS' ? 'WS' : r.method}</span>
      <span class="ep-path">${esc(r.path)}</span>
      ${needsAuth ? '<span class="lock">需鉴权</span>' : ''}
      <span class="ep-sum">${esc(op.summary || '')}</span>
      <span class="caret">▶</span>
    </div>
    <div class="ep-body"><div>
      <div class="ep-inner">
        ${op.description ? `<p class="desc">${esc(op.description)}</p>` : ''}
        <div class="tabs">
          <button class="tab on" data-tab="docs">文档</button>
          <button class="tab" data-tab="try">试用</button>
        </div>
        <div class="pane on" data-pane="docs">
          ${op.response ? `<div class="kv">
            <div class="kv-label">响应</div>
            <div class="kv-val">${esc(op.response)}</div>
          </div>` : ''}
          ${params.length ? `<div class="kv">
            <div class="kv-label">参数</div>
            <div class="kv-val">${esc(params.map((p) =>
              `${p.name}${p.required ? ' (必填)' : ''}${p.in ? ' · ' + p.in : ''}`).join('\n'))}</div>
          </div>` : '<div class="kv"><div class="kv-label">参数</div><div class="kv-val">无</div></div>'}
        </div>
        <div class="pane" data-pane="try">
          ${fields || '<div class="field"><label>无参数</label></div>'}
          <div class="btn-row">
            <button class="btn btn-primary" onclick="sendReq(this)">发送请求</button>
            <button class="btn btn-ghost" onclick="clearReq(this)">清空</button>
          </div>
        </div>
      </div>
    </div></div>
  </article>`;
}

async function sendReq(btn) {
  const card = btn.closest('.ep');
  const pane = btn.closest('.pane');
  let resBox = $('.res', pane);
  if (!resBox) {
    resBox = document.createElement('div');
    resBox.className = 'res';
    pane.appendChild(resBox);
  }

  const path = $('.ep-path', card).textContent;
  const method = $('.badge', card).textContent.trim().toUpperCase();
  const inputs = $$('.field input', pane);

  const query = new URLSearchParams();
  let body;
  for (const el of inputs) {
    const v = el.value.trim();
    if (!v) continue;
    const name = el.id.split('_').slice(2).join('_');
    if (name.toLowerCase() === 'authorization' || name.toLowerCase() === 'api_key'
        || name.toLowerCase() === 'token') {
      query.set(name, v);
    } else if (method === 'GET' || method === 'WS') {
      query.set(name, v);
    } else {
      body = v;
    }
  }

  const qs = query.toString();
  const url = location.origin + path + (qs ? '?' + qs : '');

  btn.disabled = true;
  resBox.innerHTML = '<div class="res-head"><div class="spin"></div></div>';

  const t0 = performance.now();
  try {
    const opt = { method: method === 'WS' ? 'GET' : method };
    if (body !== undefined) {
      opt.headers = { 'Content-Type': 'application/json' };
      opt.body = body;
    }
    const res = await fetch(url, opt);
    const ms = Math.round(performance.now() - t0);
    const ct = res.headers.get('content-type') || '';
    if (ct.startsWith('image/')) {
      const blob = await res.blob();
      const objUrl = URL.createObjectURL(blob);
      resBox.innerHTML = `<div class="res-head">
          <span class="status-pill ${res.ok ? 's-ok' : 's-err'}">${res.status}</span>
          <span class="res-meta">${ms}ms · ${formatSize(blob.size)} · ${esc(ct)}</span>
        </div>
        <div class="img-out"><img src="${objUrl}" alt="响应图像"></div>`;
    } else {
      const text = await res.text();
      renderRes(resBox, res, text, ms, ct);
    }
  } catch (e) {
    resBox.innerHTML = `<div class="res-head">
        <span class="status-pill s-err">ERR</span></div>
      <div class="res-body" style="color:var(--err)">${esc(e.message)}</div>`;
  } finally {
    btn.disabled = false;
  }
}

function renderRes(box, res, text, ms, ct) {
  const cls = res.ok ? 's-ok' : (res.status >= 500 ? 's-err' : 's-warn');
  let body;
  try {
    body = `<div class="res-body">${highlight(JSON.stringify(JSON.parse(text), null, 2))}</div>`;
  } catch {
    body = `<div class="res-body">${esc(text)}</div>`;
  }
  box.innerHTML = `<div class="res-head">
      <span class="status-pill ${cls}">${res.status}</span>
      <span class="res-meta">${ms}ms · ${formatSize(new TextEncoder().encode(text).length)}</span>
      <span class="res-copy" onclick="copyRes(this)">复制</span>
    </div>${body}`;
  box.dataset.raw = text;
}

function copyRes(el) {
  navigator.clipboard.writeText(el.closest('.res').dataset.raw || '');
  const old = el.textContent;
  el.textContent = '已复制';
  setTimeout(() => { el.textContent = old; }, 1200);
}

function clearReq(btn) {
  const pane = btn.closest('.pane');
  $$('.field input', pane).forEach((i) => { i.value = ''; });
  $('.res', pane)?.remove();
}
</script>
</body>
</html>
''';
}
