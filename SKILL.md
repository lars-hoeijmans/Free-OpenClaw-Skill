---
name: openclaw-oracle-setup
description: Set up a free, private, phone-controlled self-hosted AI agent on Oracle Cloud Always Free ARM infrastructure, with the user choosing OpenClaw, Hermes Agent, or both. Covers Oracle PAYG guardrails, A1 provisioning/capacity handling, Tailscale-only access, OpenClaw Gateway setup, Hermes setup, model providers (OpenCode Zen free models plus optional OpenAI/ChatGPT OAuth), Telegram/Slack channels, migration both ways, and final hand-off so the assistant can extend itself.
---

# Free Oracle Agent Setup

Use this skill when a user wants a self-hosted assistant they can command from their phone,
running on Oracle Always Free A1 infrastructure, with either **OpenClaw**, **Hermes Agent**, or
both installed safely.

The goal is not just "install a package." The goal is a working, private, owner-locked assistant
with tested models, clear cost guardrails, and a clean hand-off.

## Interaction Rule: Use Choice Questions

Make the setup feel like a guided installer. At every major branch, use the agent platform's
question/choice tool so the user can click/select instead of typing.

If a question tool is unavailable, ask one concise question with numbered options and a
recommended default. Do not dump a checklist and ask the user to figure it out.

Recommended choice prompts:

1. **Agent stack:** `Hermes (Recommended)`, `OpenClaw`, or `Both`.
2. **Oracle path:** `Create new server`, `Use existing server`, or `Audit only`.
3. **VM size:** `2 OCPU / 12 GB`, `4 OCPU / 23 GB`, or `4 OCPU / 24 GB`.
4. **Model setup:** `OpenCode Zen free only`, `OpenCode Zen + ChatGPT OAuth`, or `Bring API key`.
5. **Channels:** `Telegram`, `Slack`, `Both`, or `Skip for now`.
6. **Migration:** `Fresh install`, `Migrate OpenClaw -> Hermes`, `Migrate Hermes -> OpenClaw`, or `Side-by-side only`.

Ask only the question needed for the next step. Explain the tradeoff in one sentence.

## Working Style

- Explore -> Plan -> Implement -> Verify.
- Do the work yourself via OCI CLI, SSH, and the agent CLI whenever possible.
- Only hand work to the user when it requires their account, browser approval, payment screen,
  token entry, or phone app.
- Never ask the user to paste secrets into chat. Tokens and API keys go into their own terminal
  or browser only.
- Use official docs for current CLI syntax when commands drift.
- Keep irreversible or external actions approval-gated.
- Finish setup by baking a documentation rule into the live assistant's workspace. Add a short
  directive to its `AGENTS.md`, `TOOLS.md`, `SOUL.md`, or equivalent: whenever it installs or
  enables a new capability, it must record exact commands, paths, usage notes, verification, and
  cleanup. This prevents future sessions from rediscovering the same setup.

## Human-Only Handoffs

Everything else is yours to automate.

- Oracle account signup, payment verification, and PAYG upgrade.
- Tailscale sign-in, device approval, Serve approval, and occasional Tailscale SSH approval.
- OpenAI/Codex OAuth, Claude OAuth, Nous Portal OAuth, or other browser/device-code auth.
- Creating Telegram bots or Slack apps and entering tokens in the user's own terminal.
- Choosing whether to migrate secrets between agents.

## Shared Foundation: Oracle + Tailscale

Always do the shared server layer first, before choosing or installing the agent runtime.

1. Read local context if present: `PROJECT.md`, `AGENTS.md`, `docs/`, `ops/`.
2. Audit OCI state: auth profile, tenancy, region, compartments, budgets, quotas, instances,
   volumes, VCNs, subnets, route tables, and security lists.
3. Put PAYG guardrails in place before launching compute:
   - dedicated compartment, such as `openclaw-free-only`;
   - small budget alert;
   - quota policy limiting A1 compute/memory/storage and blocking paid adjacent services;
   - script checks that refuse root-compartment launches and paid shapes.
   See `references/oracle-guardrails.md`.
4. Provision Ubuntu 24.04 ARM on `VM.Standard.A1.Flex`.
   - conservative start: `2 OCPU / 12 GB / 100 GB`;
   - preferred roomy free setup: `4 OCPU / 23 GB / 100 GB`;
   - `24 GB` is still within the A1 free pool, but `23 GB` leaves a little headroom.
5. Expect A1 capacity friction. Retry without fault domain, across fault domains, and at smaller
   shapes; use a polite watcher with an API-key OCI profile for multi-day attempts.
6. Bootstrap Ubuntu and Tailscale with `scripts/bootstrap-openclaw-server.sh`.
7. After Tailscale SSH works, remove public TCP 22 from OCI ingress. Leave only UDP 41641 for
   Tailscale and normal egress.
8. Verify:
   - `ssh ubuntu@<tailscale-hostname>`;
   - public SSH to the public IP fails;
   - the VM shape/CPU/RAM matches the selected option.

## Choose Runtime

Use a choice question after the server is reachable:

- **Hermes (Recommended)**: best default for new installs if the user wants Nous/Hermes' newer
  agent stack, native delegation, and the runtime this workflow ultimately promoted as live.
- **OpenClaw**: best if the user specifically wants the original OpenClaw workflow, mature
  phone-channel workflows, or an OpenClaw-compatible setup before any Hermes evaluation.
- **Both**: best for comparison. Install both side-by-side, but never share live channel tokens
  between them. Give each runtime separate Telegram/Slack identities.

Then follow the matching reference:

- `references/openclaw.md` for OpenClaw.
- `references/hermes.md` for Hermes.
- `references/migration.md` when switching between runtimes or importing state.

## OpenClaw Path

Use `references/openclaw.md`.

Minimum completion criteria:

- OpenClaw installed under the server user.
- Gateway bound to loopback, token-authenticated, and exposed only through Tailscale Serve or an
  SSH tunnel.
- `openclaw-gateway.service` enabled and hardened with `Restart=on-failure`.
- Default model and fallback both generate `PONG`.
- At least one channel is owner-locked and working end-to-end.

## Hermes Path

Use `references/hermes.md`.

Minimum completion criteria:

- Hermes installed under `~/.hermes`.
- Config migrated to the current schema.
- `~/.hermes/SOUL.md` contains the skill-added delegation/coding-harness/documentation operating block; do not assume stock Hermes ships this behavior.
- At least one provider/model generates `PONG`.
- If running as the live assistant, `hermes-gateway.service` is installed, enabled, and verified.
- At least one separate channel identity is owner-locked and working.

Hermes has native `delegate_task` subagents with configurable parallelism, but stock Hermes may not
use them the way this workflow expects unless told to. This skill adds a `SOUL.md` block that makes
Hermes delegate longer independent workstreams while keeping quick tasks inline, and route
substantial coding work to Codex CLI, Claude Code, or the user's configured coding harness when
available. Do not force a strict "orchestrator-only" persona unless the user explicitly wants it.

## Both Side-by-Side

Side-by-side is feasible on an A1 VM, especially at `4 OCPU / 23 GB`, but treat channels and
secrets carefully.

- Install the user's chosen primary runtime first.
- Install the second runtime separately (`~/.openclaw` and `~/.hermes` do not overlap).
- Use separate Telegram bots and separate Slack apps/tokens.
- Do not point two live gateways at the same Telegram bot token; long polling will fight.
- Do not point two live gateways at the same Slack app/socket token.
- Use migration dry-runs for preview only until the user chooses a primary runtime.

## Migration Summary

Both directions exist in official tooling:

- **OpenClaw -> Hermes:** `hermes claw migrate --dry-run`, then apply only after reviewing the
  preview. Secrets are not migrated unless explicitly requested.
- **Hermes -> OpenClaw:** `openclaw migrate hermes --dry-run` or `openclaw onboard --flow import`.
  Best with a fresh OpenClaw setup; use overwrite/include-secrets only after review.

See `references/migration.md` for the safe sequence and caveats.

## Verification Checklist

Before hand-off, verify the selected stack:

- OCI guardrails exist and VM is in the guarded compartment.
- Public SSH is blocked; Tailscale SSH works.
- Runtime health command passes:
  - OpenClaw: `openclaw gateway health`, `openclaw channels status --probe`.
  - Hermes: `hermes doctor`, `hermes status`, `hermes gateway status` if gateway is enabled.
- Primary and fallback models both return `PONG`.
- Channel access is owner-locked.
- For migrations, outbound delivery and inbound user-triggered replies work on every moved channel.
- No secrets were written into project docs or chat.

## Finish Line

Setup is done when the server is guarded, the chosen runtime is healthy, a model works, and one
owner-locked channel works from the user's phone.

The final hand-off matters:

> "You're live. From here you can just message the assistant. Ask it to install Codex CLI,
> Claude Code, GitHub CLI, Playwright, ffmpeg, voice transcription, or another MCP/channel.
> It can extend itself on the server. Keep destructive actions approval-gated until each workflow
> proves itself."

Do not bloat the base setup by hand-installing every possible tool. Make the user aware that the
assistant can install and document new capabilities itself. Before closing, tell the assistant to
write the documentation rule into its own workspace notes so every future self-installed tool is
durable.

## References

- `references/oracle-guardrails.md` - PAYG guardrails and capacity handling.
- `references/openclaw.md` - OpenClaw install, models, Telegram, Slack, media, transcription.
- `references/hermes.md` - Hermes install, models, gateway, channels, delegation.
- `references/migration.md` - OpenClaw <-> Hermes migration.
- `references/runbook.md` - older compact Oracle/OpenClaw sequence and troubleshooting.
