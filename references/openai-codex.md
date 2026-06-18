# OpenAI / ChatGPT OAuth Model Selection

Use this reference when the user connects OpenAI/Codex through ChatGPT OAuth in OpenClaw or
Hermes.

## Privacy Posture

For sensitive repositories, customer data, secrets, personal data, or private business context,
recommend OpenAI/Codex OAuth or API/Business routes over OpenCode Zen free models.

Do not make a blanket privacy promise. Tell the user:

- OpenAI API, ChatGPT Business/Enterprise/Edu, and other business offerings are documented as not
  training on inputs/outputs by default.
- Consumer ChatGPT/Codex subscription use can have separate data controls. Before sensitive use,
  the user should verify their ChatGPT Data Controls and Codex settings are configured the way
  they want.
- This is still a cloud model path. Do not send secrets unless the user accepts the provider's
  current terms and controls.

## Default Model Policy

Use the latest working **mini** model as the default for OpenAI/Codex OAuth. It is usually faster
and more cost-effective than the latest flagship model. Do not hardcode today's model ID as a
permanent default.

As of the workflow that informed this skill, `gpt-5.4-mini` worked. Treat it as an example only.

Selection order:

1. Discover/list models exposed to the signed-in account.
2. Filter for OpenAI/Codex model IDs containing `mini`.
3. Sort newest-first by version.
4. Test candidates until one returns `PONG`.
5. Set the first passing candidate as default.
6. Use a flagship model only if no mini model works and the user accepts the tradeoff.

## OpenClaw

After OAuth:

```bash
openclaw models auth login --provider openai
openclaw models list --provider openai
```

Build a candidate list from the actual account catalog:

```bash
OPENAI_MINI_CANDIDATES="$(openclaw models list --provider openai \
  | awk '{print $1}' \
  | sed 's#^openai/##' \
  | grep -Ei '^gpt-[0-9].*mini$|mini' \
  | sort -Vr)"

printf 'OpenAI mini candidates:\n%s\n' "${OPENAI_MINI_CANDIDATES:-<none>}"
```

Test newest-first:

```bash
for model in $OPENAI_MINI_CANDIDATES; do
  echo "Testing openai/$model"
  if timeout 90s openclaw infer model run \
    --model "openai/$model" \
    --prompt 'Reply exactly: PONG' \
    | grep -q 'PONG'; then
    RECOMMENDED_OPENAI_MODEL="$model"
    break
  fi
done

test -n "${RECOMMENDED_OPENAI_MODEL:-}" \
  || { echo "No working OpenAI mini model found; ask the user before using a flagship model."; exit 1; }
```

Set it:

```bash
openclaw config set agents.defaults.models \
  '{"openai/'"$RECOMMENDED_OPENAI_MODEL"'":{}}' \
  --strict-json --replace
openclaw models set "openai/$RECOMMENDED_OPENAI_MODEL"
openclaw gateway restart
```

If OpenCode Zen is also configured, include both tested models in the allowlist and make the
user-selected primary explicit.

## Hermes

After OAuth:

```bash
hermes auth add openai-codex --type oauth --no-browser
```

Hermes may not expose the same non-interactive catalog command across versions. Prefer the
interactive `hermes model` catalog if available, or use the current OpenAI/Codex model docs as the
candidate source, then test the candidate IDs against the signed-in account.

Test newest-first:

```bash
OPENAI_MINI_CANDIDATES="${OPENAI_MINI_CANDIDATES:-gpt-5.4-mini gpt-5.1-codex-mini}"

for model in $OPENAI_MINI_CANDIDATES; do
  echo "Testing $model"
  if timeout 90s hermes -z "Reply exactly: PONG" --provider openai-codex --model "$model" \
    | grep -qx 'PONG'; then
    RECOMMENDED_OPENAI_MODEL="$model"
    break
  fi
done

test -n "${RECOMMENDED_OPENAI_MODEL:-}" \
  || { echo "No working OpenAI mini model found; ask the user before using a flagship model."; exit 1; }
```

Set it:

```bash
hermes config set model.provider openai-codex
hermes config set model.default "$RECOMMENDED_OPENAI_MODEL"
hermes -z "Reply exactly: PONG"
```

If the user chooses OpenAI only for sensitive work, do not configure OpenCode Zen free models as
fallbacks.
