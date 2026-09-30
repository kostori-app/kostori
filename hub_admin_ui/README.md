# Hub 管理后台（Web UI）

Kostori Hub Web 管理后台的源码。**构建产物已提交到 `assets/hub_admin/`**，随应用一起打包，
不联网、不做按需下载。

## 为什么打包而不是外置

- 省下的体积有限（一个 Vue 空壳就有 ~50 kB gzip），却要引入「远程代码 → 持有管理令牌的面板」
  这条 RCE 链路；
- 外置后断网 / 下载失败时管理页直接不可用，而它本来只需要在局域网里能打开。

## 目录

```
hub_admin_ui/          源码（本目录）
  index.html           Vite 入口
  vite.config.js       构建配置；产物输出到 ../assets/hub_admin
  src/
    App.vue            外壳：侧边导航 + 视图切换 + 轮询
    api.js             后端接口封装（令牌存 localStorage）
    toast.js           轻量 toast 与 run() 包装
    styles.css         设计令牌与基础样式
    components/        Card / AppButton / AppModal / FormField / StatTile /
                       StatusBadge / MiniChart / ToastHost
    views/             10 个视图，与 /api/admin/* 一一对应
assets/hub_admin/      构建产物（已提交）
  index.html  app.js  app.css
```

## 构建

```bash
cd hub_admin_ui
npm install
npm run build      # 产物写入 ../assets/hub_admin/
```

**改完源码必须重新构建并提交产物**，否则应用里跑的还是旧页面。

## 本地开发

```bash
cd hub_admin_ui
npm run dev        # http://localhost:5273
```

`vite.config.js` 里配了代理：开发服务器的 `/api` 会转发到 `http://127.0.0.1:9200`，
所以需要应用里的 Hub 管理服务正在运行（默认端口 9200，可在设置页改）。

## 与后端的约定

- 页面通过 `GET/POST /api/admin/*` 与 Hub 通信，全部走同源相对路径，
  **不硬编码 9100/9200**，端口在设置页改掉后依然有效。
- **不含 LAN 远程控制**：那是独立的 `LanControlService`（自己的 `HttpServer` 单例），
  播放/导航回调与 PIN 都由应用设置页负责，不在这里做第二个入口。
- 静态资源由 `HubWebAdminService` 按固定文件名提供（`/app.js`、`/app.css`），
  文件名写在路由表里而非取自请求，因此没有路径穿越面。
  Vite 侧因此关闭了 hash 文件名（见 `vite.config.js` 的 `rollupOptions.output`）。
- 新增页面资源时：先在 `pubspec.yaml` 的 `flutter.assets` 里显式声明
  （不能依赖 `assets/` 的递归收集），再在 `registerRoutes()` 里加一条显式路由。

## 加一个新视图

1. `src/views/XxxView.vue`，从 `../api.js` 取数据，用 `run()` 包住请求以获得统一的错误提示；
2. 在 `src/App.vue` 的 `NAV` 里加一项，并在 `VIEWS` 里注册组件；
3. `npm run build`，提交 `assets/hub_admin/` 的变化。
