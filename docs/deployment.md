# 部署流程

## 1. 准备 `.env`

```bash
cp .env.example .env
nano .env
```

至少替换：

```text
DB_PASS
NEWAPI_MASTER_KEY
CF_TUNNEL_TOKEN
WEBUI_SECRET_KEY
IMAGE_BASIC_AUTH_HASH
XUI_ADMIN_PASSWORD
NAT_SSH_HOST / NAT_SSH_PORT / NAT_SSH_USER / NAT_SSH_KEY_PATH
```

生成 `WEBUI_SECRET_KEY`：

```bash
openssl rand -hex 32
```

生成 Caddy Basic Auth 哈希：

```bash
docker run --rm caddy:2-alpine caddy hash-password --plaintext '你的密码'
```

## 2. Fresh 部署

```bash
sudo bash deploy.sh fresh --yes
```

脚本会执行：

```text
基础软件包、UFW、fail2ban、swap
Docker CE
/opt/Serve 主平台文件渲染
/opt/Serve/xui 3xui 容器部署
postgres/newapi/open-webui/gpt-image-playground/caddy/cloudflared 启动
autossh + Privoxy + ai-proxy-firewall
PostgreSQL 每日备份 cron
最终网络验证
```

## 3. Cloudflare 手动配置

```text
chat.example.com  -> HTTP open-webui:8080，不加 Access
api.example.com   -> HTTP newapi:3000，加 Access，仅管理员邮箱
proxy.example.com -> HTTP xui-3xui:12053，加 Access，仅管理员邮箱
image.example.com -> DNS only / 灰云，A 到 HK VPS IP
```

## 4. 3xui 手动配置

脚本会部署 3xui 面板和开放 Reality 端口，但 Reality 入站、`nat-ai` 出站、路由规则仍建议在 3xui 面板中配置。

出站：

```json
{
  "tag": "nat-ai",
  "protocol": "http",
  "settings": {
    "servers": [
      {
        "address": "172.19.0.1",
        "port": 7890
      }
    ]
  }
}
```

## 5. 重要约束

不要开放：

```text
3000
8080
12053
5432
0.0.0.0:7890
```

不要提交：

```text
.env
pg_data/
newapi_data/
open-webui_data/
xui/db/
caddy_data/
真实 token、密码、API Key、SSH 私钥
```

## Open WebUI 用户权限策略

默认策略是：管理员维护外部连接和模型，普通用户可以使用所有管理员配置好的模型，但不能自填 API Key 或外部连接。

```env
OPENWEBUI_BYPASS_MODEL_ACCESS_CONTROL=true
OPENWEBUI_ENABLE_DIRECT_CONNECTIONS=false
OPENWEBUI_ENABLE_API_KEYS=false
OPENWEBUI_USER_PERMISSIONS_FEATURES_API_KEYS=false
OPENWEBUI_ENABLE_WEB_SEARCH=true
OPENWEBUI_WEB_SEARCH_ENGINE=duckduckgo
OPENWEBUI_BYPASS_WEB_SEARCH_WEB_LOADER=true
OPENWEBUI_BYPASS_WEB_SEARCH_EMBEDDING_AND_RETRIEVAL=true
OPENWEBUI_USER_PERMISSIONS_FEATURES_WEB_SEARCH=true
```

Web Search 默认使用 `duckduckgo`，这是最简单的无 key 方案。默认绕过网页正文加载和向量检索，直接用搜索结果标题/摘要作为上下文和引用来源，避免搜索引擎能返回结果但网页抓取失败导致聊天里显示“未找到引用来源”。普通用户可以使用搜索按钮/联网搜索，但仍不能自填外部连接或个人 API Key。Open WebUI 容器不配置代理，搜索走 HK VPS 默认出口；NewAPI 调模型仍走既有 NAT VPS 代理链路。

`NEWAPI_MASTER_KEY` 必须填 NewAPI 后台创建的有效 OpenAI 兼容 token，通常以 `sk-` 开头。它是 Open WebUI 连接 `http://newapi:3000/v1` 的服务 token，不是 NewAPI 管理后台密码，也不能使用已经删除、停用、额度耗尽或分组无模型权限的 token。

如果普通用户和管理员都看不到模型，优先在服务器内部检查 NewAPI token 是否能返回模型：

```bash
cd /opt/Serve
docker exec -i open-webui python - <<'PY'
import asyncio, aiohttp, json
from open_webui.config import OPENAI_API_BASE_URLS, OPENAI_API_KEYS

async def main():
    url = OPENAI_API_BASE_URLS.value[0].rstrip("/") + "/models"
    key = OPENAI_API_KEYS.value[0]
    async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=20), trust_env=True) as session:
        async with session.get(url, headers={"Authorization": "Bearer " + key}) as response:
            data = json.loads(await response.text())
            items = data.get("data", []) if isinstance(data, dict) else []
            print("status=", response.status, "model_count=", len(items))
            print("first_ids=", [item.get("id") for item in items[:5]])

asyncio.run(main())
PY
```

预期是 `status= 200` 且 `model_count` 大于 0。若返回 `401` 或 `Invalid token`，需要在 NewAPI 后台新建/启用 token，更新 `.env` 的 `NEWAPI_MASTER_KEY`，再执行：

```bash
cd /opt/Serve
docker compose config --quiet
docker compose up -d --force-recreate open-webui
```
