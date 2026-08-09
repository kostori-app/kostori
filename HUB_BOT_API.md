# Kostori Hub 机器人接入指南

Kostori 的 Hub（房间/聊天/一起看服务器）为机器人/第三方服务提供了三种接入通道：

| 通道                | 方向       | 用途         | 特点            |
|-------------------|----------|------------|---------------|
| **入站 Webhook**    | 外部 → Hub | 机器人发消息进房间  | HTTP POST，无状态 |
| **出站 Webhook**    | Hub → 外部 | 机器人接收房间事件  | HTTP POST，可验签 |
| **WebSocket 客户端** | 双向       | 机器人作为完整客户端 | 实时双向，支持全部协议   |

> 注意：机器人接口**不止 webhook**。WebSocket 是功能最完整的通道——机器人以普通客户端身份连入
> Hub，可以收发消息、进房间、收系统事件，甚至参与「一起看」。Webhook 更适合轻量、无状态、需要被外部频繁触发的场景。

---

## 1. 入站 Webhook（机器人 → Hub）

机器人通过 HTTP POST 向指定房间推送消息，以机器人身份显示。

```
POST http://<hub-addr>:<hub-port>/hub/webhook/<token>
Content-Type: application/json

{ "text": "要发送的消息" }
```

- **token**：在「设置 → Hub 管理 → Webhook → 创建 Webhook」时生成，绑定到某个房间。
- **text / message**：消息内容，支持 `@提及`、表情、换行等富文本（服务端自动解析 segments）。
- **发送者**：显示为创建时填写的名称，`isBot: true`。

**响应**

```json
{
  "sent": true,
  "room": "房间名"
}
```

**错误**

| 状态码 | body                                   |
|-----|----------------------------------------|
| 403 | `{ "error": "Invalid webhook token" }` |
| 400 | `{ "error": "text/message required" }` |
| 404 | `{ "error": "Room not found" }`        |

**示例（curl）**

```bash
curl -X POST "http://192.168.1.5:9100/hub/webhook/1a2b3c4d..." \
  -H "Content-Type: application/json" \
  -d '{"text": "打卡成功 ✅"}'
```

> 跨设备调用时，把 `0.0.0.0` 换成 Hub 所在机器的实际 IP。

---

## 2. 出站 Webhook（Hub → 机器人）

在「Hub 管理 → Webhook → 出站」中配置机器人的接收 URL。房间事件发生时 Hub 会 POST 到这个 URL。

**推送给你的 body**

```json
{
  "event": "message",
  "roomId": "6ba7b810-...",
  "roomName": "一起看房间",
  "senderId": "device-uuid",
  "senderName": "用户A",
  "text": "消息正文",
  "sentAt": "2026-08-06T12:00:00.000Z"
}
```

**事件类型**

- `message`（消息事件，默认开启）：房间内的每条新消息（含同步进度消息 `KOSTORI_SYNC:` 前缀，可按需过滤）。
- 系统事件（可选开启）：进房/退房/踢人/置顶等，事件名见下文 WS 协议。

**验签**：若配置了 secret，请求头携带：

```
X-Hub-Signature: sha256=<hex(HMAC-SHA256(body, secret))>
```

接收方用同一 secret 计算 HMAC 比对即可确认来源可信。

**示例（Node 接收端）**

```js
const crypto = require('crypto');
require('http').createServer((req, res) => {
    let body = '';
    req.on('data', c => body += c);
    req.on('end', () => {
        const sig = req.headers['x-hub-signature'];
        const expected = 'sha256=' + crypto.createHmac('sha256', process.env.SECRET).update(body).digest('hex');
        if (sig !== expected) {
            res.writeHead(403);
            res.end();
            return;
        }
        const evt = JSON.parse(body);
        console.log(`[${evt.roomName}] ${evt.senderName}: ${evt.text}`);
        res.end('ok');
    });
}).listen(8080);
```

---

## 3. WebSocket 双向通道（推荐完整机器人）

机器人以普通客户端身份连接 Hub 的 WS 端点，可双向实时通信，支持全部协议能力。

```
ws://<hub-addr>:<hub-port>/hub
```

### 3.1 连接与鉴权

连接后第一条消息必须是鉴权（JSON 文本帧）：

```json
{
  "type": "auth",
  "token": "hub-api-key",
  "displayName": "机器人",
  "userId": "my-bot-id",
  "biography": "",
  "avatarUrl": ""
}
```

- **token**：Hub 的用户层 API Key（在 Hub 服务设置中配置/生成）。
- **userId**：设备唯一 ID，建议自行生成固定值（服务端用它标识连接）。
- 鉴权失败服务端会关闭连接（`Unauthorized`）。

成功后服务端返回 `welcome`：

```json
{
  "type": "welcome",
  "yourId": "my-bot-id",
  "clients": [
    ...
  ],
  // 在线客户端
  "room": {
    ...
  },
  // 大厅房间
  "rooms": [
    ...
  ],
  // 全部房间
  "history": [
    ...
  ],
  // 大厅历史
  "heartbeatInterval": 30000,
  "uploadEnabled": true
}
```

### 3.2 心跳保活

- 服务端要求客户端按 `heartbeatInterval` 周期发送 `{"messageType":"ping"}`。
- 服务端回复 `{"type":"pong"}`。超过约 10s 无响应可能被判定超时断开。

### 3.3 客户端 → 服务端（消息类型）

所有消息为 JSON 文本帧，字段 `messageType`：

| messageType                   | 说明             | 关键字段                                                                                     |
|-------------------------------|----------------|------------------------------------------------------------------------------------------|
| `broadcast`                   | 向当前房间广播消息      | `segments: [{type:"text",data:{text:"hi"}}]`                                             |
| `unicast`                     | 私聊单播           | `targetUserId`, `segments`                                                               |
| `join_room`                   | 加入房间           | `roomId`, `password?`                                                                    |
| `leave_room`                  | 离开房间           | -                                                                                        |
| `create_room`                 | 创建房间           | `roomName`, `password?`, `announcement?`, `maxParticipants?`, `roomType?`, `animeId?`... |
| `delete_room`                 | 删除房间（房主）       | `roomId`                                                                                 |
| `recall`                      | 撤回消息           | `messageId`                                                                              |
| `reaction`                    | 表情回应           | `messageId`, `emojiId`                                                                   |
| `pin`                         | 置顶             | `messageId`                                                                              |
| `search`                      | 搜索房间历史         | `keyword`                                                                                |
| `ping`                        | 心跳             | -                                                                                        |
| `status`                      | 更新在线状态         | `onlineStatus: online/away/busy/offline`                                                 |
| `profile`                     | 更新资料           | `displayName`, `avatarUrl`, `biography`                                                  |
| `mute` / `unmute`             | 禁言（管理员）        | `targetUserId`, `seconds`                                                                |
| `kick`                        | 踢人（管理员）        | `targetUserId`                                                                           |
| `room_ban` / `room_unban`     | 房间拉黑           | `targetUserId`                                                                           |
| `server_ban` / `server_unban` | 全局拉黑（全局管理员）    | `targetUserId`                                                                           |
| `set_room_admin`              | 设置房间管理员        | `targetUserId`, `value`                                                                  |
| `set_announcement`            | 设置公告           | `announcement`                                                                           |
| `set_welcome_message`         | 设置欢迎语          | `welcomeMessage`                                                                         |
| `set_room_password`           | 设置房间密码         | `password`                                                                               |
| `poke`                        | 戳一下            | `targetUserId`                                                                           |
| `invite_to_room`              | 邀请进房           | `targetUserId`                                                                           |
| `set_peer_candidates`         | 一起看 P2P 上报候选地址 | `candidates: ["ws://ip:port/peersync"]`                                                  |
| `direct_sync_status`          | 一起看直连状态        | `enabled: bool`                                                                          |

**广播消息示例**

```json
{
  "messageType": "broadcast",
  "segments": [
    {
      "type": "text",
      "data": {
        "text": "大家好"
      }
    }
  ]
}
```

### 3.4 服务端 → 客户端（下行类型）

下行消息的根字段是 `type`：

| type          | 说明                           |
|---------------|------------------------------|
| `welcome`     | 鉴权成功                         |
| `message`     | 广播/单播消息（含 `HubMessage` 全部字段） |
| `system`      | 系统事件（`event` 字段标识）           |
| `pong`        | 心跳响应                         |
| `error`       | 错误（`message` 字段）             |
| `room_joined` | 加入房间成功（含 `room` + `history`） |
| `kicked`      | 被踢下线（`reason`）               |

**收到的消息结构**

```json
{
  "type": "message",
  "messageId": "xxx",
  "messageType": "chat",
  "sender": {
    "userId": "...",
    "displayName": "..."
  },
  "targetRoomIds": [
    "..."
  ],
  "segments": [
    {
      "type": "text",
      "data": {
        "text": "hi"
      }
    }
  ],
  "sentAt": "..."
}
```

**系统事件示例**

```json
{
  "type": "system",
  "event": "client_joined_room",
  "client": {
    ...
  },
  "roomId": "..."
}
```

### 3.5 segments 富文本

`segments` 是消息内容数组，`type` + `data` 结构：

| type      | data 字段                                                         |
|-----------|-----------------------------------------------------------------|
| `text`    | `{ "text": "..." }`                                             |
| `image`   | `{ "url": "...", "width": null, "height": null, "alt": "..." }` |
| `mention` | `{ "userId": "...", "displayName": "..." }`                     |
| `quote`   | `{ "messageId": "...", "fromName": "...", "preview": "..." }`   |

### 3.6 可选的传输加密

协议支持 AES 加密 segments（服务端启用时下行消息会带 `"encrypted": true`，此时 `segments` 为 base64 密文）。密钥由 token 派生：
`key = sha256(token)`、`iv = md5(token)`，AES-CBC + PKCS7。适配器建议实现该解密以兼容加密服务端。

---

## 4. 适配器架构建议

### 4.1 Webhook 版（轻量，无状态）

```
外部系统 ──HTTP POST──► Hub(入站 webhook) ──► 房间
Hub(出站 webhook) ──HTTP POST──► 机器人服务(公网 URL)
```

- 优点：实现简单、跨防火墙、适合 serverless。
- 缺点：双向都是单向 HTTP，无状态；机器人无法「主动持续监听」、无法进房间互动。

### 4.2 WebSocket 版（完整机器人，推荐）

```
机器人服务 ──WS 长连──► Hub /hub
   │  ├─ auth → welcome
   │  ├─ broadcast/unicast → 收消息
   │  ├─ join_room → 进房互动
   │  ├─ system 事件 → 感知进退房/踢人等
   │  └─ 一起看：上报候选 / 直连同步
```

- 优点：实时双向，可参与一起看，可做交互式机器人。
- 缺点：需保持长连接、处理重连与心跳、实现加密解密。

### 4.3 混合版

- **WS 收 + 入站 webhook 发**：机器人用 WS 监听，用 webhook 发消息（两者不冲突）。
- **WS 收 + WS 回**：纯 WS，功能最全。

---

## 5. 一起看（P2P）与机器人

一起看房间的进度同步默认「房主 → 服务器 → 房间广播」。机器人可通过 `set_peer_candidates` / `direct_sync_status` 加入 P2P
直连优化：

- **房主**启动直连 WS（`/peersync`），上报候选地址，同步消息直接推给直连成员，服务器对已直连成员跳过转发。
- **成员**尝试直连房主，失败自动回退服务器广播。

机器人若只是观察/转发，可忽略 P2P，直接使用服务器广播即可。

---

## 6. 安全说明

- 入站 webhook 依赖 URL 中的 token 鉴权，token 泄露即等于可发消息，请妥善保管。
- 出站 webhook 建议配置 secret 并校验 `X-Hub-Signature`。
- WS 鉴权使用 Hub 用户层 API Key；全局管理员需 admin Key。
- 单条消息上限 64KB；每秒最多 20 条（超限静默丢弃）。
- 建议通过 HTTPS（Hub 支持绑定证书）加密传输。

## 相关代码

- Webhook 存储与验签：`lib/foundation/hub_services/webhook/hub_webhook.dart`
- 入站 Webhook 路由：`lib/foundation/hub_services/hub_service/hub_service_routes.dart`
- WS 鉴权与协议入口：`lib/foundation/hub_services/hub_service/hub_service_handler.dart`
- 消息模型 / segments：`lib/foundation/hub_services/hub_models.dart`
- 一起看 P2P：`lib/foundation/hub_services/peer_sync/peer_sync.dart`
- 官方客户端实现（协议参考）：`lib/foundation/hub_services/hub_client/`
