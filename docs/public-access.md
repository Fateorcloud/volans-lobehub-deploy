# 公开部署：Cloudflare Tunnel + 域名

默认 `deploy.sh fresh` 只在 `127.0.0.1` 上跑 LobeHub（本地测试阶段）。要把它公开给一组
用户访问，用 **Cloudflare Tunnel** 最省事：不开公网端口、TLS 在 Cloudflare 边缘完成，
边缘还顺带做 HTTP/2 + 压缩 + 静态资源缓存（首屏明显更快）。

前提：域名已托管在 Cloudflare。下面以 `example.com` 为例，App 用 `chat.example.com`、
文件存储用 `s3.example.com`。

## 为什么需要两个主机名

LobeHub 不自己存文件——它把文件卸载到 S3 兼容存储（本套件用 RustFS）。上传时浏览器拿到
一个临时签名链接，**直接把文件传给存储服务**，避免大文件拖慢聊天服务。所以存储服务
（RustFS，`127.0.0.1:9000`）必须能被用户浏览器访问到，需要它自己的主机名 `s3.example.com`。
它只是同机同隧道上多一条二级域名，对用户透明。

## 步骤

### 1. 在 Cloudflare Zero Trust 建隧道

`Networks → Tunnels → Create a tunnel`（Cloudflared 类型）→ 拿到 **Tunnel Token**。
在该隧道的 **Public Hostnames** 里加两条（Cloudflare 会自动建 DNS 记录 + 边缘证书）：

| Hostname | Service |
|---|---|
| `chat.example.com` | `http://127.0.0.1:3210` |
| `s3.example.com` | `http://127.0.0.1:9000` |

### 2. 配置 `.env`

```env
COMPOSE_PROFILES=tunnel
CF_TUNNEL_TOKEN=<你的隧道 token>

APP_URL=https://chat.example.com
INTERNAL_APP_URL=http://127.0.0.1:3210

S3_ENDPOINT=https://s3.example.com
S3_PUBLIC_DOMAIN=https://s3.example.com
S3_ENABLE_PATH_STYLE=1
S3_SET_ACL=0
RUSTFS_CORS_ALLOWED_ORIGINS=https://chat.example.com

# 准入白名单：只有这些邮箱/域名能注册登录（留空=任何人可注册）
AUTH_ALLOWED_EMAILS=you@example.com,teammate@example.com

# 服务端共享 key 池（所有登录用户可用；用户也可在设置里加自己的私有 key）
API_KEY_SELECT_MODE=turn
DEEPSEEK_API_KEY=sk-xxx           # 多把可逗号分隔：sk-aaa,sk-bbb
```

### 3. 启动

```bash
cd /opt/lobehub
docker compose --profile tunnel up -d          # 启动 cloudflared
docker compose up -d --force-recreate lobe rustfs   # 应用新 .env
```

`COMPOSE_PROFILES=tunnel` 在 `.env` 里设好后，后续 `deploy.sh repair` 会自动带上隧道。

## 验证

```bash
docker logs --tail 30 cloudflare-tunnel        # 应见 "Registered tunnel connection"
curl -I https://chat.example.com               # 200/302，且 content-encoding: br/gzip
```

浏览器打开 `https://chat.example.com`：白名单内邮箱可注册登录；未填私有 key 的用户直接用
服务端共享池；聊天里上传文件应成功（浏览器直传 `s3.example.com`）。

## 用户与密钥模型

- **准入**：`AUTH_ALLOWED_EMAILS` 决定谁能进。加人 = 往该变量加邮箱后
  `docker compose up -d --force-recreate lobe`。
- **共享池**：`.env` 里的 key 所有登录用户可用、不可见、不可改。
- **个人 BYOK**：用户在设置里填自己的 key（加密按人存）；填了用自己的，否则用共享池。

## 注意

- Cloudflare 免费版单请求上传上限约 **100MB**（聊天附件通常够用）。
- 上传报跨域/403：确认 `RUSTFS_CORS_ALLOWED_ORIGINS` 等于 App 域名、`S3_ENDPOINT` 用
  `s3.` 公开主机名、`S3_ENABLE_PATH_STYLE=1`。
- `CF_TUNNEL_TOKEN` 与各 key 只放 `.env`（已被 `.gitignore` 忽略），不要提交。
