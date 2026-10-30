# Amp → DeepSeek direct

## Status

Amp connects directly to DeepSeek's Anthropic-compatible endpoint. There is no local adapter, no Cloudflare tunnel, no Bifrost, and no Bifrost virtual-key proxy for this path.

## Topology

```text
Amp cloud
  |
  |  HTTPS + Anthropic Messages
  |  Authorization: Bearer <DeepSeek key>
  v
https://api.deepseek.com/anthropic/v1/messages
```

The local Mac does not listen on a new port for this integration. LiteLLM on `:4000` and `:3456`, the cline shim on `:8788`, and codex-router on `:4200` are unchanged.

## Why this is the minimal topology

Real Amp traffic was captured on `bluefin-adri` with a recording pass-through that forwarded the body unchanged to DeepSeek. The corpus covered normal text, a tool call with a result, a continuation after the result, an interrupted tool turn, and streaming responses.

Every request succeeded without any body mutation. The existing adapter's repairs were therefore not necessary for this machine's Amp traffic:

| Candidate repair | Real Amp evidence | Decision |
|---|---|---|
| Missing thinking on assistant turns | Amp sends signed `thinking` blocks on tool turns and continuations | removed |
| Dangling `tool_use` | Amp synthesizes an error `tool_result` when a tool is cancelled | removed |
| Orphan `tool_result` | Amp pairs every result | removed |
| `tool_result` block ordering | Amp already leads with `tool_result` | removed |
| `redacted_thinking` filtering | Not emitted by Amp with DeepSeek | removed; DeepSeek rejects explicitly |
| Unsupported document and MCP blocks | Not emitted | removed; DeepSeek rejects explicitly |
| Model alias normalization | The Amp connection mapping sends `deepseek-flash` | moved to the connection mapping |
| `output_config.effort=max` injection | Three low-cost reasoning tasks showed no quality gain and higher token use | removed |

Bifrost and its vk proxy were rejected because they add a second credential layer and are not installed or required. Cloudflare was rejected for this path because Amp's servers can reach DeepSeek directly.

## Amp connection

Create a personal Custom URL connection:

| Field | Value |
|---|---|
| Name | `amp-deepseek-direct` |
| Base URL | `https://api.deepseek.com/anthropic` |
| API format | `anthropic-messages` |
| API key | DeepSeek API key |
| Model mapping | see below |
| Priority | `0` |

Model mapping:

```text
anthropic/claude-opus-5-5 -> deepseek-flash
deepseek/deepseek-v4.1-flash -> deepseek-flash
```

The first line makes Amp's default `medium` agent use `deepseek-flash` instead of allowing DeepSeek's automatic `claude-opus*` mapping to `deepseek-v4-pro`. The second line makes explicit DeepSeek model selections resolve to the same model.

Amp's other connections, including `amp-commandcode-zen`, are left in place. Models not mapped by `amp-deepseek-direct` continue to route through the remaining connections or Amp itself.

## Provisioning

On a machine with the Amp CLI and a DeepSeek key file:

```bash
amp config model-providers add-router custom-url \
  --name amp-deepseek-direct \
  --base-url https://api.deepseek.com/anthropic \
  --api-format anthropic-messages \
  --api-key-file "$HOME/.config/litellm/deepseek-direct.key" \
  --model-mapping "anthropic/claude-opus-5-5 -> deepseek-flash
deepseek/deepseek-v4.1-flash -> deepseek-flash" \
  --personal \
  --active \
  --acknowledge-hosted-in-china
```

Then move it to the front:

```bash
amp config model-providers set-priority <connection-id> 0
```

On the Mac, the DeepSeek key is already in Keychain as `deepseek-api-key`. If a file is needed for the Amp CLI:

```bash
security find-generic-password -s deepseek-api-key -w > "$HOME/.config/litellm/deepseek-direct.key"
chmod 600 "$HOME/.config/litellm/deepseek-direct.key"
```

Alternatively, add the same connection through Amp's Model Routing settings in the web app. The connection is cloud-side and applies to the Amp account, not to this Nix configuration.

Do not add this key to the Nix store, a plist, a launchd environment, or the repository.

## Verification

List the connection without printing secrets:

```bash
amp config model-providers list --json \
  | jq -r '.[] | [.name, .priority, .active] | @tsv'
```

Run a one-token inference through the connection:

```bash
amp config model-providers check-access \
  --provider-model anthropic/claude-opus-5-5 \
  --thread <thread-id>
```

Expected result:

```json
{
  "ok": true,
  "modelProviderName": "amp-deepseek-direct",
  "providerModelID": "deepseek-flash"
}
```

Run a real tool turn:

```bash
amp -x "Use the shell_command tool to run: printf amp-direct-final. Then report the output. Do not use any other tool." \
  --stream-json-thinking
```

Expected: a `tool_use` block, a `tool_result` block, and a final assistant text block. No local listener is involved.

## Compatibility notes

DeepSeek supports the Anthropic Messages surface with these limits:

* `x-api-key` is supported.
* `anthropic-version` is ignored.
* `anthropic-beta` is ignored except for the Files API image variant.
* `thinking` is supported; `budget_tokens` is ignored.
* `output_config.effort` accepts `low`, `high`, and `max`; the default is `high`.
* With `tools`, all prior thinking blocks must be passed back. Amp already does this.
* `document`, `redacted_thinking`, `mcp_tool_use`, `mcp_tool_result`, `code_execution_tool_result`, and `container_upload` are not supported. DeepSeek rejects them explicitly; the integration does not silently drop them.
* Streaming uses `text/event-stream`. Amp uses streaming for all captured agent requests. Non-streaming works at DeepSeek but is not exercised by Amp.

## Security

* The DeepSeek key is stored in Amp's encrypted cloud provider configuration.
* On the Mac, the source of truth remains Keychain item `deepseek-api-key`.
* No secret is added to the Nix store, repository, plists, logs, or launchd environment.
* There is no public ingress on the Mac for this path.
* No local service, temporary file, or background process is created.

## Troubleshooting

| Symptom | Check |
|---|---|
| `401` | DeepSeek key is missing or wrong in the Amp connection |
| `400` for a model | Model mapping does not cover the selected model |
| `claude-opus*` bills as `deepseek-v4-pro` | Add `anthropic/claude-opus-5-5 -> deepseek-flash` to the mapping |
| `422` for a block type | Amp sent `document`, `redacted_thinking`, MCP, code-execution, or container block; DeepSeek does not support it |
| Check-access uses a different provider | Move `amp-deepseek-direct` to priority `0` |
| No `amp` CLI on the Mac | Create the connection from Amp's Model Routing web settings |
