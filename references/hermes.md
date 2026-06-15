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
hermes config set approvals.mode smart
awk '
  /^approvals:/ { in_approvals = 1; next }
  in_approvals && /^[^[:space:]]/ { exit }
  in_approvals && $1 == "mode:" { print $2; exit }
' ~/.hermes/config.yaml
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

## Approval Mode

Official security docs: https://hermes-agent.nousresearch.com/docs/user-guide/security

Do not rely on interactive `hermes setup` for this workflow. The skill uses non-interactive
server installs, so set the approval mode explicitly after config migration:

```bash
hermes config set approvals.mode smart
awk '
  /^approvals:/ { in_approvals = 1; next }
  in_approvals && /^[^[:space:]]/ { exit }
  in_approvals && $1 == "mode:" { print $2; exit }
' ~/.hermes/config.yaml
```

`smart` is the recommended middle ground: Hermes can auto-approve low-risk flagged commands, deny
genuinely dangerous commands, and escalate uncertain cases. Do not set `approvals.mode off` unless
the user explicitly asks for a YOLO/sandboxed setup and understands the risk.

Hermes does not ship with this delegation/coding-harness/documentation persona by default. This
skill adds it because the live setup needed Hermes to be told explicitly to use `delegate_task`
for longer independent workstreams, route coding work through Codex/Claude Code-style harnesses,
launch Codex with the required sandbox mode, and keep quick tasks inline.

The helper appends this idempotent defaults block to `~/.hermes/SOUL.md`, or upgrades an older
skill-added block if it is missing the current coding-harness/Codex sandbox rules. Do not
overwrite the user's full persona; add or replace only the marked block:

```markdown
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

**Launch Codex with full workspace access.** When using Codex CLI as the coding harness on this
server, run it with `--sandbox danger-full-access` by default, for example:
`codex exec --sandbox danger-full-access "<focused task>"`. The Oracle/Tailscale server is the
outer trust boundary for this setup; Codex's stricter default sandbox can prevent the coding
harness from reading files, installing dependencies, running tests, or editing the repo it was
asked to handle. Keep safety by running Codex from the target repo/workspace, giving it a focused
task, and reviewing diffs/tests before any push, deploy, or external action. Do not use
`--dangerously-bypass-approvals-and-sandbox` unless the user explicitly asks and understands the
risk.

Whenever you install or enable a new capability, record exact commands, paths, usage notes,
verification, and cleanup in the workspace notes so future sessions do not rediscover the setup.
<!-- END FREE-ORACLE-AGENT-HERMES-DEFAULTS -->
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
hermes config set model.base_url https://opencode.ai/zen/v1
hermes config set model.api_mode openai_chat
```

Use `references/opencode-zen.md` to fetch the live catalog, choose the latest working free Mimo
model, and fall back to the latest working free DeepSeek model only if no free Mimo works. Then
persist the tested recommendation:

```bash
hermes config set model.default "$RECOMMENDED_OPENCODE_ZEN_MODEL"
hermes -z "Reply exactly: PONG" --provider opencode-zen --model "$RECOMMENDED_OPENCODE_ZEN_MODEL"
```

Known lesson from a real Oracle A1 install: Mimo worked well as the Hermes default. DeepSeek was
available in the catalog, but one non-free DeepSeek ID did not produce a final response there.
Treat all model IDs as point-in-time examples and test live.

Fallback example, after selecting a second tested free model or a tested OpenAI OAuth model:

```bash
hermes config set fallback_models '["<tested-fallback-model-id>"]'
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
default. Instead, make the `SOUL.md` operating defaults above part of every Hermes install. For
coding tasks, the skill-added default is stronger: Hermes should coordinate and delegate substantial
codebase work to Codex CLI, Claude Code, or the user's equivalent coding harness whenever available.
When the harness is Codex CLI, use `codex exec --sandbox danger-full-access ...` unless the user has
configured an equivalent wrapper.

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
