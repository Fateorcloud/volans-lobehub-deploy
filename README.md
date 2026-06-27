# Volans LobeHub 自部署工具

[English](README.en.md) | 简体中文

面向个人或小团队的 LobeHub 自部署模板：在一台服务器上部署
`LobeHub + PostgreSQL/PGVector + Redis + RustFS/S3 + SearXNG`，并通过你自己的域名
（Cloudflare Tunnel，不开公网端口、TLS 在边缘完成）公开访问。

旧的 NewAPI、Open WebUI、GPT Image Playground、Caddy 图站、xui 和 NAT 出站代理不再属于本项目。
这套旧链路已经备份在 GitHub 仓库 `Fateorcloud/volans-ai-platform-deploy` 的
`codex/legacy-ai-stack-backup` 分支，需要复用时从该分支恢复。xui/NAT 现在作为独立部署项目维护，
不属于 LobeHub AI 平台核心栈。

## 架构

```text
浏览器（HTTPS）
  -> chat.<域名>  -> Cloudflare Tunnel -> 127.0.0.1:3210  LobeHub
  -> s3.<域名>    -> Cloudflare Tunnel -> 127.0.0.1:9000  RustFS S3（文件上传）

LobeHub（服务器本机）
  -> 127.0.0.1:15432 PostgreSQL / PGVector
  -> 127.0.0.1:16379 Redis
  -> 127.0.0.1:9000  RustFS
  -> 127.0.0.1:18080 SearXNG
  -> .env 中配置的模型供应商 API
```

LobeHub 容器使用 host network，使 `S3_ENDPOINT` 同时对 LobeHub 服务端和经隧道访问的浏览器可达；
其余持久化服务只绑定 `127.0.0.1`，不开任何公网端口——Cloudflare Tunnel 是唯一入口。

## 适合场景

- 你想替换复杂 AI 平台，保留一个现代、可持久化的前端，给自己或小团队使用。
- 你希望通过自己的域名 + 白名单（`AUTH_ALLOWED_EMAILS`）控制谁能注册登录。
- 你希望接入 OpenAI、Anthropic、Google/Gemini、DeepSeek、OpenRouter 等供应商。
- 你希望将来能把 `/opt/lobehub`、`.env` 和备份复制到另一台服务器恢复。

不适合：需要商业计费、复杂团队权限、API 网关计量或工作流应用平台的场景。那些需求
应另行选 LibreChat、LiteLLM 或 Dify。

## 第一步：在服务器部署

在一台新的 Ubuntu 22.04/24.04 VPS 上：

```bash
git clone https://github.com/Fateorcloud/volans-lobehub-deploy.git
cd volans-lobehub-deploy
cp .env.example .env
nano .env
sudo bash deploy.sh fresh --yes
```

### 必填：6 个密钥（都不能留默认 `CHANGE_ME...`，否则 preflight 会拒绝部署）

| 变量 | 作用 | 生成 |
|---|---|---|
| `KEY_VAULTS_SECRET` | 加密用户存在服务端的 API key（用户密钥保险箱） | `openssl rand -base64 32` |
| `AUTH_SECRET` | 给登录会话签名、防伪造 | `openssl rand -base64 32` |
| `POSTGRES_PASSWORD` | PostgreSQL 数据库密码 | `openssl rand -hex 32` |
| `RUSTFS_ACCESS_KEY` | 对象存储（文件/图片）访问账号 | `openssl rand -hex 16` |
| `RUSTFS_SECRET_KEY` | 对象存储密钥 | `openssl rand -hex 32` |
| `SEARXNG_SECRET` | 内置搜索服务的签名密钥 | `openssl rand -hex 32` |

一次性生成全部，把输出对应填进 `.env`：

```bash
for v in KEY_VAULTS_SECRET AUTH_SECRET; do echo "$v=$(openssl rand -base64 32)"; done
for v in POSTGRES_PASSWORD RUSTFS_SECRET_KEY SEARXNG_SECRET; do echo "$v=$(openssl rand -hex 32)"; done
echo "RUSTFS_ACCESS_KEY=$(openssl rand -hex 16)"
```

> **SSH 端口**：部署会启用 UFW 防火墙并自动放行 sshd 当前监听的端口；若你的 SSH 跑在非标准端口，把 `.env` 的 `SSH_PORT` 也设成它做双保险（默认 22）。

模型供应商 key 按需填写（不填也能启动，只是不能真正对话），未使用的留空：

```text
OPENAI_API_KEY / ANTHROPIC_API_KEY / GOOGLE_API_KEY / DEEPSEEK_API_KEY / OPENROUTER_API_KEY ...
```

这些是「服务端共享池」：所有登录用户可用；用户也可在设置里填自己的私有 key（填了用自己的）。

## 第二步：用域名公开访问（Cloudflare Tunnel）

把平台发布到你自己的域名：不开公网端口、TLS 在 Cloudflare 边缘完成、首屏更快。App 走
`chat.<域名>`、文件存储走 `s3.<域名>`，用 `AUTH_ALLOWED_EMAILS` 白名单控制谁能注册。
在 `.env` 配好隧道与公开域名后重启服务即可：

```env
COMPOSE_PROFILES=tunnel
CF_TUNNEL_TOKEN=<你的隧道 token>
APP_URL=https://chat.<域名>
S3_ENDPOINT=https://s3.<域名>
S3_PUBLIC_DOMAIN=https://s3.<域名>
RUSTFS_CORS_ALLOWED_ORIGINS=https://chat.<域名>
AUTH_ALLOWED_EMAILS=you@example.com,teammate@example.com
```

建隧道、加两个主机名（回源填 **HTTP**：`http://127.0.0.1:3210`、`http://127.0.0.1:9000`）、
启动、验证、加人/换 key 的完整步骤见
[公开部署：Cloudflare Tunnel + 域名](docs/public-access.md)。配置完成后浏览器打开
`https://chat.<域名>` 即可使用。

## 运维命令

```bash
sudo bash deploy.sh verify
sudo bash deploy.sh backup
sudo bash deploy.sh repair --yes
```

服务目录：

```text
/opt/lobehub
```

常用检查：

```bash
cd /opt/lobehub
docker compose ps
docker compose logs -f lobehub
docker compose logs -f lobe-rustfs
```

> 仅调试用（可选）：域名还没配好前，可临时用 SSH 隧道访问
> `ssh -L 3210:127.0.0.1:3210 <server-alias>`，再打开 `http://127.0.0.1:3210`。

## 备份与迁移

手动备份：

```bash
sudo bash deploy.sh backup
```

备份文件默认写入：

```text
/opt/lobehub/backup/postgres_lobechat_YYYY-MM-DD_HHMMSS.sql.gz
/opt/lobehub/backup/rustfs_data_YYYY-MM-DD_HHMMSS.tar.gz
```

迁移到另一台服务器时，复制：

```text
/opt/lobehub/.env
PostgreSQL 备份
RustFS 备份
```

不要把这些文件提交到 Git。

## 更多文档

- [部署流程](docs/deployment.md)
- [公开部署（Cloudflare Tunnel + 域名）](docs/public-access.md)
- [运维手册](docs/operations.md)
- [排障](docs/troubleshooting.md)
- [迁移与裁剪](docs/migration-and-trim.md)
- [开源发布检查](docs/open-source-release.md)

## 开源前检查

```bash
bash deploy.sh security-scan
git status --short
```

不要提交真实 `.env`、API key、服务器 IP、SSH key、数据库目录、RustFS 日志或备份包。
