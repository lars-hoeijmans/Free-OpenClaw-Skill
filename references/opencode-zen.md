# OpenCode Zen Model Selection

Use this reference whenever the user chooses OpenCode Zen as a model provider for OpenClaw or
Hermes. The catalog changes, so do not hardcode today's model IDs as permanent defaults.

## Privacy and Data-Use Warning

Before enabling OpenCode Zen free models, explicitly tell the user:

> OpenCode Zen free/trial models may retain prompts and outputs or use them to improve/train
> models, depending on the model and current provider terms. Do not send secrets, customer data,
> private business context, personal data, or sensitive code unless you accept that tradeoff.

OpenCode's current Zen docs say most providers follow zero-retention/no-training terms, but list
exceptions for free/trial models including Mimo, DeepSeek, Big Pickle, North Mini Code, and
Nemotron free endpoints. Treat free Zen as a great zero-cost path for non-sensitive work, not the
recommended sensitive-data path.

If the user wants the safer sensitive-work setup, recommend OpenAI/ChatGPT OAuth or another
provider route with suitable data controls instead. For OpenAI/Codex, also have the user verify
their own OpenAI Data Controls/Codex settings; do not promise privacy blindly.

## Policy

Recommend models in this order:

1. Latest working **free Mimo** model.
2. Latest working **free DeepSeek** model, if no free Mimo model exists or works.
3. If neither works, ask the user to choose from other tested free OpenCode Zen models.

Catalog presence is not enough. A model must return a real test response before becoming the
default or fallback.

## Discover Candidates

Run this on the server after `jq` is installed:

```bash
OPENCODE_ZEN_MODELS_JSON="$(curl -fsSL https://opencode.ai/zen/v1/models)"

FREE_MODELS="$(printf '%s\n' "$OPENCODE_ZEN_MODELS_JSON" \
  | jq -r '.data[].id' \
  | grep -Ei '(-free$|^big-pickle$)' \
  | sort -Vr)"

MIMO_CANDIDATES="$(printf '%s\n' "$FREE_MODELS" | grep -Ei 'mimo' || true)"
DEEPSEEK_CANDIDATES="$(printf '%s\n' "$FREE_MODELS" | grep -Ei 'deepseek' || true)"

printf 'Free Mimo candidates:\n%s\n\n' "${MIMO_CANDIDATES:-<none>}"
printf 'Free DeepSeek candidates:\n%s\n' "${DEEPSEEK_CANDIDATES:-<none>}"
```

The `-free` suffix is the OpenCode Zen convention currently exposed by the catalog. If the API
later exposes explicit pricing fields, prefer explicit `$0` pricing over suffix matching.

## Test Candidates

Test the Mimo candidates first, then DeepSeek candidates. Skip any candidate that hangs, errors,
or produces no final response.

Hermes:

```bash
for model in $MIMO_CANDIDATES $DEEPSEEK_CANDIDATES; do
  echo "Testing $model"
  if timeout 60s hermes -z "Reply exactly: PONG" --provider opencode-zen --model "$model" \
    | grep -qx 'PONG'; then
    RECOMMENDED_OPENCODE_ZEN_MODEL="$model"
    break
  fi
done

test -n "${RECOMMENDED_OPENCODE_ZEN_MODEL:-}" \
  || { echo "No working free Mimo/DeepSeek model found; ask the user."; exit 1; }

echo "Recommended OpenCode Zen model: $RECOMMENDED_OPENCODE_ZEN_MODEL"
```

OpenClaw:

Register the currently free candidates before testing:

```bash
PROVIDER_JSON="$(printf '%s\n' "$FREE_MODELS" | jq -R -s '
  split("\n")
  | map(select(length > 0))
  | map({id: ., name: .}) as $models
  | {
      baseUrl: "https://opencode.ai/zen/v1",
      api: "openai-completions",
      apiKey: "${OPENCODE_ZEN_API_KEY}",
      models: $models
    }
')"

openclaw config set models.providers.opencodezen "$PROVIDER_JSON" --strict-json --replace
openclaw config set env.OPENCODE_ZEN_API_KEY '<entered-by-human>'
```

Then test:

```bash
for model in $MIMO_CANDIDATES $DEEPSEEK_CANDIDATES; do
  echo "Testing $model"
  if timeout 60s openclaw infer model run \
    --model "opencodezen/$model" \
    --prompt 'Reply exactly: PONG' \
    | grep -q 'PONG'; then
    RECOMMENDED_OPENCODE_ZEN_MODEL="$model"
    break
  fi
done

test -n "${RECOMMENDED_OPENCODE_ZEN_MODEL:-}" \
  || { echo "No working free Mimo/DeepSeek model found; ask the user."; exit 1; }

echo "Recommended OpenCode Zen model: $RECOMMENDED_OPENCODE_ZEN_MODEL"
```

## Set Defaults

Hermes:

```bash
hermes config set model.provider opencode-zen
hermes config set model.default "$RECOMMENDED_OPENCODE_ZEN_MODEL"
hermes config set model.base_url https://opencode.ai/zen/v1
hermes config set model.api_mode openai_chat
hermes -z "Reply exactly: PONG"
```

OpenClaw:

```bash
openclaw config set agents.defaults.models \
  '{"opencodezen/'"$RECOMMENDED_OPENCODE_ZEN_MODEL"'":{}}' \
  --strict-json --replace
openclaw models set "opencodezen/$RECOMMENDED_OPENCODE_ZEN_MODEL"
openclaw gateway restart
openclaw infer model run \
  --model "opencodezen/$RECOMMENDED_OPENCODE_ZEN_MODEL" \
  --prompt 'Reply exactly: PONG'
```

If the user also configured ChatGPT/OpenAI OAuth, it is reasonable to add a tested OpenAI model as
a final fallback only if the user accepts the privacy/cost tradeoff. If the user chose OpenAI-only
for sensitive work, do not add free OpenCode Zen models as fallbacks. If the user wants free-only,
use another tested free OpenCode Zen model as fallback rather than a paid/API-key model.

## Current Observed Examples

On 2026-06-15, the live catalog included `mimo-v2.5-free` and `deepseek-v4-flash-free`. Treat
those as examples only; always fetch and test the current catalog during setup.
