# Service disposition table

Status: **Gate 1 draft — no implementation writes yet**

Scope: the 27 enabled `default.target.wants` user units and 5 enabled timers
captured from the old Fedora home, plus the one repo-owned proxy that is
implemented natively on NixOS.

Policy:

- No old proxy unit, script, environment file, tunnel token, or provider key is
  copied from the external HDD.
- The old stack stays in the read-only backup as archive evidence.
- The only proxy on NixOS is the repo-owned `amp-deepseek-proxy`, bound to
  `127.0.0.1:4014`.
- The Cloudflare tunnel that exists on Darwin is **not** ported by default.
- A service is only started on NixOS after its code is in the repository, its
  secrets are in sops, and its VM test passes.

Disposition values: `Port` (implement natively), `Replace` (use a NixOS
module), `Containerize` (run in podman), `Archive` (keep data, do not start),
`Drop` (do not restore).

## 1. Enabled user services

| # | Unit | What it does | Network / data | Secret references | Disposition | NixOS action / reason |
|---|---|---|---|---|---|---|
| 1 | `amp-bifrost-vk-proxy.service` | injects a Bifrost virtual key for the Amp tunnel | `127.0.0.1:4012`; reads `bifrost-virtual.key` | virtual key file | Archive | old proxy stack; no copy |
| 2 | `amp-litellm-named-tunnel.service` | Cloudflare named tunnel for Amp-facing LiteLLM | outbound tunnel; token file | `cf-tunnel-token` | Archive | tunnel is not ported; no token copy |
| 3 | `arah.service` | ride-planner project server | `PORT=8790`; project tree | project env | Archive | project-specific; restore data only, do not start |
| 4 | `bifrost-amp.service` | Bifrost LLM gateway container | host network; Docker volume | `bifrost.env`, setup token | Archive | container stack is not part of the curated NixOS profile |
| 5 | `bliv5802-api.service` | BLIV-5802 backend demo | `0.0.0.0:14001`; worktree venv | `UP.env` | Archive | work demo; never expose `0.0.0.0` |
| 6 | `bliv-admin-real.service` | BLIV admin demo | project tree; local config | project config | Archive | work demo |
| 7 | `bliv-dh-real.service` | BLIV data-house demo | project tree; local config | project config | Archive | work demo |
| 8 | `bliv-secrets.service` | home-manager-managed secret unit | no unit file in manifest; dangling symlink | unknown | Drop | broken symlink; do not restore; recreate secrets through sops if needed |
| 9 | `claude-litellm.service` | LiteLLM router for Claude Code | local port; config tree | OAuth/token files | Archive | old proxy stack |
| 10 | `cline-litellm.service` | LiteLLM front door for cline/qoder | local port; config tree | multiple `cline-shim/*.env`, master key | Archive | old proxy stack; inline secret in unit |
| 11 | `cline-shim.service` | Cline account-rotating shim | `127.0.0.1:8788`; accounts JSON | `accounts.json` | Archive | account rotation is not part of the NixOS profile |
| 12 | `cliproxyapi-magnitude.service` | CLIProxyAPI Magnitude proxy | local port; `Tooling/CLIProxyAPI-latest-magnitude` | config file | Archive | old proxy stack |
| 13 | `collie.service` | remote shell bridge | `COLLIE_PORT=8787`; Tailscale hosts | `collie/.env` | Archive | remote shell exposure; do not expose |
| 14 | `commandcode-proxy.service` | Anthropic/OpenAI-compatible Command Code proxy | `127.0.0.1:3050`; `Tooling/commandcode-proxy` | inline `QODER_API_KEY` | Archive | old proxy; inline secret must be rotated; no copy |
| 15 | `dashscope-effort-proxy.service` | injects effort into DashScope requests | `127.0.0.1:4013` | none in unit | Archive | old proxy |
| 16 | `deepseek-direct-effort-proxy.service` | injects effort into DeepSeek requests | `127.0.0.1:4014`; reads key file | inline key read from `deepseek-direct.key` | Archive | conflicts with `amp-deepseek-proxy` port; old proxy; no copy |
| 17 | `dsh-web.service` | DeepSeek Harness web UI | `127.0.0.1:3080`; `~/.dsh` | none in unit | Archive | `.local/bin/dsh` is absent from the manifest |
| 18 | `freebuff-2api.service` | Freebuff proxy | `127.0.0.1:47821`; Rust binary | `freebuff.env` | Archive | old proxy stack |
| 19 | `gpg-preset-passphrase.service` | presets a GPG passphrase into gpg-agent | none | **inline plaintext passphrase** | Drop | **SecretLeak**: never restore; rotate GPG passphrase/key; purge unit from restored tree |
| 20 | `magnitude-acn.service` | Magnitude ACN daemon | local daemon; `~/.magnitude` | none in unit | Archive | dev daemon; not part of NixOS profile |
| 21 | `nix-managed-probe.service` | home-manager-managed probe | no unit file; dangling symlink | unknown | Drop | broken symlink; do not restore |
| 22 | `omp-auth-broker.service` | OMP auth broker for Cursor/Anthropic | `127.0.0.1:18765`; `~/.omp` | credentials in `~/.omp` | Archive | credential broker; no copy |
| 23 | `omp-auth-gateway.service` | OMP auth gateway for Amp | `127.0.0.1:3062`; broker URL | broker credentials | Archive | old proxy stack |
| 24 | `podman-restart.service` | restarts podman containers at user login | user systemd; from `/usr/lib` | none | Replace | enable `virtualisation.podman`; use the NixOS module, do not copy the unit |
| 25 | `qodercli2api.service` | Qoder Anthropic-compatible proxy | `127.0.0.1:8377`; `Tooling/qodercli2api` | `qodercli2api/env` | Archive | old proxy stack |
| 26 | `sprint69-deck.service` | Sprint 69 static review deck | `127.0.0.1:8769`; Tailscale serve | none in unit | Archive | payload absent from manifest; do not start |
| 27 | `zcode-api.service` | Z.AI/Bigmodel coding-plan proxy | local port; `Tooling/zcode-api` | provider credentials | Archive | old proxy stack |

## 2. Enabled timers

| Timer | Unit | Schedule | Disposition | NixOS action / reason |
|---|---|---|---|---|
| `amp-drift.timer` | `amp-drift.service` | every 5 min | Archive | old proxy drift check |
| `claude-litellm-token.timer` | `claude-litellm-token.service` | every 1 min | Archive | old LiteLLM token reload |
| `haiku-route-check.timer` | `haiku-route-check.service` | every 2 min | Archive | old OMP route health check |
| `nix-gc.timer` | `nix-gc.service` | home-manager GC | Replace | use NixOS `nix.gc.automatic` with a reviewed schedule |
| `opencode-sync-commandcode.timer` | `opencode-sync-commandcode.service` | every 6 h | Archive | old proxy model sync |

## 3. Broken home-manager units

Five logical units have dangling symlinks into a missing home-manager
generation. They are not restored as links:

| Unit | Paths | Disposition |
|---|---|---|
| `bliv-secrets.service` | unit + `default.target.wants` symlink | Drop; recreate through sops if still needed |
| `nix-gc.service` | unit symlink | Replace with `nix.gc.automatic` |
| `nix-gc.timer` | unit + `timers.target.wants` symlink | Replace with `nix.gc.automatic` |
| `nix-managed-probe.service` | unit + `default.target.wants` symlink | Drop |
| `tray.target` | `default.target.wants` symlink | Drop; no NixOS tray target |

## 4. Native NixOS service

| Unit | Source | Listen | Secret references | Start condition | Verification |
|---|---|---|---|---|---|
| `amp-deepseek-proxy.service` | `pkgs/amp-deepseek` | `127.0.0.1:4014` | sops: `amp-deepseek/upstream-key`, `amp-deepseek/inbound-key` | enabled by `ampDeepseekNixos`; `WantedBy = [ "default.target" ]` | `curl /health` = 200; wrong inbound key = 401; missing secret = 503; `ss -ltnp` shows loopback only |

The proxy unit is a **home-manager systemd user service** on NixOS. It is not a
system service and does not open a firewall port. The Darwin launchd units
remain unchanged. The service is hardened with `NoNewPrivileges`,
`PrivateTmp`, `ProtectSystem=strict`, `ProtectHome=read-only`, and a restricted
address-family list. It orders after `sops-nix.service`; the sops template is
optional until `ampDeepseekNixos.sopsFile` is provisioned. The VM test injects
test keys through the same unit and verifies 200/401/503.

## 5. Ports and exposure

| Port | Old owner | New owner | Bind | Exposure |
|---|---|---|---|---|
| 3050 | `commandcode-proxy` | none | n/a | archived |
| 3080 | `dsh-web` | none | n/a | archived |
| 4012 | `amp-bifrost-vk-proxy` | none | n/a | archived |
| 4013 | `dashscope-effort-proxy` | none | n/a | archived |
| 4014 | `deepseek-direct-effort-proxy` | `amp-deepseek-proxy` | `127.0.0.1` | loopback only |
| 8377 | `qodercli2api` | none | n/a | archived |
| 8769 | `sprint69-deck` | none | n/a | archived |
| 8787 | `collie` | none | n/a | archived; remote shell risk |
| 8788 | `cline-shim` | none | n/a | archived |
| 14001 | `bliv5802-api` | none | n/a | archived |
| 18765 | `omp-auth-broker` | none | n/a | archived |
| 3062 | `omp-auth-gateway` | none | n/a | archived |
| 47821 | `freebuff-2api` | none | n/a | archived |

No old port is reopened by this change except `4014`, and only on loopback.

## 6. Verification gates

| Gate | Check | Pass condition |
|---|---|---|
| Static | `grep` the NixOS config for archived unit names | no old proxy unit or script is referenced |
| Evaluation | `nix eval .#nixosConfigurations.t14.config.home-manager.users.adrioui.systemd.user.services` | only `amp-deepseek-proxy` from this table |
| VM | `systemctl --user list-unit-files --state=enabled` | no archived unit enabled |
| VM | `ss -ltnp` | only loopback `4014`; no `0.0.0.0` proxy listener |
| VM | `curl -fsS http://127.0.0.1:4014/health` | HTTP 200 with `ok: true` |
| VM | stop sops secret / unset key | health 503; service does not fall back to plaintext |
| Security | `journalctl --user -u amp-deepseek-proxy` | no key material in logs |
| Migration | restored tree | no `gpg-preset-passphrase.service`, no old proxy env files, no dangling home-manager links |
