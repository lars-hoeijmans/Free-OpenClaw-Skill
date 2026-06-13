# 🦞 Free-OpenClaw-Skill

**Your own AI assistant — on your own cloud box, in your pocket.**
An agent skill that sets up a private, phone-controlled [OpenClaw](https://openclaw.ai) assistant on a cheap Oracle Cloud ARM server… guided by an agent that already knows every pothole, so you don't have to step in them.

> It started as one real, end-to-end setup. Every trap we hit got written down — so the *next* run is the smooth one.

---

## ✨ What you end up with

A pocket-sized AI ops assistant that's actually *yours*:

- 🖥️ **A free/cheap Oracle ARM server** (`VM.Standard.A1.Flex`), provisioned by CLI with real cost guardrails.
- 🔒 **Private by default** — bound to loopback, reachable only over your [Tailscale](https://tailscale.com) network. The public internet can't see it.
- 🤖 **OpenClaw Gateway** running as a service, with a model *and a tested fallback* wired up.
- 📱 **Telegram + Slack control** — text it from anywhere, no VPN. Locked to *you*.
- 🎙️ **Voice notes → text** (optional, via faster-whisper) — you literally just ask it to set that up.
- 🪄 **Self-extending** — once it's live, you ask it to install the Codex CLI, Claude Code, Playwright, `gh`… and it does. On its own server. By itself.

## 🎯 Who it's for

Written for an AI agent helping a human **anywhere** on the spectrum from *senior engineer* to *"wait, what's an SSH?"*. The skill does the work itself, explains each step in plain language, and hands you only the things **only you** can do — approve a browser login, paste a token into *your own* terminal.

## 🚀 Use it

1. Drop the skill into your Codex skills folder:
   ```bash
   git clone https://github.com/lars-hoeijmans/openclaw-oracle-setup ~/.codex/skills/openclaw-oracle-setup
   ```
2. Ask your agent:
   > "Use **openclaw-oracle-setup** to provision a guarded Oracle A1 OpenClaw server I can control from my phone."
3. Follow along. Budget ~1–2 hours, mostly hands-off — Oracle's A1 capacity wait is the main variable, and the skill plans for it.

> Lives in `~/.codex/skills/` for **Codex CLI**. The `SKILL.md` format is portable to other SKILL-compatible agents too.

## 🧰 What you'll need

- An **Oracle Cloud** account — the skill walks you through signup and the PAYG upgrade, with guardrails that keep real spend at **€0** if you stay inside Always-Free limits.
- A **Tailscale** account (free tier is plenty).
- A **model** — a ChatGPT/Claude subscription (via OAuth) or **free** models via OpenCode Zen.
- **Telegram** on your phone (and/or a **Slack** workspace) if you want chat control.

## 🕳️ Potholes it walks you around

Each of these cost real time to discover. The skill knows them so you don't have to:

- ☁️ Oracle's infamous **`Out of host capacity`** on A1 — with a retry strategy and an unattended watcher.
- 🙈 The gateway token that reads back as `__OPENCLAW_REDACTED__` — and why your `#token=` URL keeps getting rejected.
- 🧩 **"Free" models that are silently disabled** and make every chat reply *"Something went wrong"* — test before you trust.
- 🪪 The Slack **app-manifest gauntlet**: the required `description`, the Messages-tab toggle, and the "Agent or Assistant" switch that quietly hides your DMs.
- 👻 Why **bots can't join Slack group DMs** at all — and what to do instead.
- 🖼️ The `MEDIA:` line that breaks the instant it's wrapped in **markdown** (so your screenshot arrives as… a file path).
- 🔑 Why you only see one OpenAI model in the dashboard (plot twist: it's the allowlist, not your subscription).

## 🛡️ Safety, baked in

- Secrets **never** pass through the chat — they go in *your* terminal/browser. (Agent tool output redacts them anyway.)
- The gateway stays **loopback-only**, exposed solely over your private tailnet — never public HTTP.
- Cloud **cost guardrails** (quota policy + budget alert) go in *before* any paid resource is created.
- Your bot is **owner-locked** — a stranger can't drive an assistant that has shell access to your server.
- Keep destructive or external actions **approval-gated** until each workflow has earned your trust. Capability ≠ unattended trust.

## 📂 What's inside

```
SKILL.md       # the whole playbook — the agent reads this
scripts/       # bootstrap + gateway-install helpers
references/    # Oracle guardrails + the full end-to-end runbook
agents/        # skill interface descriptor
```

## 🤝 Contributing

Found a new pothole, or wired up something cool (a new channel, a slick Codex workflow)? Open an issue or a PR — that's how the skill gets smarter for the next person.

---

*Set up once, by hand, the hard way — so you can set it up in an afternoon, the easy way.* 🦞
