# OpenClaw Guide

Use this guide after the Oracle/Tailscale foundation is complete.

## Install Gateway

Run the bundled installer helper from the operator machine:

```bash
SSH_TARGET=ubuntu@openclaw ./scripts/install-openclaw-gateway.sh
```

It installs OpenClaw, binds the gateway to loopback, enables token auth, configures Tailscale
Serve mode, installs the user systemd service, and adds a self-healing systemd drop-in:

```ini
[Service]
Restart=on-failure
RestartSec=10
```

Manual equivalent on the server:

```bash
curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard
openclaw setup --non-interactive --accept-risk --mode local --workspace "$HOME/.openclaw/workspace" --skip-health || true
openclaw config set gateway.bind loopback
openclaw config set gateway.auth.mode token
openclaw doctor --generate-gateway-token --non-interactive --yes
openclaw config set gateway.tailscale.mode serve
openclaw config set gateway.trustedProxies '["127.0.0.1"]'
openclaw config validate
openclaw gateway install --force
openclaw gateway start
sudo tailscale set --operator="$(id -un)"
```

Verify:

```bash
openclaw --version
openclaw gateway health
systemctl --user is-active openclaw-gateway.service
curl http://127.0.0.1:18789
tailscale serve status
```

## Dashboard Token

`openclaw config get gateway.auth.token` returns the redaction sentinel
`__OPENCLAW_REDACTED__`, not the real token. Have the human retrieve the token from their own
terminal:

```bash
ssh ubuntu@openclaw "jq -r '.gateway.auth.token' /home/ubuntu/.openclaw/openclaw.json"
```

Paste it into the dashboard token field only. If the field contains `__OPENCLAW_REDACTED__`, it is
the wrong value.

## Models

Always ask which model should be default, then test it. Do not trust auto-selected defaults.

OpenAI OAuth:

```bash
openclaw models auth login --provider openai
```

For OpenAI/ChatGPT OAuth, use `references/openai-codex.md` to select the latest working mini model
exposed to the user's account. Mini is the recommended default for speed/cost; do not hardcode
`gpt-5.5` or another flagship model unless the user explicitly wants it and the test passes.

API key/provider:

```bash
openclaw models auth paste-api-key --provider <id>
```

OpenCode Zen custom provider:

```bash
curl -fsSL https://opencode.ai/zen/v1/models | jq -r '.data[].id' | grep -Ei '(-free$|^big-pickle$)'
```

Before enabling OpenCode Zen free models, read `references/opencode-zen.md` and warn the user that
free/trial Zen models may retain prompts/outputs or use them to improve/train models. For sensitive
work, recommend OpenAI/ChatGPT OAuth or another route with suitable data controls instead.

Use `references/opencode-zen.md` to fetch the live catalog, choose the latest working free Mimo
model, register the free candidates in the OpenClaw custom provider, and fall back to the latest
working free DeepSeek model only if no free Mimo works. Catalog presence does not mean the model
actually works for the account.

Test every model:

```bash
openclaw infer model run --model <provider/model> --prompt 'Reply exactly: PONG'
```

Set allowlist and default:

```bash
openclaw config set agents.defaults.models \
  '{"opencodezen/'"$RECOMMENDED_OPENCODE_ZEN_MODEL"'":{}}' \
  --strict-json --replace
openclaw models set "opencodezen/$RECOMMENDED_OPENCODE_ZEN_MODEL"
openclaw gateway restart
```

If OpenAI OAuth is also configured and the user accepts it as a fallback, first select/test
`RECOMMENDED_OPENAI_MODEL` with `references/openai-codex.md`, then add it:

```bash
openclaw config set agents.defaults.models \
  '{"opencodezen/'"$RECOMMENDED_OPENCODE_ZEN_MODEL"'":{},"openai/'"$RECOMMENDED_OPENAI_MODEL"'":{}}' \
  --strict-json --replace
openclaw models fallbacks add "openai/$RECOMMENDED_OPENAI_MODEL"
openclaw gateway restart
```

The dashboard model picker shows the allowlist (`agents.defaults.models`), not everything the
provider can theoretically expose.

## Telegram

Human-only:

- Create a bot with `@BotFather`.
- Get the owner's numeric Telegram ID.
- Enter the bot token from their own terminal.

Agent:

```bash
openclaw channels add --channel telegram --token '<entered-by-human>'
openclaw config set channels.telegram.dmPolicy pairing
openclaw config set channels.telegram.allowFrom '["tg:<id>"]' --strict-json --replace
openclaw config set commands.ownerAllowFrom '["telegram:<id>"]' --strict-json --replace
openclaw gateway restart
openclaw channels status --probe
```

Right after restart, Telegram can show disconnected for 15-20 seconds while polling settles.

## Slack

Install plugin:

```bash
openclaw plugins install @openclaw/slack
openclaw gateway restart
```

Slack runs over Socket Mode. The human creates the Slack app from a JSON manifest, gets:

- `xapp-...` app-level token with `connections:write`;
- `xoxb-...` bot token;
- optionally `xoxp-...` user token for workspace search (`search:read`);
- their Slack member ID (`U...`, not secret).

Manifest gotchas:

- `display_information.description` is required.
- `app_home.messages_tab_enabled: true` is required for DMs.
- Keep Slack's "Agent or Assistant" toggle off for the classic Messages tab.
- Bots cannot join Slack group DMs. Use private channels for "me + colleague + assistant".
- Keep events to `message.im` and `app_mention` unless you intentionally want passive channel ingestion.

Enter tokens from the human's terminal:

```bash
openclaw channels add --channel slack
openclaw config set channels.slack.userToken '<xoxp-entered-by-human>'   # optional search token
```

Owner-lock:

```bash
openclaw config set channels.slack.dmPolicy allowlist
openclaw config set channels.slack.allowFrom '["slack:<U...>"]' --strict-json --replace
openclaw config set commands.ownerAllowFrom '["telegram:<id>","slack:<U...>"]' --strict-json --replace
openclaw config set channels.slack.groupPolicy allowlist
openclaw gateway restart
openclaw channels status --probe
openclaw channels capabilities --channel slack
```

Do not paste Slack tokens into chat. If one is pasted, rotate it.

## Media Attachments

Screenshots/files are sent with a bare `MEDIA:<path>` directive on its own line.

Correct:

```text
MEDIA:./screenshots/shot.png
```

Wrong:

```text
**MEDIA:./screenshots/shot.png**
- MEDIA:./screenshots/shot.png
`MEDIA:./screenshots/shot.png`
```

Markdown wrapping breaks attachment detection and leaks the path as text. Use workspace paths,
not `/tmp`. Captions go on separate lines. Use `#doc` to force file/document delivery:

```text
MEDIA:./report.pdf#doc
```

## Voice Transcription

Best route: tell the user to ask OpenClaw from chat:

> "Set up voice transcription so you can understand voice notes I send you."

OpenClaw can install its own dependencies. A pragmatic observed setup is a `faster-whisper` venv
with a wrapper such as `transcribe.sh <audio> [model]`. Ask it to save the method in
`AGENTS.md` or `TOOLS.md` so it reuses the wrapper later. Use `base` or `small` for better
accuracy than `tiny`.

## Finish Line

Tell the user explicitly that OpenClaw can now extend itself:

> "Ask it to install Codex CLI, Claude Code, GitHub CLI, Playwright, ffmpeg, transcription, or
> another MCP/channel. Keep destructive actions approval-gated."
