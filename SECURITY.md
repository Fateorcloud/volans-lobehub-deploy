# Security Policy

This repository is designed to be public. Do not commit production secrets,
server-specific credentials, database dumps, user lists, private keys, or
backup archives.

## Never Commit

- `.env` or any filled environment file
- Cloudflare Tunnel tokens
- NewAPI/OpenAI-compatible tokens
- Open WebUI secret keys
- SSH private keys or NAT VPS credentials
- Caddy Basic Auth plaintext passwords
- 3xui database files, admin credentials, Reality private keys, client UUID lists
- PostgreSQL, NewAPI, Open WebUI, Caddy, or 3xui data directories
- Generated Mihomo/Clash client configs containing real UUIDs, IPs, or keys

## Before Publishing

Run:

```bash
bash scripts/80_security_scan.sh
```

The scan is intentionally conservative. If it reports a false positive, prefer
rewriting the file to use placeholders instead of adding broad allow rules.

## Runtime Boundaries

The expected public ports are:

```text
SSH custom port
80/tcp and 443/tcp for Caddy image site
XUI_REALITY_PORT/tcp for the VLESS Reality node
```

These services must not be publicly reachable:

```text
NewAPI 3000
Open WebUI 8080
3xui panel port
PostgreSQL 5432
Privoxy 7890
SSH SOCKS 10808
```

## Reporting

For a public fork, open a private advisory if available. Otherwise, contact the
repository owner privately and avoid posting live tokens, IP-bound credentials,
or exploit details in public issues.
