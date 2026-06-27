#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

require_root
load_env

log "Installing base packages"
apt update
apt -y upgrade
apt install -y \
  curl wget git vim nano htop unzip jq ca-certificates gnupg lsb-release \
  ufw cron logrotate openssl

if ! swapon --show | grep -q '^/swapfile'; then
  log "Creating 2G swapfile"
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

cat >/etc/sysctl.d/97-swap.conf <<'EOF2'
vm.swappiness=10
vm.vfs_cache_pressure=50
EOF2

sysctl --system

# Firewall: deny inbound by default, but never lock out SSH. Allow whatever
# port(s) sshd actually listens on, plus an optional configured SSH_PORT.
ufw default deny incoming
ufw default allow outgoing

ssh_ports="$(ss -tlnpH 2>/dev/null | awk '/sshd/{print $4}' | sed -E 's/.*:([0-9]+)$/\1/')"
[[ -z "$ssh_ports" ]] && ssh_ports="$(sshd -T 2>/dev/null | awk '/^port /{print $2}')"
[[ -n "${SSH_PORT:-}" ]] && ssh_ports="$ssh_ports ${SSH_PORT}"
ssh_ports="$(printf '%s\n' $ssh_ports | grep -E '^[0-9]+$' | sort -u)"
[[ -z "$ssh_ports" ]] && ssh_ports=22
for p in $ssh_ports; do
  log "Allowing SSH port $p/tcp through the firewall"
  ufw allow "$p/tcp" comment 'SSH' || true
done

ufw --force enable

log "Base system setup complete"
