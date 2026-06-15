#!/usr/bin/env bash
set -eo pipefail

SSH_TARGET="${SSH_TARGET:-}"

if [[ -z "$SSH_TARGET" ]]; then
  echo "Set SSH_TARGET, for example: SSH_TARGET=ubuntu@openclaw $0" >&2
  exit 1
fi

ssh -o StrictHostKeyChecking=accept-new "$SSH_TARGET" bash -s <<'REMOTE'
set -eo pipefail

sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt install -y build-essential curl git ca-certificates jq
sudo loginctl enable-linger "$(id -un)"

if ! command -v hermes >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/hermes" ]]; then
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
fi

if ! grep -qxF 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc"; then
  printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.bashrc"
fi

export PATH="$HOME/.local/bin:$PATH"

hermes --version
hermes config migrate || true
hermes doctor || true

# Install the gateway unit for later evaluation, but keep it stopped/disabled until separate
# channel identities are configured. This avoids fighting a live OpenClaw gateway for tokens.
if hermes gateway status >/dev/null 2>&1; then
  echo "Hermes gateway command is available."
fi

if ! systemctl --user list-unit-files | grep -q '^hermes-gateway.service'; then
  printf 'n\nn\n' | hermes gateway install || true
fi

systemctl --user disable --now hermes-gateway.service >/dev/null 2>&1 || true

echo
echo "Hermes base install complete."
echo "Gateway service is installed if supported, but intentionally stopped/disabled."
echo "Configure models and separate channel tokens before enabling it."
REMOTE
