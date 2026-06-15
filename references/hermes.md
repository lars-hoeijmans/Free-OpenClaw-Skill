# Hermes Guide

Use this guide after the Oracle/Tailscale foundation is complete. It works independently from
the OpenClaw path.

Official install docs: https://hermes-agent.nousresearch.com/docs/getting-started/installation

## Install Hermes

Recommended side-by-side install under the server user:

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
export PATH="$HOME/.local/bin:$PATH"
hermes --version
hermes config migrate || true
hermes doctor
```

Hermes installs per-user code/data under `~/.hermes` and the command at `~/.local/bin/hermes`.
The installer handles Python, Node, ripgrep, ffmpeg, Playwright/browser tooling, the repo clone,
venv, and global command setup. On headless servers you may choose `--skip-browser`, but browser
automation is useful for web-app QA, so prefer the full install when resources allow.

The helper script is safe for a base install and intentionally leaves the gateway stopped:

```bash
SSH_TARGET=ubuntu@openclaw ./scripts/install-hermes-base.sh
```

## Models

Official provider docs: https://hermes-agent.nousresearch.com/docs/integrations/providers

Ask the user which model route they want:

- OpenCode Zen free models.
- OpenAI Codex / ChatGPT OAuth.
- Nous Portal OAuth.
- Bring an API key.

### OpenCode Zen

Hermes has first-class `opencode-zen` support. Store the key in `~/.hermes/.env`, not in project
docs or chat:

```bash
printf '\nOPENCODE_ZEN_API_KEY=%s\n' '<entered-by-human>' >> ~/.hermes/.env
chmod 600 ~/.hermes/.env
hermes config set model.provider opencode-zen
hermes config set model.default <tested-free-model-id>
hermes config set model.base_url https://opencode.ai/zen/v1
hermes config set model.api_mode openai_chat
```

Test before persisting:

```bash
hermes -z "Reply exactly: PONG" --provider opencode-zen --model <model-id>
```

Known lesson from a real Oracle A1 install: `mimo-v2.5-free` and `nemotron-3-ultra-free` worked
in Hermes; `deepseek-v4-flash` did not produce a final response there. Treat all model IDs as
point-in-time examples and test live.

Fallback example:

```bash
hermes config set model.default mimo-v2.5-free
hermes config set fallback_models '["nemotron-3-ultra-free"]'
hermes -z "Reply exactly: PONG"
```

### OpenAI Codex / ChatGPT OAuth

Hermes supports OpenAI Codex via device-code OAuth. It stores credentials in `~/.hermes/auth.json`
and can sometimes import existing Codex CLI credentials from `~/.codex/auth.json`, but do not rely
on that. If import fails, run a fresh device login:

```bash
hermes auth add openai-codex --type oauth --no-browser
```

The user opens the URL, enters the code, and approves. Then test:

```bash
hermes -z "Reply exactly: PONG" --provider openai-codex --model gpt-5.4-mini
```

Use only models that actually generate for the user's subscription.

## Gateway

Install the gateway service only after models work:

```bash
hermes gateway install
hermes gateway status
```

For evaluation beside OpenClaw, install the service but keep it stopped/disabled until Hermes has
separate channel tokens:

```bash
systemctl --user disable --now hermes-gateway.service || true
systemctl --user status hermes-gateway.service --no-pager
```

For Hermes as the live assistant, enable/start it:

```bash
sudo loginctl enable-linger "$(id -un)"
systemctl --user enable --now hermes-gateway.service
hermes gateway status
hermes doctor
```

Do not let two gateways use the same Telegram bot token or Slack app/socket token.

## Channels

Use separate identities if OpenClaw is still live:

- Separate Telegram bot for Hermes.
- Separate Slack app for Hermes.
- Skip WhatsApp unless the user has a spare number and accepts the ban/account-risk model.

After adding a channel, owner-lock it before restart/hand-off. Use the Hermes channel docs for the
current exact keys, then verify with `hermes gateway status` and an end-to-end message.

Known cutover lessons:

- `TELEGRAM_ALLOWED_USERS` expects bare numeric Telegram user IDs, for example `123456789`.
- `SLACK_ALLOWED_USERS` expects bare Slack member IDs, for example `U01ABC2DEF3`, not
  OpenClaw-style `slack:U01ABC2DEF3`.
- Keep `GATEWAY_ALLOW_ALL_USERS=false` unless the user explicitly accepts a public bot.
- Hermes can test outbound delivery with `hermes send --to telegram:<chat_id> "message"` and
  `hermes send --to slack:<channel_id> "message"` after the gateway has discovered or been given
  a target.
- Slack `/claudia` is an OpenClaw-era custom command. Hermes uses DMs, mentions, `/hermes`, and
  Hermes' generated native slash commands unless the Slack app manifest is updated.

## Delegation

Official delegation docs: https://hermes-agent.nousresearch.com/docs/user-guide/features/delegation

Hermes has native `delegate_task` subagents. Do not force an "orchestrator-only" system prompt by
default. Use a light instruction instead:

> Use `delegate_task` for independent research, coding, QA, or long-running workstreams, then
> summarize results back to the main session.

Defaults from the docs:

- `delegation.max_concurrent_children`: 3 concurrent children.
- `delegate_task` is synchronous and blocks the parent turn.
- For durable long-running work, prefer cron jobs or background terminal commands.

Only raise spawn depth/concurrency after the user understands cost and parallelism.

## Verification

Minimum checks:

```bash
hermes --version
hermes config check || hermes config migrate
hermes doctor
hermes status
hermes -z "Reply exactly: PONG"
```

If gateway is enabled:

```bash
systemctl --user is-active hermes-gateway.service
hermes gateway status
```

## Finish Line

Tell the user Hermes can also grow itself:

> "From here, message Hermes and ask it to install Codex CLI, Claude Code, GitHub CLI, Playwright,
> ffmpeg, voice tooling, or MCP servers. Let it save working recipes into its own notes/skills."
