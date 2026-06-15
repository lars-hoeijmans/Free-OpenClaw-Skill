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

HERMES_SOUL="$HOME/.hermes/SOUL.md"
mkdir -p "$(dirname "$HERMES_SOUL")"
touch "$HERMES_SOUL"

# Hermes does not add these operating defaults by itself. This skill adds them so new installs
# inherit the delegation/coding-harness/documentation behavior validated in the live setup.
DEFAULTS_BLOCK="$(mktemp)"
cat > "$DEFAULTS_BLOCK" <<'SOUL'
<!-- BEGIN FREE-ORACLE-AGENT-HERMES-DEFAULTS -->
## Operating Defaults

**Delegate longer tasks to sub-agents.** When the user asks for research, analysis, multi-step
builds, QA, debugging, setup, or anything that would take more than a few tool calls, use Hermes
`delegate_task` sub-agents so the main conversation stays the coordinating surface. Handle quick
questions, simple lookups, and small edits directly.

Run independent workstreams in parallel when useful, then summarize each result back to the main
session with status, evidence, file paths, commands run, and remaining blockers. For truly durable
background work, use explicit terminal/systemd/cron jobs and document how to inspect, stop, and
clean them up.

**Route coding tasks to coding harnesses.** For repository/codebase work such as building apps,
implementing features, debugging, refactoring, tests, reviews, QA automation, or PR preparation,
delegate to a specialized coding harness by default. Prefer Codex CLI when available; use Claude
Code or the user's configured coding agent as the fallback. Keep Hermes as the coordinator: clarify
the goal, launch/monitor the coding harness with the right repo context, then summarize diffs,
tests, risks, and next steps back to the user. Do not do heavy coding inline unless no harness is
available or the change is clearly trivial.

Whenever you install or enable a new capability, record exact commands, paths, usage notes,
verification, and cleanup in the workspace notes so future sessions do not rediscover the setup.
<!-- END FREE-ORACLE-AGENT-HERMES-DEFAULTS -->
SOUL

if ! grep -q 'BEGIN FREE-ORACLE-AGENT-HERMES-DEFAULTS' "$HERMES_SOUL"; then
  printf '\n' >> "$HERMES_SOUL"
  cat "$DEFAULTS_BLOCK" >> "$HERMES_SOUL"
  echo "Hermes SOUL.md operating defaults added."
elif ! grep -q 'Route coding tasks to coding harnesses' "$HERMES_SOUL"; then
  TMP_SOUL="$(mktemp)"
  awk -v block_file="$DEFAULTS_BLOCK" '
    BEGIN {
      while ((getline line < block_file) > 0) {
        block = block line ORS
      }
    }
    /<!-- BEGIN FREE-ORACLE-AGENT-HERMES-DEFAULTS -->/ {
      printf "%s", block
      in_block = 1
      next
    }
    /<!-- END FREE-ORACLE-AGENT-HERMES-DEFAULTS -->/ && in_block {
      in_block = 0
      next
    }
    !in_block { print }
  ' "$HERMES_SOUL" > "$TMP_SOUL"
  cat "$TMP_SOUL" > "$HERMES_SOUL"
  rm -f "$TMP_SOUL"
  echo "Hermes SOUL.md operating defaults upgraded."
else
  echo "Hermes SOUL.md operating defaults already present."
fi
rm -f "$DEFAULTS_BLOCK"

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
