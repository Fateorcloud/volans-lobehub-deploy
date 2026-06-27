# Volans LobeHub Self-Deploy Kit

English | [Chinese](README.md)

A small self-hosting toolkit for LobeHub. It deploys
`LobeHub + PostgreSQL/PGVector + Redis + RustFS/S3 + SearXNG` on a single server
and publishes it on your own domain through a Cloudflare Tunnel (no open ports,
TLS at the edge).

The previous NewAPI, Open WebUI, GPT Image Playground, Caddy image site, xui,
and NAT egress proxy have been removed from this project. The old deployable
chain is backed up in the GitHub repo `Fateorcloud/volans-ai-platform-deploy`,
branch `codex/legacy-ai-stack-backup`. xui/NAT now lives in a separate deploy
project.

## Architecture

```text
Browser (HTTPS)
  -> chat.<domain>  -> Cloudflare Tunnel -> 127.0.0.1:3210  LobeHub
  -> s3.<domain>    -> Cloudflare Tunnel -> 127.0.0.1:9000  RustFS S3 (uploads)

LobeHub (on the server)
  -> 127.0.0.1:15432 PostgreSQL / PGVector
  -> 127.0.0.1:16379 Redis
  -> 127.0.0.1:9000  RustFS
  -> 127.0.0.1:18080 SearXNG
  -> provider APIs configured in .env
```

LobeHub uses host networking so `S3_ENDPOINT` is reachable by both the LobeHub
server and the browser through the tunnel. All data services bind to `127.0.0.1`
only and open no public ports — the Cloudflare Tunnel is the single ingress.

## Suitable For

- Replacing a heavier AI platform while keeping a modern, persistent front end
  for yourself or a small team.
- Gating sign-up to your own domain with an `AUTH_ALLOWED_EMAILS` allowlist.
- Connecting providers such as OpenAI, Anthropic, Google/Gemini, DeepSeek, and
  OpenRouter.
- Restoring later on another server by copying `/opt/lobehub`, `.env`, and backups.

Not for: commercial billing, complex team permissions, API gateway metering, or
workflow app platforms. Use LibreChat, LiteLLM, or Dify for those.

## Step 1: Deploy on the server

On a fresh Ubuntu 22.04/24.04 VPS:

```bash
git clone https://github.com/Fateorcloud/volans-lobehub-deploy.git
cd volans-lobehub-deploy
cp .env.example .env
nano .env
sudo bash deploy.sh fresh --yes
```

### Required: 6 secrets (none may keep the `CHANGE_ME...` default — preflight rejects them)

| Variable | What it protects | Generate with |
|---|---|---|
| `KEY_VAULTS_SECRET` | Encrypts the API keys users store server-side (per-user key vault) | `openssl rand -base64 32` |
| `AUTH_SECRET` | Signs login sessions (tamper protection) | `openssl rand -base64 32` |
| `POSTGRES_PASSWORD` | PostgreSQL database password | `openssl rand -hex 32` |
| `RUSTFS_ACCESS_KEY` | Object-storage (files/images) access key | `openssl rand -hex 16` |
| `RUSTFS_SECRET_KEY` | Object-storage secret key | `openssl rand -hex 32` |
| `SEARXNG_SECRET` | Signing secret for the built-in search service | `openssl rand -hex 32` |

Generate them all at once and paste the output into `.env`:

```bash
for v in KEY_VAULTS_SECRET AUTH_SECRET; do echo "$v=$(openssl rand -base64 32)"; done
for v in POSTGRES_PASSWORD RUSTFS_SECRET_KEY SEARXNG_SECRET; do echo "$v=$(openssl rand -hex 32)"; done
echo "RUSTFS_ACCESS_KEY=$(openssl rand -hex 16)"
```

> **SSH port**: the deploy enables the UFW firewall and auto-allows the port sshd is currently listening on. If your SSH runs on a non-standard port, also set `SSH_PORT` in `.env` as a belt-and-suspenders (default 22).

Model provider keys are optional (it starts without them, but can't chat until at least one is set); leave unused ones empty:

```text
OPENAI_API_KEY / ANTHROPIC_API_KEY / GOOGLE_API_KEY / DEEPSEEK_API_KEY / OPENROUTER_API_KEY ...
```

These form a server-side shared pool: all logged-in users can use them, and each user may add their own private key in Settings.

## Step 2: Publish on your domain (Cloudflare Tunnel)

Expose the platform on your own domain — no open ports, TLS at the Cloudflare
edge, faster first paint. Serve the app at `chat.<domain>` and storage at
`s3.<domain>`, and gate sign-up with `AUTH_ALLOWED_EMAILS`. Set the tunnel and
public domains in `.env`, then restart:

```env
COMPOSE_PROFILES=tunnel
CF_TUNNEL_TOKEN=<your tunnel token>
APP_URL=https://chat.<domain>
S3_ENDPOINT=https://s3.<domain>
S3_PUBLIC_DOMAIN=https://s3.<domain>
RUSTFS_CORS_ALLOWED_ORIGINS=https://chat.<domain>
AUTH_ALLOWED_EMAILS=you@example.com,teammate@example.com
```

For the full walkthrough — create the tunnel, add the two hostnames (origin is
**HTTP**: `http://127.0.0.1:3210` and `http://127.0.0.1:9000`), start, verify,
add users / rotate keys — see
[Public access: Cloudflare Tunnel + domain](docs/public-access.md). When done,
open `https://chat.<domain>`.

## Operations

```bash
sudo bash deploy.sh verify
sudo bash deploy.sh backup
sudo bash deploy.sh repair --yes
```

Deploy directory:

```text
/opt/lobehub
```

Useful checks:

```bash
cd /opt/lobehub
docker compose ps
docker compose logs -f lobehub
docker compose logs -f lobe-rustfs
```

> Debug only (optional): before the domain is set up you can reach it over an SSH
> tunnel — `ssh -L 3210:127.0.0.1:3210 <server-alias>`, then open
> `http://127.0.0.1:3210`.

## Backup And Migration

Manual backup:

```bash
sudo bash deploy.sh backup
```

Default backup files:

```text
/opt/lobehub/backup/postgres_lobechat_YYYY-MM-DD_HHMMSS.sql.gz
/opt/lobehub/backup/rustfs_data_YYYY-MM-DD_HHMMSS.tar.gz
```

For a second server, copy the private `.env`, restore PostgreSQL, restore RustFS
data, then run the verification command. Never commit these private artifacts.

## More Docs

- [Deployment flow](docs/deployment.md)
- [Public access (Cloudflare Tunnel + domain)](docs/public-access.md)
- [Operations](docs/operations.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Migration and trim](docs/migration-and-trim.md)
- [Open-source release checklist](docs/open-source-release.md)

## Open Source Safety

```bash
bash deploy.sh security-scan
git status --short
```

Do not commit real `.env`, API keys, server IPs, SSH keys, database directories,
RustFS logs, or backups.
