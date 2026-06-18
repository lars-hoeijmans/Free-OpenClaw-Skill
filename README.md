# 🦞 Free-OpenClaw-Skill

**Your own AI assistant — free, private, and in your pocket.**
An agent skill that sets up a private, phone-controlled self-hosted assistant on a **free** Oracle Cloud ARM server — now with a guided choice between [OpenClaw](https://openclaw.ai), [Hermes Agent](https://hermes-agent.nousresearch.com), or both.

> It started as one real, end-to-end setup. Every trap we hit got written down — so the *next* run is the smooth one.

---

## 💸 The best part: it runs on free

No new subscriptions required — the whole stack stands on free tiers:

- 🆓 **The server** — Oracle Cloud's **Always Free** ARM VM (`VM.Standard.A1.Flex`). The skill's quota + budget guardrails keep real spend at **€0**, even after the PAYG upgrade that's sometimes needed to get past Oracle's capacity limits.
- 🆓 **The brains** — free **OpenCode Zen** models ($0), fetched/tested live at setup. The skill prefers the newest working free Mimo model, then falls back to the newest working free DeepSeek model if needed. For sensitive work, it recommends OpenAI/ChatGPT OAuth instead because Zen free/trial models can have data-use exceptions.
- ♻️ **Already paying for ChatGPT (or Claude)?** Plug your existing subscription in via OAuth and use it too — no new spend. For OpenAI/ChatGPT OAuth, the skill tests the latest available mini model and uses that as the default when it works.

Floor cost: **$0/month.** Bring a paid model only if you already have one.

## ✨ What you end up with

A pocket-sized AI ops assistant that's actually *yours*:

- 🖥️ **A free Oracle ARM server** (`VM.Standard.A1.Flex`), provisioned by CLI with real cost guardrails.
- 🔒 **Private by default** — bound to loopback, reachable only over your [Tailscale](https://tailscale.com) network. The public internet can't see it.
- 🤖 **Your chosen runtime** — OpenClaw, Hermes, or both side-by-side for comparison.
- 🧠 **A tested model setup** — OpenAI/ChatGPT OAuth for sensitive work with the latest tested mini model by default, or free OpenCode Zen for non-sensitive work after a clear data-use warning.
- 📱 **Telegram + Slack control** — text it from anywhere, no VPN. Locked to *you*.
- 🎙️ **Voice notes → text** (optional, via faster-whisper) — you literally just ask it to set that up.
- 🪄 **Self-extending** — once it's live, you ask it to install the Codex CLI, Claude Code, Playwright, `gh`… and it does. On its own server. By itself.

## 🎯 Who it's for

Written for an AI agent helping a human **anywhere** on the spectrum from *senior engineer* to *"wait, what's an SSH?"*. The skill does the work itself, explains each step in plain language, and hands you only the things **only you** can do — approve a browser login, paste a token into *your own* terminal.

## 🚀 Use it

1. Drop the skill into your Codex skills folder:
   ```bash
   git clone https://github.com/lars-hoeijmans/Free-OpenClaw-Skill ~/.codex/skills/openclaw-oracle-setup
   ```
2. Ask your agent:
   > "Use **openclaw-oracle-setup** to provision a guarded Oracle A1 self-hosted agent server I can control from my phone."
3. The agent will ask you to choose:
   - OpenClaw
   - Hermes
   - Both, side-by-side
4. Follow along. Budget ~1–2 hours, mostly hands-off — Oracle's A1 capacity wait is the main variable, and the skill plans for it.

> Lives in `~/.codex/skills/` for **Codex CLI**. The `SKILL.md` format is portable to other SKILL-compatible agents too.

## 🧰 What you'll need

- An **Oracle Cloud** account — the skill walks you through signup and the PAYG upgrade, with guardrails that keep real spend at **€0** if you stay inside Always-Free limits.
- A **Tailscale** account (free tier is plenty).
- A **model** — ChatGPT/OpenAI OAuth if you already have it, or free OpenCode Zen models for non-sensitive work after reviewing their data-use tradeoff.
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
- 🔁 How to migrate **OpenClaw → Hermes** or **Hermes → OpenClaw** safely — dry-run first, secrets only by explicit choice.
- 🧵 Why Hermes usually does **not** need an "orchestrator-only" prompt — it has native delegation/subagents.

## 🛡️ Safety, baked in

- Secrets **never** pass through the chat — they go in *your* terminal/browser. (Agent tool output redacts them anyway.)
- The gateway stays **loopback-only**, exposed solely over your private tailnet — never public HTTP.
- Cloud **cost guardrails** (quota policy + budget alert) go in *before* any paid resource is created.
- Your bot is **owner-locked** — a stranger can't drive an assistant that has shell access to your server.
- Keep destructive or external actions **approval-gated** until each workflow has earned your trust. Capability ≠ unattended trust.

## 📂 What's inside

```
SKILL.md       # the guided router — Oracle first, then OpenClaw/Hermes/Both
scripts/       # bootstrap + OpenClaw/Hermes install helpers
references/    # Oracle guardrails, OpenClaw path, Hermes path, migrations
agents/        # skill interface descriptor
```

## 🤝 Contributing

Found a new pothole, or wired up something cool (a new channel, a slick Codex workflow)? Open an issue or a PR — that's how the skill gets smarter for the next person.

---

*Set up once, by hand, the hard way — so you can set it up in an afternoon, the easy way.* 🦞
