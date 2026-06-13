#!/usr/bin/env bash
set -eo pipefail

SSH_TARGET="${SSH_TARGET:-}"
TAILSCALE_HOSTNAME="${TAILSCALE_HOSTNAME:-openclaw}"
REMOTE_USER_HOME="${REMOTE_USER_HOME:-/home/ubuntu}"

if [[ -z "$SSH_TARGET" ]]; then
  echo "Set SSH_TARGET, for example: SSH_TARGET=ubuntu@PUBLIC_IP $0" >&2
  exit 1
fi

ssh -o StrictHostKeyChecking=accept-new "$SSH_TARGET" bash -s <<REMOTE
set -eo pipefail

sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y
sudo DEBIAN_FRONTEND=noninteractive apt install -y build-essential curl git ca-certificates
sudo hostnamectl set-hostname "$TAILSCALE_HOSTNAME"
sudo loginctl enable-linger "\$(id -un)"

if ! command -v tailscale >/dev/null 2>&1; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi

sudo systemctl enable --now tailscaled

if ! tailscale status >/dev/null 2>&1; then
  echo
  echo "Approve the Tailscale URL printed below."
  sudo tailscale up --ssh --hostname="$TAILSCALE_HOSTNAME"
else
  echo "Tailscale is already logged in."
fi

echo
echo "Bootstrap complete."
echo "Verify from your client: ssh \$(id -un)@$TAILSCALE_HOSTNAME"
REMOTE
