# Amp → DeepSeek via Cloudflare Tunnel

## Status

Amp connects to DeepSeek through a Cloudflare Tunnel and a minimal local proxy. The proxy forwards the Anthropic Messages body unchanged, validates an inbound bearer key, injects the DeepSeek key from Keychain, and streams the response back. There are no schema repairs, no Bifrost, and no Bifrost virtual-key proxy.

The Amp CLI is installed by `modules/ai.nix` through `pkgs/amp-cli.nix`, pinned to the latest upstream version `0.0.1793332853-ge7c6c6`. It is unfree, so `modules/den.nix` includes `amp-cli` in the unfree allowlist.

## Topology

```text
Amp cloud
  |
  |  https://amp-deepseek.adrioui.xyz/anthropic/v1/messages
  |  Authorization: Bearer <inbound key>
  v
Cloudflare Tunnel "amp-deepseek-mac"
  |
  v
cloudflared
  |
  v
127.0.0.1:4014  amp-deepseek-proxy
  |
  |  validates the inbound key
  |  injects x-api-key from Keychain
  v
https://api.deepseek.com/anthropic/v1/messages
```

The proxy does not mutate the request body. It only validates the inbound credential, removes inbound credentials, injects the DeepSeek key, and forwards the body and SSE stream.

## Why this topology

* Amp sends model requests from its servers, so the endpoint must be publicly reachable.
* The Cloudflare Tunnel is the only ingress. The origin proxy listens on `127.0.0.1:4014` only.
* The inbound bearer key is the public authentication layer. It is stored in Keychain and in Amp's encrypted provider config.
* Bifrost and its vk proxy are not installed or required.
* The previous adapter repairs were removed because the real Amp corpus passes without them. The proxy is a transport, not a protocol adapter.
* `output_config.effort=max` is not injected. A three-task benchmark showed no quality gain over `high`, with extra token use and latency.
* Unsupported DeepSeek blocks are passed through and rejected explicitly by DeepSeek.

## Amp connection

| Field | Value |
|---|---|
| Name | `amp-deepseek-tunnel` |
| Base URL | `https://amp-deepseek.adrioui.xyz/anthropic` |
| API format | `anthropic-messages` |
| API key | inbound key from Keychain `amp-deepseek-inbound-key` |
| Priority | `0` |

Model mapping:

```text
deepseek/deepseek-v4.1-flash -> deepseek-flash
anthropic/claude-opus-5-5 -> deepseek-flash
```

The first line makes the requested DeepSeek V4.1 Flash model resolve to the API's `deepseek-flash` model. The second makes Amp's default `medium` agent use DeepSeek Flash instead of DeepSeek V4 Pro.

## Dial

The `medium` Dial slot is tuned to `deepseek/deepseek-v4.1-flash` at `high` effort:

```json
{"preset":"chatgpt-only","medium":{"main":{"model":"deepseek/deepseek-v4.1-flash","effort":"high"}}}
```

The other Dial modes continue to follow the ChatGPT Only preset. This is an Amp account setting, not a Nix-managed value. It can be changed under Settings → Mode Dial → Tune Modes.

## Local services

`modules/amp-deepseek.nix` declares two home-manager launchd agents:

| Agent | Purpose |
|---|---|
| `amp-deepseek-proxy` | runs `pkgs/amp-deepseek/proxy.mjs` on `127.0.0.1:4014` |
| `amp-deepseek-tunnel` | runs `cloudflared tunnel --no-autoupdate run` with `TUNNEL_TOKEN` from Keychain |

The proxy reads `deepseek-api-key` and `amp-deepseek-inbound-key` from Keychain at launch. The tunnel reads `amp-deepseek-tunnel-token` from Keychain at launch. No value is written to a plist, the Nix store, or a log.

## Cloudflare resources

| Resource | Value |
|---|---|
| Tunnel | `amp-deepseek-mac` |
| Hostname | `amp-deepseek.adrioui.xyz` |
| Origin | `http://127.0.0.1:4014` |

There is no separate Cloudflare Access application for this hostname. The inbound bearer key is validated by the proxy.

The existing `amp.adrioui.xyz` tunnel and `amp-commandcode-zen` connection are unchanged.

## Verification

Local proxy:

```bash
curl -sS http://127.0.0.1:4014/health
```

Expected:

```json
{"ok":true,"upstream":"https://api.deepseek.com/anthropic"}
```

Public endpoint with the inbound key:

```bash
curl -sS -o /dev/null -w '%{http_code}\n' \
  -H "Authorization: Bearer $(security find-generic-password -s amp-deepseek-inbound-key -w)" \
  https://amp-deepseek.adrioui.xyz/anthropic/v1/messages \
  -H 'content-type: application/json' \
  -d '{"model":"deepseek-flash","max_tokens":16,"messages":[{"role":"user","content":"Say OK"}]}'
```

Amp provider check:

```bash
amp config model-providers check-access \
  --provider-model deepseek/deepseek-v4.1-flash \
  --thread <thread-id>
```

Expected: `ok: true`, provider `amp-deepseek-tunnel`, provider model `deepseek-flash`.

Real tool turn:

```bash
amp -x "Use the shell_command tool to run: printf cloudflare-proven. Then report the output. Do not use any other tool." \
  --stream-json-thinking
```

Expected: `tool_use`, `tool_result`, and a final text block.

## Compatibility notes

* `x-api-key` is supported by DeepSeek.
* `anthropic-version` is ignored.
* `anthropic-beta` is ignored except for the Files API image variant.
* `thinking` is supported; `budget_tokens` is ignored.
* `output_config.effort` accepts `low`, `high`, and `max`; the default is `high`.
* With `tools`, all prior thinking blocks must be passed back. Amp does this.
* `document`, `redacted_thinking`, `mcp_tool_use`, `mcp_tool_result`, `code_execution_tool_result`, and `container_upload` are not supported by DeepSeek. They are forwarded and rejected explicitly.
* Streaming uses `text/event-stream`. Amp uses streaming for agent requests.

## Security

* The inbound bearer key is the public authentication layer.
* The origin proxy listens only on `127.0.0.1:4014`.
* The proxy strips `Authorization`, `x-api-key`, `x-amp-thread-id`, and all inbound gateway headers before calling DeepSeek.
* The DeepSeek key, inbound key, and tunnel token are read from Keychain at launch.
* No secret appears in the repository, Nix store, plists, logs, or launchd environment.
* The proxy logs only status, request size, and duration.

## Troubleshooting

| Symptom | Check |
|---|---|
| `401` from the proxy | Inbound key is missing or wrong in the Amp connection |
| `502` from the proxy | `cloudflared` cannot reach `127.0.0.1:4014` or the proxy is down |
| `503` from the proxy | Keychain item `deepseek-api-key` or `amp-deepseek-inbound-key` is missing |
| Tunnel exits at launch | Keychain item `amp-deepseek-tunnel-token` is missing |
| `400` for a model | Amp model mapping does not map the selected model to `deepseek-flash` |
| `422` for a block type | Amp sent a block DeepSeek does not support |
