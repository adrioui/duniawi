# AI Tools

## Status

The AI toolchain is installed system-wide. Amp is pinned separately because its upstream releases move faster than the flake's nixpkgs input. DeepSeek is reached through a dedicated Cloudflare Tunnel and proxy documented in `docs/amp-deepseek.md`.

## Packages

`modules/ai.nix` installs:

| Package | Role |
|---|---|
| `amp-cli` from `pkgs/amp-cli.nix` | Amp coding agent CLI |
| `llm-agents.pi` | Pi coding agent |
| `llm-agents.opencode` | OpenCode |
| `llm-agents.cursor-agent` | Cursor agent |
| `llm-agents.claude-code` | Claude Code |
| `herdr` | terminal agent/herd tooling |

`pkgs/amp-cli.nix` is pinned to the latest upstream release at packaging time:

```text
0.0.1793332853-ge7c6c6
sha256-9HLoroHiXsDQOMENpciBLrSPLGwc/GTipmeJthGnwhs=
```

It is unfree and allowlisted in `modules/den.nix`.

## Amp DeepSeek

The Amp DeepSeek integration is documented separately:

* `docs/amp-deepseek.md` — tunnel, proxy, Keychain, model mapping, modes.

The local system plugin `~/.config/amp/plugins/official-modes` registers the official mode list, including DeepSeek V4.1 Flash. It is copied from `pkgs/amp-official-modes/` by home-manager activation because Amp requires a writable plugin directory.

## Keychain environment

`modules/shell.nix` exports keys at shell start from Keychain:

| Variable | Keychain service |
|---|---|
| `HCNOTE_API_KEY` | `hcnote` |
| `COMMANDCODE_API_KEY` | `commandcode-api-key` |
| `OPENCODE_API_KEY` | `opencode-api-key` |
| `OPENCODE_GO_API_KEY` | same as `OPENCODE_API_KEY` |

Values are read with `security find-generic-password` at runtime. They are not written to Nix, plists, or logs.

## Verification

```bash
amp --version
amp plugins list
amp config model-providers list --json
claude --version
opencode --version
cursor-agent --version
```

For the DeepSeek route:

```bash
amp config model-providers check-access \
  --provider-model deepseek/deepseek-v4.1-flash \
  --thread <thread-id>
```

## Security

* API keys live in Keychain, never in the repository.
* Amp provider credentials are stored in Amp's encrypted cloud config.
* The unfree allowlist is narrow.
* The official modes plugin is vendored from the official Amp plugin cache and pinned in `pkgs/amp-official-modes/SOURCE.md`.
* No AI tool receives a repository-stored secret.

## Troubleshooting

| Symptom | Check |
|---|---|
| `amp` missing | rebuild and check `pkgs/amp-cli.nix` |
| Amp model list only shows built-ins | restart Amp or run `plugins: reload`; check `amp plugins list` |
| DeepSeek mode missing | check the `official-modes` plugin and the `amp-deepseek-tunnel` connection |
| `401` from DeepSeek proxy | inbound key in Keychain and Amp connection |
| Keychain variable empty | item name and login keychain |
| Claude Code auth fails | `claude` uses its own auth, not the shell exports |
| Cursor agent missing | `pkgs.llm-agents.cursor-agent` must be in `environment.systemPackages` |
