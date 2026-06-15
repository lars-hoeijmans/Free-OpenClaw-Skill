# OpenClaw <-> Hermes Migration

Migration is useful when a user starts with one runtime and later wants to evaluate or switch to
the other. Always preview first. Never share live channel tokens between two running gateways.

## OpenClaw -> Hermes

Official docs: https://hermes-agent.nousresearch.com/docs/guides/migrate-from-openclaw

Hermes imports OpenClaw with:

```bash
hermes claw migrate --dry-run
```

Dry-run is the default first step. It previews what would be imported and makes no changes.

Apply only after review:

```bash
hermes claw migrate
```

Full migration including API keys/secrets requires explicit opt-in:

```bash
hermes claw migrate --preset full --migrate-secrets --yes
```

If Hermes already has its own `SOUL.md` or model config, the migration may refuse to apply until
conflicts are resolved. The safe pattern is:

```bash
hermes claw migrate --dry-run --preset full --migrate-secrets --skill-conflict rename
# If conflicts are expected and backups exist:
hermes claw migrate --preset full --migrate-secrets --skill-conflict rename --overwrite --yes
```

After `--overwrite`, immediately re-test and restore Hermes-specific model settings if needed.
OpenClaw model IDs and provider names do not always work unchanged in Hermes.
Also reapply the Hermes `SOUL.md` operating defaults from `references/hermes.md` if the migration
overwrote the persona file. That block includes both the delegation rule and the coding-harness
rule that routes substantial codebase work to Codex CLI, Claude Code, or the user's equivalent
coding agent.

What the Hermes docs say can migrate:

- persona, memory, user profile, daily memory files;
- skills from several OpenClaw skill locations;
- model/provider config;
- session policies;
- MCP servers;
- messaging platform config;
- some TTS and miscellaneous config.

Secrets are not imported silently. `--migrate-secrets` is required, and SecretRefs using file/exec
sources may require manual setup.

Safe side-by-side recommendation:

- Run `--dry-run` only while OpenClaw is live.
- Do not migrate Telegram/Slack secrets if both gateways will keep running.
- Prefer separate Hermes channel identities for evaluation.
- If switching over, stop OpenClaw gateway first, then migrate/reconfigure channels deliberately.

## Post-Cutover Smoke Test

After any migration that moves live Telegram, Slack, or other channel tokens:

1. Confirm the old gateway is stopped and disabled.
2. Confirm the new gateway is active and enabled.
3. Confirm the new runtime's default and fallback models generate a real `PONG`.
4. Confirm adapter logs show platform connection, such as Telegram polling or Slack Socket Mode.
5. Send one outbound test message from the new runtime if the CLI supports it.
6. Ask the user to send an inbound `ping` from every migrated channel and verify an agent reply.
7. Explain changed channel UX before hand-off. For example, OpenClaw's custom Slack `/claudia`
   command does not automatically become a Hermes command; use DM, mention, `/hermes`, or update
   the Slack app manifest.

Logs and outbound sends prove the transport is connected. The inbound user-triggered ping proves
the user can actually drive the assistant.

## Hermes -> OpenClaw

Official docs:

- https://docs.openclaw.ai/install/migrating-hermes
- https://docs.openclaw.ai/cli/migrate

OpenClaw supports importing Hermes state through its migration provider.

Preview:

```bash
openclaw migrate hermes --dry-run
```

Apply after review:

```bash
openclaw migrate apply hermes --yes
```

Onboarding import path:

```bash
openclaw onboard --flow import
openclaw onboard --import-from hermes --import-source ~/.hermes
```

The OpenClaw docs recommend a fresh OpenClaw setup for onboarding imports. If OpenClaw state
already exists, reset it first or use `openclaw migrate` with overwrite/include-secrets only after
reviewing the plan.

What OpenClaw imports from Hermes:

- model configuration and custom providers;
- MCP server definitions;
- `SOUL.md`, `AGENTS.md`, memory files, and user memory;
- skills with `SKILL.md`;
- selected auth credentials when explicitly included.

Archive-only/manual-review state includes plugins, sessions, logs, cron, MCP tokens, and state
databases. Do not assume OpenClaw can safely execute or trust those opaque files.

Secret options:

```bash
openclaw migrate apply hermes --include-secrets --yes
openclaw migrate hermes --dry-run --no-auth-credentials
```

Use secrets import only when the user is switching primary runtime, not when running both.

## Decision Rules

- **User wants to evaluate:** install side-by-side, no secret migration, separate channels.
- **User wants to switch OpenClaw -> Hermes:** backup OpenClaw, stop OpenClaw gateway, run Hermes
  dry-run, then apply selected migration, verify Hermes models/channels. Explicitly set
  `TELEGRAM_ALLOWED_USERS` and `SLACK_ALLOWED_USERS` in Hermes after migration.
- **User wants to switch Hermes -> OpenClaw:** backup Hermes, use fresh OpenClaw when possible,
  run OpenClaw dry-run, then apply selected migration, verify OpenClaw doctor/models/channels.
- **User wants both long-term:** do not migrate channel secrets. Duplicate durable docs/memory only
  if the user wants similar personalities.
