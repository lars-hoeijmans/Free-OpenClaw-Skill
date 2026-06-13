#!/usr/bin/env bash
set -eo pipefail

SSH_TARGET="${SSH_TARGET:-}"
OPENCLAW_PORT="${OPENCLAW_PORT:-18789}"

if [[ -z "$SSH_TARGET" ]]; then
  echo "Set SSH_TARGET, for example: SSH_TARGET=ubuntu@openclaw $0" >&2
  exit 1
fi

ssh -o StrictHostKeyChecking=accept-new "$SSH_TARGET" bash -s <<REMOTE
set -eo pipefail

if ! command -v openclaw >/dev/null 2>&1 && [[ ! -x "\$HOME/.npm-global/bin/openclaw" ]]; then
  curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard
fi

if ! grep -qxF 'export PATH="\$HOME/.npm-global/bin:\$PATH"' "\$HOME/.bashrc"; then
  printf '\\nexport PATH="\$HOME/.npm-global/bin:\$PATH"\\n' >> "\$HOME/.bashrc"
fi

export PATH="\$HOME/.npm-global/bin:\$PATH"

openclaw setup --non-interactive --accept-risk --mode local --workspace "\$HOME/.openclaw/workspace" --skip-health || true
openclaw config set gateway.bind loopback
openclaw config set gateway.auth.mode token
openclaw doctor --generate-gateway-token --non-interactive --yes
openclaw config set gateway.tailscale.mode serve
openclaw config set gateway.trustedProxies '["127.0.0.1"]'
openclaw config validate
chmod 700 "\$HOME/.openclaw"

openclaw gateway install --force --port "$OPENCLAW_PORT"
openclaw gateway start

echo
openclaw --version
openclaw gateway health
systemctl --user is-active openclaw-gateway.service

echo
# Serve needs operator rights for the gateway's non-root user, plus tailnet-level Serve enablement.
sudo tailscale set --operator="\$(id -un)" || true
echo "Trying Tailscale Serve. If it prints an approval URL, the tailnet admin approves it once,"
echo "then rerun this script (or run: tailscale serve --bg --yes $OPENCLAW_PORT)."
tailscale serve --bg --yes "$OPENCLAW_PORT" || true
tailscale serve status || true

echo
echo "If Serve is unavailable, tunnel from your client:"
echo "  ssh -L $OPENCLAW_PORT:127.0.0.1:$OPENCLAW_PORT $SSH_TARGET"
REMOTE
