---
name: openclaw-oracle-setup
description: Set up a secure OpenClaw Gateway server on Oracle Cloud Always Free / PAYG A1 ARM infrastructure with Tailscale-only access, PAYG guardrails, OCI CLI provisioning, Ubuntu bootstrap, OpenClaw install, gateway verification, model-provider setup (OpenAI OAuth + OpenCode Zen/custom OpenAI-compatible, free-model selection and testing), Telegram and Slack channel setup (Slack: DMs, public/private channels, native Slack tool actions + search), optional voice-note transcription (faster-whisper), a finish-line hand-off (have OpenClaw extend itself — install Codex/Claude Code/etc. on request), and troubleshooting. Use when a user wants to create or replicate an OpenClaw server on Oracle Cloud, fix OCI A1 capacity/provisioning issues, configure Tailscale SSH/Serve, connect model providers, set up a Telegram or Slack bot, enable voice-note transcription, hand off so the owner can have OpenClaw self-install more tooling, or document a repeatable OpenClaw VPS setup for another person.
---

# OpenClaw Oracle Setup

## How to Use This Skill (Audience & Approach)

The person you're helping ranges from senior engineer to "barely knows what AI is." Your job
is to make a genuinely complex setup feel effortless and to avoid the obstacles documented
here. Regardless of their level:

- **Do the work yourself.** Drive every step you can via the OCI CLI, SSH, and the OpenClaw
  CLI. Only hand the user a command when it is a step only they can do (see Human Handoffs).
- **Explain in plain language.** Briefly say what each step does and why before doing it.
  Define any unavoidable jargon in one line. Never paste raw stack traces at the user.
- **One clear ask at a time.** For human-only steps, give exact click-by-click instructions
  (menu path, button name, the precise URL), then pause and wait for confirmation.
- **Set expectations up front:** ~1–2 hours, mostly hands-off; a likely Oracle capacity wait;
  a temporary ~$100 (local-equivalent) card hold if they go PAYG; a few browser approvals.
- **Verify and report each milestone** in plain terms ("your server is reachable and locked
  down to your private network — the public internet can't see it").
- **Protect secrets.** Never let the user paste API keys/tokens into the chat — they go in the
  user's own terminal/browser. Your tool output redacts secrets anyway, so you cannot relay them.
- **Fix, don't dump.** Diagnose and resolve errors yourself, then summarize what happened.

## Operating Rules

- Treat billing, IAM, quotas, public network exposure, and credential handling as high-risk.
- Do not create paid OCI resources until guardrails are in place and the user explicitly asks to proceed.
- Never paste or store OCI private keys, OpenClaw gateway tokens, API keys, or payment details in project files.
- Prefer OCI CLI for repeatability, but use the Oracle Console for PAYG upgrade, payment verification, Tailscale approvals, and other browser-only steps.
- Keep OpenClaw Gateway bound to loopback. Expose it through Tailscale Serve or an SSH tunnel, not public HTTP.
- After Tailscale SSH is verified, remove public TCP 22 from OCI ingress and leave only UDP 41641 for Tailscale.
- **Finish setup by baking the documentation rule into the agent's workspace.** After the gateway
  is live and a channel is connected, add the following directive to the agent's `AGENTS.md` and/or
  `TOOLS.md` so every new capability is permanently recorded from day one:
  > *"Whenever you install, configure, or enable a new capability (transcription, MCP servers, dev
  > tools, channel integrations, etc.), write a permanent record in `TOOLS.md` and/or `AGENTS.md`
  > with the exact setup commands, paths, and usage notes. Do not leave it undocumented or in an
  > ephemeral location. Verify the capability works end-to-end after documenting, and clean up any
  > temporary or duplicate setups."*
  This is the single most important fix for reliability — without it, a future restart session
  will have no memory of how capabilities were set up and will waste time rebuilding them.

## Human Handoffs (only the human can do these)

Everything else is yours to automate. These need the user's browser/account/approval —
delegate each with exact instructions, then wait. If one stalls, keep the rest moving and
clearly restate the single pending action.

1. **Create the Oracle Cloud account** (signup + identity/payment verification).
2. **Upgrade to Pay As You Go** when free-tier A1 capacity is unavailable (the common case).
   Warn first: Oracle places a temporary ~$100 USD (local-equivalent) card authorization;
   staying within Always Free limits keeps real spend at €0. Only after guardrails are set.
3. **Tailscale:** create/sign in to Tailscale; approve the server device; approve Tailscale
   Serve (one-time URL); re-approve SSH if prompted.
4. **Model auth:** approve the OpenAI/Codex OAuth in the browser, and/or paste API keys — in
   the user's OWN terminal, never in chat.

## Workflow

1. Read the project notes first if present: `PROJECT.md`, `AGENTS.md`, `docs/`, `ops/`.
2. Audit current state before changes:
   - OCI auth profile, tenancy, subscribed region, compartments, quota policies, budgets.
   - Existing compute instances, block volumes, VCNs, subnets, route tables, and security lists.
   - Local SSH key availability and Tailscale account readiness.
3. Establish PAYG guardrails before launching compute:
   - Dedicated compartment such as `openclaw-free-only`.
   - Small tenancy-wide warning budget.
   - Quota policy that restricts compute to `Standard.A1`, caps A1 memory/cores and block storage, and blocks paid adjacent services.
   - Script-level checks that refuse root-compartment launches and paid shapes.
   - See `references/oracle-guardrails.md`.
4. Provision an Ubuntu 24.04 ARM VM:
   - Shape: `VM.Standard.A1.Flex`.
   - Conservative start: `2 OCPU / 12 GB RAM / 100 GB boot volume`.
   - Network initially allows TCP 22 and UDP 41641 only.
   - Inject the user's public SSH key only.
   - EXPECT capacity friction: free-tier A1 very often returns `Out of host capacity`. Retry
     across availability domains, fault domains, and smaller sizes; run a persistent retry
     watcher; PAYG improves odds. See `references/runbook.md` → Capacity Handling. This is the
     single biggest blocker — tell the user early so a wait doesn't feel like a failure.
5. Bootstrap the server:
   - Use `scripts/bootstrap-openclaw-server.sh` after SSH works.
   - Approve the Tailscale auth URL when prompted.
   - Verify `ssh ubuntu@openclaw` or the chosen Tailscale hostname from the client machine.
6. Lock down OCI network:
   - Remove TCP 22 from the OCI security list.
   - Verify public SSH to the public IP fails.
   - Verify Tailscale SSH still works.
7. Install and configure OpenClaw:
   - Use `scripts/install-openclaw-gateway.sh`.
   - Configure gateway bind `loopback`, auth mode `token`, Tailscale mode `serve`, and trusted proxy `["127.0.0.1"]`.
   - Install/start the user systemd gateway service. Add a systemd drop-in with
     `Restart=on-failure` / `RestartSec=10` so it self-heals — without it, a restart whose
     task-drain times out gets SIGKILLed and the service stays `failed` for hours (all channels
     go silent). The bundled `install-openclaw-gateway.sh` does this automatically.
   - Enable Tailscale Serve for HTTPS dashboard access (see "Tailscale Serve" below). It needs BOTH Serve enabled on the tailnet (admin approval URL) AND `sudo tailscale set --operator=<gateway-user>` so the gateway — which runs as a non-root user — can manage Serve. Without the operator it silently logs `serve failed` and access stays loopback-only.
8. Verify:
   - `openclaw --version`
   - `openclaw gateway status`
   - `openclaw gateway health`
   - `systemctl --user is-active openclaw-gateway.service`
   - `curl http://127.0.0.1:18789`
   - `tailscale serve status` shows `https://<host>.<tailnet>.ts.net` → `127.0.0.1:18789`
   - From a tailnet device: `curl -I https://<host>.<tailnet>.ts.net/` returns `200`
9. Document final state:
   - Region, compartment, instance shape, public IP, Tailscale IP, SSH command, VCN/security-list IDs.
   - Guardrails, verification commands, and pending manual approvals. (Do NOT hand-install
     worker tooling here — that is done later by asking OpenClaw itself; see "Finish Line".)
10. Connect model providers (see "Connecting Model Providers"):
   - Authenticate OpenAI via OAuth (uses the user's subscription), and/or add a custom provider
     such as OpenCode Zen — free models only, fetched live at setup time.
   - Set a model allowlist (`agents.defaults.models`) restricted to models that actually work.
   - ASK the user which model should be the default (don't accept OpenClaw's arbitrary auto-pick),
     set it with `openclaw models set <id>`, and TEST it generates (`openclaw infer model run
     --model <id> --prompt 'Reply: PONG'`) — a broken default makes every chat fail. Add and test
     a fallback (`openclaw models fallbacks add <id>`).
11. Optionally connect a phone channel (see "Connect a Phone Channel (Telegram)") — usually the
    user's real goal.
12. Optionally enable voice-note transcription (see "Voice Transcription"). The easiest, most
    future-proof route is to TELL the user they can just ASK OpenClaw, in chat, to set it up —
    it self-installs the dependency (faster-whisper). A non-technical user won't know this is
    possible, so proactively offer it.
13. Optionally connect Slack (see "Connect Slack"). It is a first-class but **multi-user** channel
    (DMs, public/private channels, native Slack tool actions + search). Lock WHO can
    drive it to the owner, and watch the Slack-app manifest gotchas documented in that section.
14. Wrap up — hand off the superpower (see "Finish Line"). Setup is DONE once the gateway, a tested
    default model (+ fallback), and one owner-locked channel are live. Then explicitly tell the user
    OpenClaw can extend ITSELF: they just ASK it, from their phone, to install further tooling —
    Codex CLI, Claude Code, `gh`, Playwright, more channels — instead of you hand-installing it.

## Script Usage

Copy scripts from this skill to the target project before running them, then review the variables at the top.

Base server + Tailscale bootstrap:

```bash
SSH_TARGET=ubuntu@PUBLIC_IP \
TAILSCALE_HOSTNAME=openclaw \
./scripts/bootstrap-openclaw-server.sh
```

OpenClaw Gateway install/configure after Tailscale SSH works:

```bash
SSH_TARGET=ubuntu@openclaw \
./scripts/install-openclaw-gateway.sh
```

## Tailscale Serve (HTTPS dashboard access)

Serve exposes the loopback gateway as **tailnet-only HTTPS** (not public Funnel) at
`https://<hostname>.<tailnet>.ts.net/`, reachable from any tailnet device including a phone.
With `gateway.tailscale.mode = serve` the gateway manages Serve itself — but two
prerequisites must hold, or it silently logs `serve failed` and access stays loopback-only:

1. **Serve enabled on the tailnet.** The first `tailscale serve` attempt prints an approval
   URL (`https://login.tailscale.com/f/serve?node=...`); the tailnet admin approves it once
   (this also enables HTTPS certs — MagicDNS must be on).
2. **Operator set to the gateway user.** The gateway runs as a non-root user (e.g. `ubuntu`),
   and `tailscale serve` requires root or operator rights:

   ```bash
   ssh ubuntu@openclaw 'sudo tailscale set --operator=$(id -un)'
   ```

Restart the gateway, then verify:

```bash
ssh ubuntu@openclaw 'systemctl --user restart openclaw-gateway.service; tailscale serve status'
# expect: https://<host>.<tailnet>.ts.net (tailnet only) -> proxy http://127.0.0.1:18789
ssh ubuntu@openclaw 'journalctl --user -u openclaw-gateway.service -n 50 | grep -i serve'
# expect a "serve enabled" line, not "serve failed"
```

Fallback if Serve is unavailable — a loopback SSH tunnel:

```bash
ssh -L 18789:127.0.0.1:18789 ubuntu@openclaw   # leave open; browse http://127.0.0.1:18789/
```

## Authenticating to the Dashboard

With the default `gateway.auth.mode = token`, each device enters the gateway token once
(remembered per browser). Serve gives clean HTTPS but does not by itself remove the token.
To drop the token, enable tailnet-identity auth (`gateway.auth.allowTailscale`, used with
Serve) — verify the exact key and behavior against the OpenClaw auth docs before changing
an auth setting.

CRITICAL — retrieving the gateway token:

- `openclaw config get gateway.auth.token` returns the redaction sentinel
  `__OPENCLAW_REDACTED__` (exactly 21 chars), NOT the token. OpenClaw redacts secrets at
  the API layer by design, so a `#token=` URL built from `config get` is always rejected
  ("Auth did not match"). This is the single most common setup trap.
- Read the real value (~48 chars) straight from the config file instead:

```bash
# Run from the operator's OWN terminal: an AI agent's tool sandbox also redacts secrets
# in transit, so an agent cannot fetch a usable token for you — the human must do this.
ssh ubuntu@openclaw "jq -r '.gateway.auth.token' /home/ubuntu/.openclaw/openclaw.json"
# macOS: append  | tr -d '\n' | pbcopy  to copy to the clipboard instead of printing.
```

Paste it into the dashboard **Gateway Token** field (auth mode `token`; leave Password
empty — never fill both). If the field ever shows `__OPENCLAW_REDACTED__`, you copied the
sentinel, not the token.

If the dashboard shows a **doubled URL** (e.g. `wss://<host>/https:/<host>`) or broken `?`
images, the browser address bar — or the stored gateway URL — got doubled, and the Control
UI persisted it. This is a client-side/browser issue, not a server one. Fix: correct the
address bar to the clean origin `https://<host>.<tailnet>.ts.net/`, reset the WebSocket URL
field to `wss://<host>.<tailnet>.ts.net`, click Connect; if it persists, clear the site's
browser storage (the bad value is cached there). Bookmark the clean URL to avoid recurrence.

## Connecting Model Providers

Model credentials live in each agent's `~/.openclaw/agents/<agent>/agent/openclaw-agent.sqlite`
— NOT in `openclaw.json` or `auth-profiles.json`, so a missing `auth-profiles.json` does not
mean "no creds". Check state with `openclaw models status` (look for `status=usable` vs
`missing`) and `openclaw models auth list`. A model can be the default yet unauthenticated.

Secrets must originate from the human: OAuth needs a browser approval, and API keys are
secrets that an AI agent's tool sandbox redacts in transit. Run these from the operator's
own terminal.

- **OAuth** (reuses a ChatGPT/Codex subscription, no key to handle):
  ```bash
  openclaw models auth login --provider openai   # prints a device/URL flow to approve
  ```
- **API key for a built-in provider:**
  ```bash
  openclaw models auth paste-api-key --provider <id>   # stored in the agent auth store
  ```
- **Custom OpenAI-compatible provider** (OpenCode Zen, DeepSeek, OpenRouter, etc.): define it
  under `models.providers.<id>` with `baseUrl`, `api: "openai-completions"`, and an
  env-substituted key (never inline the raw key in the JSON):
  ```bash
  openclaw config set models.providers.<id> \
    '{"baseUrl":"https://host/v1","api":"openai-completions","apiKey":"${MYKEY_ENV}","models":[{"id":"<model-id>","name":"<label>"}]}' \
    --strict-json --merge
  # operator supplies the key (their terminal), e.g.:  openclaw config set env.MYKEY_ENV '<key>'
  openclaw models set <id>/<model-id>
  ```
  Reference models as `<provider-id>/<model-id>`. Restart the gateway, then re-check
  `openclaw models status`.

**The dashboard/agent picker shows ONLY the allowlist.** What appears in the Control UI model
dropdown is exactly `agents.defaults.models` (the "Configured models" line in `models status`) —
NOT everything a provider could offer. If a user says "I only see one OpenAI model in the
dashboard," that's the allowlist, not their subscription; add ids to `agents.defaults.models` to
surface more (the gateway must restart; refresh the dashboard). Also, an OpenAI **OAuth (ChatGPT
subscription)** only exposes a LIMITED set that actually runs — in practice the current GPT-5.x
chat models (e.g. `gpt-5.5`, `gpt-5.4`, `gpt-5.4-mini`). The `o`-series and `*-pro` variants appear
in `openclaw models list --available --provider openai` but are NOT callable via the sub (they
return `Unknown model` or HTTP 400); those need a metered platform **API key** (`sk-…`). So list
`--available`, confirm each with `openclaw infer model run --model openai/<id> --prompt 'Reply:
PONG'`, and allowlist only the ones that generate.

**Choosing the default model — ask, then test.** Do NOT accept OpenClaw's auto-picked default;
it grabs an arbitrary configured model (we saw it pick a *disabled* free model, which made every
chat fail with "Something went wrong"). Always:

1. ASK the user which model they want as the default.
2. Set it explicitly: `openclaw models set <provider/model>`.
3. TEST it actually generates before handing off:
   `openclaw infer model run --model <provider/model> --prompt 'Reply: PONG'`.
4. Add a reliable fallback so a flaky/disabled default never dead-ends a chat. An
   authenticated `openai/*` model is ideal — it is not subject to free-tier disabling:
   `openclaw models fallbacks add <provider/model>` (confirm with `openclaw models fallbacks
   list`; `openclaw models status` then shows `Fallbacks (1): …`). TEST the fallback generates
   too (`openclaw infer model run --model <provider/model> --prompt 'Reply: PONG'`) — an
   unusable fallback is no fallback. Restart the gateway after changing the default or fallbacks.

### OpenCode Zen — register ONLY free models

NEVER hardcode the free-model list — Zen's catalog and pricing change over time. At setup
time, FETCH the current catalog and keep only the $0 models. As of this writing the free ids
follow a `-free` suffix convention (plus `big-pickle`), but treat that as a heuristic and
confirm $0 pricing, because the convention and catalog can change:

```bash
# discover candidate free ids from the LIVE catalog (do this at setup time, not from memory)
curl -s https://opencode.ai/zen/v1/models | jq -r '.data[].id' | grep -E '\-free$|^big-pickle$'
# then confirm each is actually $0 on the current pricing page: https://opencode.ai/docs/zen/
```

Register only the confirmed-free ids in `models.providers.opencodezen.models`. Any specific
model ids written in this skill (e.g. `deepseek-v4-flash-free`) are point-in-time EXAMPLES,
not an authoritative list — always re-derive the real ids from the fetch above.

CRITICAL: catalog presence ≠ usable. Some Zen models are `disabled` (HTTP `401 Model is
disabled`) for a given account/plan. After registering, TEST each one actually generates and
keep only those that do — a disabled default makes every chat fail with "Something went wrong":

```bash
openclaw infer model run --model opencodezen/<id> --prompt 'Reply: PONG'
```

Register/allowlist only models that return output. Consider a reliable fallback (e.g. an
authenticated `openai/*` model) so a flaky/disabled free model never dead-ends a chat.

GOTCHA: supplying the key as the env var `OPENCODE_ZEN_API_KEY` also auto-activates
OpenClaw's **built-in `opencode` / `opencode-go` providers**, which expose Zen's FULL paid
catalog regardless of your custom provider. There is no per-provider disable flag; the reliable fix is a model allowlist — set
`agents.defaults.models` to exactly the free ids you want usable, which restricts the
picker/agent and hides everything else (built-in paid models stay in the raw catalog but
become non-selectable):

```bash
# ids below are EXAMPLES — substitute the free ids you fetched above + the model(s) you want
openclaw config set agents.defaults.models '{"opencodezen/deepseek-v4-flash-free":{},"openai/gpt-5.5":{}}' --strict-json --replace
```

Verify with `openclaw models status` — `Configured models` should equal your allowlist.

## Connect a Phone Channel (Telegram)

Usually the user's real goal: command the assistant from their phone, anywhere, with NO
VPN/Tailscale (the gateway polls Telegram outbound; only the admin dashboard stays
tailnet-private). Confirm the default model works FIRST — a disabled/broken default makes the
bot reply "Something went wrong" even when the channel itself is fine.

Human steps (only they can do these):
- Create a bot: message **@BotFather** → `/newbot` → a name, then a username ending in `bot`
  → it returns a **bot token** (a secret).
- Get their numeric Telegram id (e.g. message **@userinfobot**) — not a secret; you need it to
  lock the bot to them.

You do:
- Add the token from the USER's own terminal (it's a secret, redacted in transit for an agent):
  `openclaw channels add --channel telegram --token <token>`.
- LOCK it to the owner (a stranger must not drive an assistant that has server/model access):
  `channels.telegram.dmPolicy=pairing`, `channels.telegram.allowFrom=["tg:<id>"]`,
  `commands.ownerAllowFrom=["telegram:<id>"]`.
- Restart, then verify `openclaw channels status --probe` shows `connected`. Right after a
  restart it shows `disconnected` for ~15–20s while polling reconnects — recheck, don't panic.
- Have the user message the bot to confirm an end-to-end reply.

## Connect Slack (optional — DMs, channels, Slack actions)

Slack is a first-class channel via a plugin, but unlike Telegram it is **multi-user** — a whole
workspace can see and try to use it, so locking down WHO can drive it is mandatory. It runs over
**Socket Mode** (a WebSocket, no public URL), which fits the loopback/Tailscale-private model.

**1. Install the plugin (agent, non-interactive):**

```bash
openclaw plugins install @openclaw/slack
openclaw gateway restart   # required to load the plugin
```

GOTCHA: `openclaw channels capabilities --channel slack` tries to install the plugin via an
interactive prompt that loops forever without a TTY — use `plugins install` instead.

**2. Human creates the Slack app from a manifest** (only they can; needs a workspace where they
can add apps — a company-managed workspace may need admin approval):

- api.slack.com/apps → **Create New App → From a manifest** → **JSON** → paste → Create.
- **Basic Information → App-Level Tokens** → generate one with `connections:write` → `xapp-…`.
- **Install to Workspace** → copy the **Bot User OAuth Token** `xoxb-…`.
- Get their **member ID** (`U…`; profile → ⋮ → Copy member ID) — not a secret; needed for the lock.

The manifest below grants the FULL set (DMs, public+private channels, all Slack tool
actions, search, slash command). Trim scopes for least-privilege if the user only wants DM
control. Scope→action map: `chat:write` post/edit/delete; `channels:*`/`groups:*` read public/
private channels; `im:*` DMs; `reactions:*`; `pins:*`; `files:*`;
`users:read`/`usergroups:read`; `emoji:read`; `commands` slash commands; `app_mentions:read` tags.
Search needs the **user** scope `search:read` (yields a `xoxp-` user token).

```json
{
  "display_information": { "name": "Assistant", "description": "Personal AI assistant" },
  "features": {
    "bot_user": { "display_name": "Assistant", "always_online": true },
    "app_home": { "home_tab_enabled": false, "messages_tab_enabled": true, "messages_tab_read_only_enabled": false },
    "slash_commands": [ { "command": "/assistant", "description": "Ask the assistant", "should_escape": false } ]
  },
  "oauth_config": {
    "scopes": {
      "user": [ "search:read" ],
      "bot": [
        "app_mentions:read", "chat:write",
        "im:history", "im:read", "im:write",
        "channels:read", "channels:history",
        "groups:read", "groups:history",
        "users:read", "usergroups:read",
        "reactions:read", "reactions:write",
        "pins:read", "pins:write",
        "files:read", "files:write",
        "emoji:read", "commands"
      ]
    }
  },
  "settings": {
    "org_deploy_enabled": false,
    "socket_mode_enabled": true,
    "event_subscriptions": { "bot_events": ["message.im", "app_mention"] }
  }
}
```

Manifest GOTCHAS (each cost us a retry):
- `display_information.description` is **required** — omitting it gives "We can't translate a
  manifest with errors." Use the JSON editor (it defaults to JSON).
- `app_home.messages_tab_enabled: true` is **required** for DMs — without it, DMing the app shows
  "Sending messages to this app has been turned off." (UI equivalent: App Home → Show Tabs →
  Messages Tab on + "Allow users to send… messages".)
- Keep Slack's **"Agent or Assistant"** toggle **OFF** (don't add `assistant_view`). It replaces
  the classic Messages tab with Slack's Assistant UI, which needs `assistant:write` + assistant
  events. The classic Messages tab behaves like a normal DM thread (Telegram parity).
- Socket Mode → **no Request URL** needed; events AND slash commands ride the WebSocket.
- Keep events to `message.im`/`app_mention` only (NOT `message.channels`/`.groups`)
  so the bot reads channels **on-demand when asked**, never passively ingesting chatter.

**3. Tokens — secrets, entered from the HUMAN's terminal, NEVER pasted to the agent:**

```bash
# SSH in FIRST and wait for the prompt, THEN run (the guided flow avoids quoting/history issues):
openclaw channels add --channel slack             # prompts for the xoxb- and xapp- tokens
# search: after adding the search:read user scope + reinstalling to get the xoxp- user token:
openclaw config set channels.slack.userToken '<xoxp-…>'   # config-only; userTokenReadOnly:true = read-only
```

SECRET GOTCHAS (each bit us): an agent's tool sandbox **redacts** secrets, so it can never receive
a usable token — if a token lands in the chat, treat it as compromised and **rotate** it (simplest:
Basic Information → Delete App → recreate from the manifest). Pasting `ssh host` + the command in
one paste can swallow the command during connect — SSH in first. A missing/unmatched `'` drops you
to the `>` (PS2) continuation prompt — Ctrl+C and retry, or use the guided flow above.

**4. Lock down WHO can drive it (agent — not secret). Slack is multi-user:**

```bash
openclaw config set channels.slack.dmPolicy allowlist
openclaw config set channels.slack.allowFrom '["slack:<U…>"]' --strict-json --replace
# MERGE the slack id alongside existing owner entries (e.g. telegram) — read first, don't clobber:
openclaw config set commands.ownerAllowFrom '["telegram:<id>","slack:<U…>"]' --strict-json --replace
# channels stay silent until you allowlist one (groupPolicy defaults to allowlist):
#   channels.slack.channels.<C…>.users=["slack:<U…>"]  + requireMention
```

Broad scopes change what the bot CAN do, not WHO drives it — driving stays owner-locked. To use it
in a channel, the human `/invite`s it (a bot must be a member to receive a tag — Slack's rule),
then you allowlist that channel's `C…` id locked to the owner.

GOTCHA: you can't add a bot to a 1:1 DM, and **Slack does NOT allow bots in group DMs** (MPIMs) —
apps never appear in the "add people to this conversation" picker and there is no `/invite`
equivalent for group DMs. For "me + a colleague + assistant", use a **channel** (a private channel
feels just like a group DM). This is why the manifest omits `mpim:*` scopes / `message.mpim` — they
cannot be used to put a bot in a group DM.

**5. Restart + verify:**

```bash
openclaw gateway restart
openclaw channels status --probe          # expect Slack: connected, health:healthy, works
openclaw channels status --probe --json   # botTokenStatus/appTokenStatus/userTokenStatus: available
openclaw channels capabilities --channel slack   # shows granted bot scopes + supported actions
```

Changing scopes later = **Reinstall to Workspace**; the bot token stays the same (scopes update in
place), so usually no re-add. Enable the slash command in OpenClaw with
`channels.slack.slashCommand={"enabled":true,"name":"/assistant","ephemeral":true}`. OpenClaw
exposes Slack to the agent as a **native tool** (send/read/react/pin/files/search) — no external
"Slack MCP" server is needed.

## Sending Images & Media (the `MEDIA:` line)

When the assistant sends a file (screenshot, image, PDF) to a channel, it emits a `MEDIA:<path>`
directive **on its own line, in PLAIN TEXT**. The gateway detects that exact line and uploads the
file as an attachment.

**The #1 reason "it won't send me a screenshot/image":** the agent wrapped the directive in
markdown — `**MEDIA:…**`, backticks, or a `- ` bullet. The line then no longer matches, so
**nothing attaches and the raw path/URL shows up as literal text** in the chat (we hit this — a
screenshot send that printed the path instead). The fix is to emit it bare, on its own line:

```
MEDIA:./screenshots/shot.png
```

Other rules:
- **Path:** workspace-relative (as above), an absolute path under the workspace, or a URL
  (`MEDIA:https://…`). Avoid `/tmp` — observed to be unreliable for delivery; keep media in the
  workspace.
- **Caption:** put any caption text on a SEPARATE line from the `MEDIA:` line.
- **`#doc`:** append it to force delivery as a file/document instead of an inline image —
  `MEDIA:./report.pdf#doc`.
- Channel-agnostic — the same directive applies to Telegram, Slack, etc.

If a user reports broken images, this is almost always it: **check for a markdown-wrapped `MEDIA:`
line or a `/tmp` path.** The durable fix is to have the assistant record the rule in its own
workspace notes (`AGENTS.md`/`TOOLS.md`) — "`MEDIA:` = plain text, own line, workspace path, never
`/tmp`" — so future replies don't repeat it.

## Voice Transcription (optional — voice notes → text)

A phone-controlled assistant is far more useful if the user can send **voice notes** and have
it understand them. OpenClaw does not transcribe out of the box, but it can set this up itself.

**Best route — just ask OpenClaw (recommended, especially for non-technical users).** The
assistant can install its own dependencies on the server, so the simplest and most future-proof
setup is for the user to tell it, in plain language from the chat/Telegram, e.g.:

> "Set up voice transcription so you can understand the voice notes I send you."

A normal person won't know this is even possible — so proactively TELL them and hand them that
sentence. In practice OpenClaw provisions **`faster-whisper`** (CTranslate2): no API key, no
system packages, runs on CPU/ARM, audio never leaves the box, and it auto-downloads a small
model. (A real run produced a `~/whisper-env` venv + a `transcribe.sh <audio> [model]` wrapper
+ the `faster-whisper-tiny` model — the agent chose this over the bundled skill on its own.)

Make it reliable and more accurate:
- With the documentation rule in Operating Rules (above), the agent will now **automatically record
  how it transcribes** in its `TOOLS.md` — verified path, model, and wrapper — and reuse it on
  every voice note instead of rebuilding ad hoc.
- The default `tiny` model is fast but rough. For better accuracy ask it to use **`base`** or
  **`small`** (tiers: `tiny → base → small → medium → large-v3`, trading speed/RAM for accuracy).
- A venv install is persistent (survives reboot); the bundled skill's brew path is not.

Bundled alternatives (inspect with `openclaw skills list` / `info <id>` / `check`):
- `openai-whisper` — local Whisper CLI, but expects the `whisper` binary via **brew**, which is
  awkward on a headless Ubuntu ARM server (this is exactly why "just ask it" → faster-whisper is
  cleaner here).
- `openai-whisper-api` — transcribe via the OpenAI API: no local compute, but needs an API key
  and **sends the user's audio to OpenAI**. Most bundled skills ship **disabled**; enable per skill.

**Verify:** have the user send the bot a voice note and confirm it replies with the transcript.
Confirm the default model works first (see the Telegram section) — transcription feeds text to
the model, so a broken default still yields "Something went wrong".

NOTE: this "just ask OpenClaw to install it" pattern generalizes far beyond transcription — it is
the core hand-off described in **Finish Line** below. Offer it to users instead of hand-running
install commands yourself.

## Finish Line — Hand the User OpenClaw's Superpower

Setup is **complete** once three things hold: the gateway is healthy behind Tailscale, a default
model is set and tested (with a fallback), and at least one channel (Telegram/Slack) is connected
and owner-locked. Stop hand-installing things there — the rest is done better another way.

The most valuable thing to leave the user with: **OpenClaw can extend itself.** Once it runs with a
capable model and shell access to its own box, the user can just *ask it*, in plain language from
their phone, to install and wire up new tools — no SSH, no CLI, no you. Most people (even engineers)
don't realize this, so **say it explicitly and give examples.**

Things the user can simply ask the assistant to do:
- **Dev tooling:** "install the Codex CLI and use it for coding tasks", "install Claude Code",
  "install the GitHub CLI and help me triage issues", "set up Node / pnpm / Docker".
- **New abilities:** "set up voice transcription" (faster-whisper, above), "install Playwright so
  you can browse and test websites", "install ffmpeg for audio/video".
- **More wiring:** "connect another channel", "add an MCP server for <service>", "enable the
  `<name>` skill" (`openclaw skills list` shows what's bundled).
- **Self-documenting (automatic):** The documentation rule (added to the agent's workspace as
  part of this setup sequence) means the agent will record every new capability in its `TOOLS.md`
  automatically — no need to specifically ask.

A good closing hand-off to the user sounds like:

> "You're live. From here you don't need me or the terminal — just message the assistant. Try
> *'install the Codex CLI and use it for coding'*, or *'set up voice transcription'*. It installs
> its own tools on the server. Start small, and keep anything destructive approval-gated."

**Safety reminder to pass on:** the assistant has real shell access to the server and spends the
user's model budget, so keep external or irreversible actions (pushing code, deploying, deleting,
emailing, posting publicly) **approval-gated** until each workflow has proven itself. Capability is
not the same as unattended trust.

## Updates & Recovery

- An OpenClaw update restarts the gateway, so the dashboard drops for ~30–60s. Wait and
  reload — the token survives the update; do not re-fetch it.
- Updates write a `~/.openclaw/openclaw.json.pre-update` backup. There is a known bug
  class where `update` / `doctor --fix` / `configure` can rewrite the config and drop
  `gateway.auth` or replace real secrets with `__OPENCLAW_REDACTED__`. After any update,
  verify integrity (no secret printed):

```bash
ssh ubuntu@openclaw 'jq "{mode: .gateway.auth.mode, isMask: (.gateway.auth.token == \"__OPENCLAW_REDACTED__\"), len: (.gateway.auth.token | tostring | length)}" ~/.openclaw/openclaw.json'
```

  Expect `mode: "token"`, `isMask: false`, `len` ~48. If auth was dropped or masked,
  restore from `openclaw.json.pre-update` (or `openclaw.json.last-good`) and restart the
  user service: `systemctl --user restart openclaw-gateway.service`.

## References

- Read `references/oracle-guardrails.md` before PAYG or quota work.
- Read `references/runbook.md` for the full end-to-end sequence and common failure handling.
- Use official Oracle/OpenClaw/Tailscale docs for current command syntax when a CLI error suggests drift.
