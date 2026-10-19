# Headless 部署网络配置

Headless 服务调用 Bangumi 的请求复用 Kostori 的网络层。无头进程无法读取桌面系统代理时，可在启动进程前配置代理环境变量。

## 代理环境变量

推荐使用 KOSTORI_PROXY，它优先于标准代理环境变量：

~~~dotenv
KOSTORI_PROXY=http://proxy-host:7890
~~~

也可以使用 HTTPS_PROXY、HTTP_PROXY 或 ALL_PROXY。代理地址可以带 http:// scheme；代理主机名必须能从 Kostori Headless 所在的容器或服务器访问。

如果不方便设置环境变量，也可以在 Headless 启动参数中传入 `--proxy http://proxy-host:7890`。该参数只对当前进程生效，不会写回 GUI 配置，例如：

```text
kostori --headless --service headless --proxy http://proxy-host:7890
```

Docker Compose 示例：

~~~yaml
services:
  kostori:
    environment:
      KOSTORI_PROXY: http://proxy:7890
~~~

如果代理运行在宿主机上，容器内的 127.0.0.1 指向容器自身，应改用容器可访问的宿主机地址或代理服务名。

KOSTORI_PROXY 是部署级显式配置，会优先于应用内保存的代理设置；这样不会被 GUI 设备上保存的“直连”选项覆盖。未设置 KOSTORI_PROXY 时，应用网络设置为“跟随系统”即可读取 HTTPS_PROXY 等标准变量。桌面系统代理通道不可用时，Headless 会自动回退到环境变量。

打开 `/docs` 后，带鉴权的接口会在“试用”页显示 `token` 输入框。`/api/logs` 属于管理接口，必须填启动时的管理令牌（`--admin-key`），用户令牌不能访问。

## Koishi 插件连接

Koishi 连接 Kostori Headless 时，baseUrl 必须是 Koishi 进程可访问的 Headless 地址。两个进程不在同一个容器时，不要使用 127.0.0.1 指向另一个容器。

番剧搜索和条目分享卡片可公开调用；番剧时间表截图需要配置 Kostori 用户 API Key。Koishi 到 Headless 的请求超时建议至少设为 30 秒，因为时间表和分享卡片会触发 Bangumi 网络请求及图片渲染。
