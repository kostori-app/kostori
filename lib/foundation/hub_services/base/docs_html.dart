part of 'package:kostori/foundation/hub_services/services.dart';

String _buildDocsHtml() {
  return r'''<!DOCTYPE html>
<html lang="zh">
<head>
  <title>Kostori API</title>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="icon" href="/icon" type="image/png">
  <style>
    *, *::before, *::after { box-sizing: border-box; }
 
    :root {
      --bg: #080c14;
      --surface: #0d1420;
      --surface2: #111a2a;
      --surface3: #162033;
      --border: #1e2d45;
      --border2: #243550;
      --accent: #3b82f6;
      --accent2: #2563eb;
      --accent-glow: rgba(59,130,246,0.15);
      --text: #dde6f5;
      --text-muted: #6b82a0;
      --green: #34d399;
      --blue: #60a5fa;
      --cyan: #22d3ee;
      --orange: #fb923c;
      --red: #f87171;
      --yellow: #fbbf24;
    }
 
    body {
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Inter', sans-serif;
      background: var(--bg);
      color: var(--text);
      display: flex;
      height: 100vh;
      overflow: hidden;
    }
 
    /* ── Sidebar ── */
    #sidebar {
      width: 268px;
      min-width: 268px;
      background: var(--surface);
      border-right: 1px solid var(--border);
      display: flex;
      flex-direction: column;
      overflow: hidden;
    }
 
    #sidebar-header {
      padding: 20px 18px 14px;
      border-bottom: 1px solid var(--border);
      background: linear-gradient(180deg, rgba(59,130,246,0.06) 0%, transparent 100%);
    }
 
    #sidebar-header .logo {
      display: flex;
      align-items: center;
      gap: 10px;
      margin-bottom: 10px;
    }
 
    #sidebar-header .logo img {
      width: 30px; height: 30px;
      border-radius: 8px;
      box-shadow: 0 0 0 1px var(--border2), 0 0 12px rgba(59,130,246,0.25);
    }
 
    #sidebar-header .logo span {
      font-size: 15px;
      font-weight: 700;
      color: var(--text);
      letter-spacing: -0.3px;
    }
 
    .version-row { display: flex; align-items: center; gap: 8px; }
 
    #sidebar-header .version {
      font-size: 10px;
      color: var(--text-muted);
      background: var(--surface2);
      border: 1px solid var(--border);
      border-radius: 4px;
      padding: 2px 7px;
    }
 
    .status-dot {
      width: 7px; height: 7px;
      border-radius: 50%;
      background: var(--green);
      box-shadow: 0 0 6px rgba(52,211,153,0.6);
    }
 
    .status-text { font-size: 11px; color: var(--text-muted); }
 
    #search-box {
      margin: 12px 14px 0;
      position: relative;
    }
 
    #search-box input {
      width: 100%;
      background: var(--surface2);
      border: 1px solid var(--border);
      border-radius: 7px;
      padding: 8px 10px 8px 32px;
      color: var(--text);
      font-size: 13px;
      outline: none;
      transition: border-color 0.15s, box-shadow 0.15s;
    }
 
    #search-box input:focus {
      border-color: var(--accent2);
      box-shadow: 0 0 0 3px rgba(59,130,246,0.12);
    }
 
    #search-box input::placeholder { color: var(--text-muted); }
 
    #search-box .icon {
      position: absolute; left: 10px; top: 50%;
      transform: translateY(-50%);
      color: var(--text-muted); font-size: 14px; pointer-events: none;
    }
 
    #nav {
      flex: 1; overflow-y: auto;
      padding: 8px 10px 20px;
      scrollbar-width: thin;
      scrollbar-color: var(--border) transparent;
    }
 
    .nav-group-label {
      font-size: 10px; font-weight: 700;
      letter-spacing: 0.08em; text-transform: uppercase;
      color: var(--text-muted); padding: 10px 8px 4px;
    }
 
    .nav-item {
      display: flex; align-items: center; gap: 8px;
      padding: 7px 10px; border-radius: 6px; cursor: pointer;
      font-size: 12.5px; color: var(--text-muted);
      transition: all 0.12s; text-decoration: none;
    }
 
    .nav-item:hover { background: var(--surface2); color: var(--text); }
 
    .nav-item.active {
      background: rgba(59,130,246,0.14);
      color: var(--blue);
      border-left: 2px solid var(--accent);
      padding-left: 8px;
    }
 
    .nav-item .method-badge {
      font-size: 9px; font-weight: 700;
      padding: 2px 5px; border-radius: 4px;
      min-width: 34px; text-align: center; flex-shrink: 0;
    }
 
    .badge-get    { background: rgba(96,165,250,0.15);  color: #60a5fa; }
    .badge-post   { background: rgba(52,211,153,0.15);  color: #34d399; }
    .badge-put    { background: rgba(251,191,36,0.15);  color: #fbbf24; }
    .badge-delete { background: rgba(248,113,113,0.15); color: #f87171; }
    .badge-ws     { background: rgba(34,211,238,0.15);  color: #22d3ee; }
 
    .nav-item .path-text {
      overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
    }
 
    /* ── Main ── */
    #main {
      flex: 1; overflow-y: auto;
      padding: 32px 44px;
      scrollbar-width: thin;
      scrollbar-color: var(--border) transparent;
    }
 
    /* ── Hero ── */
    #hero {
      margin-bottom: 36px; padding-bottom: 28px;
      border-bottom: 1px solid var(--border);
    }
 
    #hero h1 {
      font-size: 28px; font-weight: 800;
      margin: 0 0 6px; letter-spacing: -0.6px;
      background: linear-gradient(135deg, #60a5fa 0%, #22d3ee 100%);
      -webkit-background-clip: text; -webkit-text-fill-color: transparent;
      background-clip: text;
    }
 
    #hero p {
      color: var(--text-muted); font-size: 14px; margin: 0 0 18px;
    }
 
    .info-cards { display: flex; gap: 12px; flex-wrap: wrap; }
 
    .info-card {
      background: var(--surface2);
      border: 1px solid var(--border);
      border-radius: 8px; padding: 12px 16px; min-width: 180px;
    }
 
    .info-card .label {
      font-size: 10px; color: var(--text-muted);
      margin-bottom: 5px; text-transform: uppercase; letter-spacing: 0.06em;
    }
 
    .info-card .value {
      font-size: 13px; font-weight: 600; color: var(--text);
      font-family: 'SF Mono', 'Fira Code', monospace; word-break: break-all;
    }
 
    .auth-guide {
      background: var(--surface2);
      border: 1px solid var(--border);
      border-left: 3px solid var(--accent);
      border-radius: 8px; padding: 14px 18px; margin-top: 16px;
    }
 
    .auth-guide .auth-title {
      font-size: 11px; font-weight: 700; color: var(--blue);
      margin-bottom: 10px; text-transform: uppercase; letter-spacing: 0.06em;
    }
 
    .auth-row {
      display: flex; align-items: center; gap: 10px;
      margin-bottom: 7px; font-size: 13px;
    }
 
    .auth-row:last-child { margin-bottom: 0; }
 
    .auth-row .tag {
      background: var(--surface3); border: 1px solid var(--border);
      border-radius: 4px; padding: 2px 8px;
      font-size: 10px; color: var(--text-muted);
      min-width: 68px; text-align: center;
    }
 
    .auth-row code {
      color: var(--cyan);
      font-family: 'SF Mono', 'Fira Code', monospace; font-size: 12px;
      background: rgba(34,211,238,0.08); padding: 2px 7px; border-radius: 4px;
    }
 
    /* ── Endpoint cards ── */
    .endpoint-card {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 10px; margin-bottom: 12px;
      overflow: visible; transition: border-color 0.15s, box-shadow 0.15s;
    }
 
    .endpoint-card.expanded {
      border-color: var(--accent2);
      box-shadow: 0 0 0 1px rgba(59,130,246,0.15), 0 4px 20px rgba(0,0,0,0.3);
    }
 
    .endpoint-header {
      display: flex; align-items: center; gap: 12px;
      padding: 13px 18px; cursor: pointer; user-select: none;
      border-radius: 10px;
    }
 
    .endpoint-header:hover { background: rgba(255,255,255,0.02); }
    .expanded .endpoint-header { border-radius: 10px 10px 0 0; }
 
    .method-pill {
      font-size: 11px; font-weight: 700;
      padding: 4px 9px; border-radius: 5px;
      min-width: 50px; text-align: center; flex-shrink: 0;
    }
 
    .endpoint-path {
      font-family: 'SF Mono', 'Fira Code', monospace;
      font-size: 13px; color: var(--text); flex: 1;
    }
 
    .endpoint-summary { font-size: 13px; color: var(--text-muted); }
 
    .auth-lock { font-size: 12px; color: var(--yellow); flex-shrink: 0; }
 
    .chevron {
      color: var(--text-muted); font-size: 10px;
      transition: transform 0.2s; flex-shrink: 0;
    }
 
    .expanded .chevron { transform: rotate(90deg); }
 
    .endpoint-body {
      display: none; border-top: 1px solid var(--border);
    }
 
    .expanded .endpoint-body { display: block; }
 
    /* tabs */
    .ep-tabs {
      display: flex; gap: 0;
      border-bottom: 1px solid var(--border);
      padding: 0 18px;
    }
 
    .ep-tab {
      padding: 10px 16px; font-size: 12px; font-weight: 600;
      color: var(--text-muted); cursor: pointer;
      border-bottom: 2px solid transparent;
      margin-bottom: -1px; transition: all 0.15s;
      text-transform: uppercase; letter-spacing: 0.05em;
    }
 
    .ep-tab:hover { color: var(--text); }
    .ep-tab.active { color: var(--blue); border-bottom-color: var(--accent); }
 
    .ep-panel { display: none; padding: 16px 18px 18px; }
    .ep-panel.active { display: block; }
 
    .detail-section { margin-top: 0; }
 
    .detail-section .section-title {
      font-size: 10px; font-weight: 700; color: var(--text-muted);
      text-transform: uppercase; letter-spacing: 0.08em; margin-bottom: 8px;
    }
 
    .param-row {
      display: flex; align-items: flex-start; gap: 10px;
      padding: 8px 12px; background: var(--surface2);
      border-radius: 6px; margin-bottom: 6px; font-size: 13px;
    }
 
    .param-name {
      font-family: 'SF Mono', 'Fira Code', monospace;
      color: var(--cyan); min-width: 130px; flex-shrink: 0;
    }
 
    .param-in {
      font-size: 10px; background: var(--surface3); border: 1px solid var(--border);
      color: var(--text-muted); padding: 2px 6px; border-radius: 3px;
      flex-shrink: 0; margin-top: 1px;
    }
 
    .param-required {
      font-size: 10px; background: rgba(248,113,113,0.12); color: var(--red);
      padding: 2px 6px; border-radius: 3px; flex-shrink: 0; margin-top: 1px;
    }
 
    .param-desc { color: var(--text-muted); flex: 1; }
 
    .response-row {
      display: flex; align-items: center; gap: 10px;
      padding: 8px 12px; background: var(--surface2);
      border-radius: 6px; margin-bottom: 6px; font-size: 13px;
    }
 
    .status-code {
      font-family: 'SF Mono', 'Fira Code', monospace;
      font-weight: 700; min-width: 42px;
    }
 
    .s200 { color: var(--green); }
    .s101 { color: var(--cyan); }
    .s401 { color: var(--red); }
    .s404 { color: var(--orange); }
    .desc-text { color: var(--text-muted); }
 
    /* ── Try it out ── */
    .try-panel { }
 
    .try-section-title {
      font-size: 10px; font-weight: 700; color: var(--text-muted);
      text-transform: uppercase; letter-spacing: 0.08em; margin-bottom: 10px;
    }
 
    .try-field { margin-bottom: 12px; }
 
    .try-field label {
      display: block; font-size: 11px; font-weight: 600;
      color: var(--text-muted); margin-bottom: 5px;
      text-transform: uppercase; letter-spacing: 0.05em;
    }
 
    .try-field label .req { color: var(--red); margin-left: 2px; }
 
    .try-field input,
    .try-field textarea,
    .try-field select {
      width: 100%;
      background: var(--surface2); border: 1px solid var(--border);
      border-radius: 6px; padding: 8px 11px;
      color: var(--text); font-size: 13px;
      font-family: 'SF Mono', 'Fira Code', monospace;
      outline: none; transition: border-color 0.15s, box-shadow 0.15s;
      resize: vertical;
    }
 
    .try-field input:focus,
    .try-field textarea:focus,
    .try-field select:focus {
      border-color: var(--accent);
      box-shadow: 0 0 0 3px rgba(59,130,246,0.1);
    }
 
    .try-field textarea { min-height: 80px; }
 
    .try-field input::placeholder,
    .try-field textarea::placeholder { color: var(--text-muted); }
 
    .try-row { display: flex; gap: 10px; align-items: flex-start; }
 
    .try-row .try-field { flex: 1; }
 
    .try-actions { display: flex; align-items: center; gap: 10px; margin-top: 14px; }
 
    .btn-send {
      background: var(--accent); color: #fff;
      border: none; border-radius: 7px;
      padding: 9px 22px; font-size: 13px; font-weight: 700;
      cursor: pointer; transition: background 0.15s, box-shadow 0.15s;
      letter-spacing: 0.02em;
    }
 
    .btn-send:hover {
      background: #1d4ed8;
      box-shadow: 0 0 16px rgba(59,130,246,0.3);
    }
 
    .btn-send:active { transform: scale(0.98); }
    .btn-send:disabled { background: var(--border2); cursor: not-allowed; opacity: 0.6; }
 
    .btn-clear {
      background: transparent; color: var(--text-muted);
      border: 1px solid var(--border); border-radius: 7px;
      padding: 8px 16px; font-size: 13px;
      cursor: pointer; transition: all 0.15s;
    }
 
    .btn-clear:hover { border-color: var(--border2); color: var(--text); }
 
    .try-response { margin-top: 16px; }
 
    .try-response-header {
      display: flex; align-items: center; gap: 10px;
      margin-bottom: 8px;
    }
 
    .res-status-badge {
      font-size: 11px; font-weight: 700;
      padding: 3px 9px; border-radius: 5px;
      font-family: 'SF Mono', monospace;
    }
 
    .res-badge-ok   { background: rgba(52,211,153,0.15); color: var(--green); }
    .res-badge-err  { background: rgba(248,113,113,0.15); color: var(--red); }
    .res-badge-warn { background: rgba(251,191,36,0.15);  color: var(--yellow); }
 
    .res-time { font-size: 11px; color: var(--text-muted); }
    .res-size { font-size: 11px; color: var(--text-muted); }
 
    .res-copy {
      margin-left: auto; font-size: 11px; color: var(--text-muted);
      cursor: pointer; padding: 3px 8px;
      border: 1px solid var(--border); border-radius: 4px;
      transition: all 0.12s;
    }
 
    .res-copy:hover { color: var(--text); border-color: var(--border2); }
 
    .res-body {
      background: var(--surface2); border: 1px solid var(--border);
      border-radius: 7px; padding: 14px 16px;
      font-family: 'SF Mono', 'Fira Code', monospace;
      font-size: 12px; line-height: 1.6;
      color: var(--text); white-space: pre-wrap;
      overflow-x: auto; max-height: 380px; overflow-y: auto;
      scrollbar-width: thin; scrollbar-color: var(--border) transparent;
    }
 
    .sending-indicator {
      display: none; align-items: center; gap: 8px;
      font-size: 13px; color: var(--text-muted);
    }
 
    .sending-indicator.visible { display: flex; }
 
    /* JSON syntax highlight */
    .json-key    { color: #60a5fa; }
    .json-str    { color: #34d399; }
    .json-num    { color: #fb923c; }
    .json-bool   { color: #f472b6; }
    .json-null   { color: #6b82a0; }
 
    /* ── Loading ── */
    #loading {
      display: flex; align-items: center; justify-content: center;
      height: 200px; color: var(--text-muted); font-size: 14px; gap: 10px;
    }
 
    .spinner {
      width: 18px; height: 18px;
      border: 2px solid var(--border);
      border-top-color: var(--accent);
      border-radius: 50%;
      animation: spin 0.7s linear infinite;
    }
 
    @keyframes spin { to { transform: rotate(360deg); } }
 
    .empty { color: var(--text-muted); font-size: 13px; padding: 6px 0; }
 
    ::-webkit-scrollbar { width: 5px; height: 5px; }
    ::-webkit-scrollbar-track { background: transparent; }
    ::-webkit-scrollbar-thumb { background: var(--border); border-radius: 3px; }
  </style>
</head>
<body>
 
<div id="sidebar">
  <div id="sidebar-header">
    <div class="logo">
      <img src="/icon" alt="Kostori" onerror="this.style.display='none'">
      <span>Kostori API</span>
    </div>
    <div class="version-row">
      <span class="version" id="api-version">v—</span>
      <span class="status-dot"></span>
      <span class="status-text">Online</span>
    </div>
  </div>
  <div id="search-box">
    <span class="icon">⌕</span>
    <input type="text" placeholder="Search endpoints..." id="search-input">
  </div>
  <div id="nav"></div>
</div>
 
<div id="main">
  <div id="hero">
    <h1>Kostori API Docs</h1>
    <p id="api-desc">Local service API — browse endpoints and test them directly from your browser.</p>
    <div class="info-cards" id="info-cards"></div>
    <div class="auth-guide">
      <div class="auth-title">🔑 Authentication</div>
      <div class="auth-row">
        <span class="tag">HTTP</span>
        <code>Authorization: Bearer &lt;key&gt;</code>
        <span style="color:var(--text-muted);font-size:12px">— user or admin key</span>
      </div>
      <div class="auth-row">
        <span class="tag">WebSocket</span>
        <code>?token=&lt;key&gt;</code>
        <span style="color:var(--text-muted);font-size:12px">— query param</span>
      </div>
    </div>
  </div>
 
  <div id="loading"><div class="spinner"></div> Loading endpoints...</div>
  <div id="endpoints" style="display:none"></div>
</div>
 
<script>
// ── JSON syntax highlighter ──────────────────────────────────────────────────
function highlight(json) {
  return json
    .replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')
    .replace(/("(\\u[a-zA-Z0-9]{4}|\\[^u]|[^\\"])*"(\s*:)?|\b(true|false|null)\b|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?)/g, m => {
      if (/^"/.test(m)) {
        if (/:$/.test(m)) return `<span class="json-key">${m}</span>`;
        return `<span class="json-str">${m}</span>`;
      }
      if (/true|false/.test(m)) return `<span class="json-bool">${m}</span>`;
      if (/null/.test(m))       return `<span class="json-null">${m}</span>`;
      return `<span class="json-num">${m}</span>`;
    });
}
 
function formatSize(bytes) {
  if (bytes < 1024) return bytes + ' B';
  return (bytes / 1024).toFixed(1) + ' KB';
}
 
(async () => {
  // ── Fetch spec ───────────────────────────────────────────────────────────
  let spec;
  try {
    const res = await fetch(window.location.origin + '/openapi.json');
    spec = await res.json();
  } catch (e) {
    document.getElementById('loading').innerHTML = '❌ Failed to load API spec';
    return;
  }
 
  const info   = spec.info   ?? {};
  const server = (spec.servers ?? [])[0]?.url ?? window.location.origin;
 
  document.getElementById('api-version').textContent = 'v' + (info.version ?? '?');
 
  document.getElementById('info-cards').innerHTML = `
    <div class="info-card">
      <div class="label">Server</div>
      <div class="value">${server}</div>
    </div>
    <div class="info-card">
      <div class="label">Version</div>
      <div class="value">${info.version ?? '—'}</div>
    </div>
    <div class="info-card">
      <div class="label">Spec</div>
      <div class="value"><a href="/openapi.json" style="color:var(--blue);text-decoration:none">openapi.json ↗</a></div>
    </div>
  `;
 
  // ── Parse endpoints ──────────────────────────────────────────────────────
  const endpoints = [];
  for (const [path, methods] of Object.entries(spec.paths ?? {})) {
    for (const [method, op] of Object.entries(methods)) {
      endpoints.push({ path, method: method.toUpperCase(), op });
    }
  }
 
  // ── Sidebar nav ──────────────────────────────────────────────────────────
  const nav = document.getElementById('nav');
 
  function renderNav(list) {
    nav.innerHTML = '';
    if (!list.length) {
      nav.innerHTML = '<div class="empty" style="padding:10px 8px">No results</div>';
      return;
    }
    const lbl = document.createElement('div');
    lbl.className = 'nav-group-label';
    lbl.textContent = `Endpoints (${list.length})`;
    nav.appendChild(lbl);
 
    list.forEach((ep, idx) => {
      const globalIdx = endpoints.indexOf(ep);
      const item = document.createElement('a');
      item.className = 'nav-item';
      item.href = '#ep-' + globalIdx;
      item.dataset.index = globalIdx;
      const bc = ep.method === 'GET' ? 'badge-get'
        : ep.method === 'POST'   ? 'badge-post'
        : ep.method === 'PUT'    ? 'badge-put'
        : ep.method === 'DELETE' ? 'badge-delete' : 'badge-ws';
      item.innerHTML = `<span class="method-badge ${bc}">${ep.method}</span><span class="path-text">${ep.path}</span>`;
      item.addEventListener('click', () => {
        document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
        item.classList.add('active');
      });
      nav.appendChild(item);
    });
  }
 
  renderNav(endpoints);
 
  // ── Method colors ────────────────────────────────────────────────────────
  function methodColor(m) {
    return m === 'GET' ? '#60a5fa' : m === 'POST' ? '#34d399'
      : m === 'PUT' ? '#fbbf24' : m === 'DELETE' ? '#f87171' : '#22d3ee';
  }
 
  function methodBg(m) {
    return m === 'GET' ? 'rgba(96,165,250,0.12)' : m === 'POST' ? 'rgba(52,211,153,0.12)'
      : m === 'PUT' ? 'rgba(251,191,36,0.12)' : m === 'DELETE' ? 'rgba(248,113,113,0.12)'
      : 'rgba(34,211,238,0.12)';
  }
 
  // ── Render endpoint cards ────────────────────────────────────────────────
  const container = document.getElementById('endpoints');
  document.getElementById('loading').style.display = 'none';
  container.style.display = 'block';
 
  endpoints.forEach((ep, i) => {
    const op       = ep.op;
    const params   = op.parameters ?? [];
    const responses= op.responses  ?? {};
    const requiresAuth = (op.security ?? []).length > 0;
    const isWs     = ep.method === 'GET' && responses['101'];
    const httpMethod = isWs ? 'WS' : ep.method;
 
    // ── Params tab HTML ──
    const paramsHtml = params.length > 0
      ? params.map(p => `
          <div class="param-row">
            <span class="param-name">${p.name ?? p.Name ?? ''}</span>
            <span class="param-in">${p.in ?? p.type ?? ''}</span>
            ${p.required ? '<span class="param-required">required</span>' : ''}
            <span class="param-desc">${p.description ?? ''}</span>
          </div>`).join('')
      : '<div class="empty">No parameters</div>';
 
    const responsesHtml = Object.entries(responses).map(([code, r]) => {
      const cls = code==='200'?'s200':code==='101'?'s101':code==='401'?'s401':'s404';
      return `<div class="response-row">
        <span class="status-code ${cls}">${code}</span>
        <span class="desc-text">${r.description ?? ''}</span>
      </div>`;
    }).join('');
 
    // ── Try-it-out inputs ──
    // Auth header input
    const authInput = requiresAuth
      ? `<div class="try-field">
           <label>Authorization <span class="req">*</span></label>
           <input type="text" class="try-auth" placeholder="Bearer your-api-key">
         </div>`
      : '';
 
    // Path + query params
    const pathParams  = params.filter(p => (p.in ?? p.type) === 'path');
    const queryParams = params.filter(p => (p.in ?? p.type) === 'query');
    const headerParams= params.filter(p => (p.in ?? p.type) === 'header');
    const bodyParams  = params.filter(p => (p.in ?? p.type) === 'body');
 
    let tryPathHtml = '';
    if (pathParams.length) {
      tryPathHtml = '<div class="try-section-title" style="margin-bottom:8px">Path Parameters</div>'
        + pathParams.map(p => `<div class="try-field">
            <label>${p.name}${p.required ? '<span class="req">*</span>' : ''}</label>
            <input type="text" class="try-param-path" data-name="${p.name}" placeholder="${p.description ?? p.name}">
          </div>`).join('');
    }
 
    let tryQueryHtml = '';
    if (queryParams.length) {
      tryQueryHtml = '<div class="try-section-title" style="margin-bottom:8px;margin-top:12px">Query Parameters</div>'
        + queryParams.map(p => `<div class="try-field">
            <label>${p.name}${p.required ? '<span class="req">*</span>' : ''}</label>
            <input type="text" class="try-param-query" data-name="${p.name}" placeholder="${p.description ?? p.name}">
          </div>`).join('');
    }
 
    let tryBodyHtml = '';
    if (['POST','PUT','PATCH'].includes(ep.method)) {
      tryBodyHtml = `<div class="try-field" style="margin-top:12px">
        <label>Request Body <span style="color:var(--text-muted);font-weight:400;text-transform:none;font-size:11px">(JSON)</span></label>
        <textarea class="try-body" placeholder='{\n  "key": "value"\n}'></textarea>
      </div>`;
    }
 
    const card = document.createElement('div');
    card.className = 'endpoint-card';
    card.id = 'ep-' + i;
 
    card.innerHTML = `
      <div class="endpoint-header" onclick="toggleCard(this)">
        <span class="method-pill" style="background:${methodBg(httpMethod)};color:${methodColor(httpMethod)}">${httpMethod}</span>
        <span class="endpoint-path">${ep.path}</span>
        <span class="endpoint-summary">${op.summary ?? ''}</span>
        ${requiresAuth ? '<span class="auth-lock">🔒</span>' : ''}
        <span class="chevron">▶</span>
      </div>
      <div class="endpoint-body">
        ${op.description ? `<div style="font-size:13px;color:var(--text-muted);padding:12px 18px 0">
          ${op.description}</div>` : ''}
        <div class="ep-tabs">
          <div class="ep-tab active" onclick="switchTab(this,'docs')">Docs</div>
          ${!isWs ? `<div class="ep-tab" onclick="switchTab(this,'try')">Try it out ▶</div>` : ''}
        </div>
        <div class="ep-panel active" data-panel="docs">
          <div class="detail-section">
            <div class="section-title">Parameters</div>
            ${paramsHtml}
          </div>
          <div class="detail-section" style="margin-top:14px">
            <div class="section-title">Responses</div>
            ${responsesHtml}
          </div>
        </div>
        ${!isWs ? `
        <div class="ep-panel try-panel" data-panel="try">
          ${authInput}
          ${tryPathHtml}
          ${tryQueryHtml}
          ${tryBodyHtml}
          <div class="try-actions">
            <button class="btn-send" onclick="sendRequest(this)" data-method="${ep.method}" data-path="${ep.path}">
              Send Request
            </button>
            <button class="btn-clear" onclick="clearTry(this)">Clear</button>
            <div class="sending-indicator">
              <div class="spinner"></div> Sending...
            </div>
          </div>
          <div class="try-response" style="display:none"></div>
        </div>` : ''}
      </div>
    `;
    container.appendChild(card);
  });
 
  // ── Search ───────────────────────────────────────────────────────────────
  document.getElementById('search-input').addEventListener('input', e => {
    const q = e.target.value.toLowerCase();
    const filtered = endpoints.filter(ep =>
      ep.path.toLowerCase().includes(q) ||
      ep.method.toLowerCase().includes(q) ||
      (ep.op.summary ?? '').toLowerCase().includes(q)
    );
    renderNav(filtered);
    endpoints.forEach((ep, i) => {
      const el = document.getElementById('ep-' + i);
      if (!el) return;
      const matches = !q || ep.path.toLowerCase().includes(q) ||
        ep.method.toLowerCase().includes(q) ||
        (ep.op.summary ?? '').toLowerCase().includes(q);
      el.style.display = matches ? '' : 'none';
    });
  });
 
  // ── Scroll spy ───────────────────────────────────────────────────────────
  const obs = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        const idx = entry.target.id.replace('ep-','');
        document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
        document.querySelector(`.nav-item[data-index="${idx}"]`)?.classList.add('active');
      }
    });
  }, { rootMargin: '-30% 0px -60% 0px' });
 
  document.querySelectorAll('.endpoint-card').forEach(el => obs.observe(el));
 
})();
 
// ── Card toggle ──────────────────────────────────────────────────────────────
function toggleCard(header) {
  header.closest('.endpoint-card').classList.toggle('expanded');
}
 
// ── Tab switch ───────────────────────────────────────────────────────────────
function switchTab(tab, name) {
  const body = tab.closest('.endpoint-body');
  body.querySelectorAll('.ep-tab').forEach(t => t.classList.remove('active'));
  body.querySelectorAll('.ep-panel').forEach(p => p.classList.remove('active'));
  tab.classList.add('active');
  body.querySelector(`[data-panel="${name}"]`)?.classList.add('active');
}
 
// ── Clear Try ────────────────────────────────────────────────────────────────
function clearTry(btn) {
  const panel = btn.closest('.try-panel');
  panel.querySelectorAll('input, textarea').forEach(el => el.value = '');
  const resDiv = panel.querySelector('.try-response');
  if (resDiv) { resDiv.style.display = 'none'; resDiv.innerHTML = ''; }
}
 
// ── Send request ─────────────────────────────────────────────────────────────
async function sendRequest(btn) {
  const panel  = btn.closest('.try-panel');
  const method = btn.dataset.method;
  let   path   = btn.dataset.path;
 
  // Replace path params
  panel.querySelectorAll('.try-param-path').forEach(input => {
    if (input.value) path = path.replace(`{${input.dataset.name}}`, input.value);
  });
 
  // Build query string
  const qp = new URLSearchParams();
  panel.querySelectorAll('.try-param-query').forEach(input => {
    if (input.value) qp.append(input.dataset.name, input.value);
  });
 
  const qs = qp.toString();
  const url = window.location.origin + path + (qs ? '?' + qs : '');
 
  // Build headers
  const headers = { 'Content-Type': 'application/json' };
  const authInput = panel.querySelector('.try-auth');
  if (authInput?.value?.trim()) {
    const v = authInput.value.trim();
    headers['Authorization'] = v.startsWith('Bearer ') ? v : 'Bearer ' + v;
  }
 
  // Build body
  let body = undefined;
  const bodyInput = panel.querySelector('.try-body');
  if (bodyInput?.value?.trim()) {
    try { JSON.parse(bodyInput.value); body = bodyInput.value; }
    catch { showResponse(panel, null, null, 'Invalid JSON body'); return; }
  }
 
  // Show spinner
  const indicator = panel.querySelector('.sending-indicator');
  indicator.classList.add('visible');
  btn.disabled = true;
 
  const t0 = performance.now();
  try {
    const res = await fetch(url, { method, headers, body });
    const elapsed = Math.round(performance.now() - t0);
    const text = await res.text();
    showResponse(panel, res.status, text, null, elapsed);
  } catch (e) {
    showResponse(panel, null, null, e.message);
  } finally {
    indicator.classList.remove('visible');
    btn.disabled = false;
  }
}
 
function showResponse(panel, status, text, errMsg, elapsed) {
  const resDiv = panel.querySelector('.try-response');
  resDiv.style.display = 'block';
 
  let badgeClass = 'res-badge-warn';
  let badgeText  = '—';
  if (status) {
    badgeText  = String(status);
    badgeClass = status >= 200 && status < 300 ? 'res-badge-ok'
      : status >= 400 ? 'res-badge-err' : 'res-badge-warn';
  }
 
  let bodyHtml = '';
  if (errMsg) {
    bodyHtml = `<div class="res-body" style="color:var(--red)">${errMsg}</div>`;
  } else {
    let displayText = text ?? '';
    try {
      displayText = JSON.stringify(JSON.parse(text), null, 2);
      bodyHtml = `<div class="res-body">${highlight(displayText)}</div>`;
    } catch {
      bodyHtml = `<div class="res-body">${displayText.replace(/</g,'&lt;')}</div>`;
    }
  }
 
  const size = text ? formatSize(new TextEncoder().encode(text).length) : '—';
 
  resDiv.innerHTML = `
    <div class="try-response-header">
      <span class="res-status-badge ${badgeClass}">${badgeText}</span>
      ${elapsed != null ? `<span class="res-time">${elapsed}ms</span>` : ''}
      ${text ? `<span class="res-size">${size}</span>` : ''}
      ${text ? `<span class="res-copy" onclick="navigator.clipboard.writeText(${JSON.stringify(text).replace(/'/g,"&#39;")})">Copy</span>` : ''}
    </div>
    ${bodyHtml}
  `;
}
 
function formatSize(bytes) {
  return bytes < 1024 ? bytes + ' B' : (bytes/1024).toFixed(1) + ' KB';
}
</script>
</body>
</html>
''';
}
