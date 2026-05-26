# Open Source Release Checklist

Use this checklist before creating a public GitHub repository.

## Required Files

- `README.md` explains architecture, manual Cloudflare steps, deployment, and verification.
- `.env.example` contains only placeholders.
- `.gitignore` excludes generated credentials, databases, backups, and client configs.
- `LICENSE` is present.
- `SECURITY.md` documents secret handling and public port boundaries.
- `scripts/80_security_scan.sh` passes.

## Privacy Review

Confirm the repository does not contain:

- Real domains that you do not want public.
- Real VPS IP addresses.
- Real Cloudflare Tunnel tokens or Access policy IDs.
- Real NewAPI/OpenAI tokens.
- Real Open WebUI `WEBUI_SECRET_KEY`.
- Real Basic Auth plaintext passwords or hashes tied to production.
- SSH private keys, public keys, known-hosts files, or NAT VPS usernames.
- 3xui SQLite databases, Reality private keys, client UUIDs, or subscriptions.
- Generated Mihomo/Clash config files for live clients.

## Suggested Release Commands

```bash
bash scripts/80_security_scan.sh
git init
git add .
git status --short
git commit -m "Initial open source deployment toolkit"
```

Create the GitHub repository after the scan passes and the staged file list
looks clean.

## GitHub Repository Settings

Recommended:

- Public repository only after the first security scan passes.
- Disable GitHub Actions secrets until workflows are intentionally added.
- Enable secret scanning if available for the account.
- Add a short repository description:

```text
One-shot Ubuntu deployment toolkit for Open WebUI, NewAPI, Cloudflare Tunnel,
GPT Image Playground, and 3xui split egress.
```
