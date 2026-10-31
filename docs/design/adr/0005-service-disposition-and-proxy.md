# ADR-0005: Archive the old proxy stack; implement amp-deepseek natively

- Status: Proposed
- Date: 2026-10-31
- Deciders: repository owner
- Related: `docs/design/services.md`, `docs/design/packages.md`, Approval 3

## Context

The old Fedora home has 27 enabled user units, most of them AI proxies,
routers, tunnels, credential brokers, and work demos. Several contain inline
secrets or environment files. The backup is read-only and unencrypted. Copying
the stack would copy its secret surface and its unsupported code.

The repository already owns a small, tested proxy at `pkgs/amp-deepseek`
(MIT, Node, `/health`, loopback `4014`). The user wants that proxy implemented
on NixOS as well, but **not** copied from the external HDD.

## Decision

1. Archive the old Fedora proxy stack. Do not copy its units, scripts, env
   files, tunnel tokens, or provider keys.
2. Implement the repo-owned `amp-deepseek` proxy natively on NixOS as
   `ampDeepseekNixos`:
   - home-manager `systemd.user.services.amp-deepseek-proxy`;
   - `ExecStart` from `pkgs/amp-deepseek`;
   - sops secrets for upstream and inbound keys;
   - bind `127.0.0.1:4014`;
   - no Cloudflare tunnel by default.
3. Keep the Darwin `ampDeepseek` launchd/Keychain aspect unchanged on `adri`.
4. Replace `nix-gc` with `nix.gc.automatic`; replace `podman-restart` with the
   NixOS podman module; drop broken home-manager units.
5. Archive every other old unit. Reimplement a service only after its code is
   in the repository, its secrets are in sops, and its VM test passes.

## Consequences

- The NixOS attack surface is much smaller: one loopback proxy, no old
  tunnels, no remote shell bridge, no credential brokers.
- Old AI proxy workflows are unavailable on NixOS until separately
  reimplemented. That is intentional.
- The old proxy data stays in the read-only backup as archive evidence.
- The proxy is testable on both systems with the existing Node tests.
- The proxy's DeepSeek upstream key must be newly issued; the old
  `deepseek-direct.key` is not reused.

## Alternatives considered

| Alternative | Why rejected |
|---|---|
| Copy the old proxy stack | copies secrets and unsupported code from an unencrypted backup |
| Port every old unit | large scope, unknown behavior, high secret surface |
| No proxy at all | user explicitly wants the repo-owned proxy implemented |
| Port the Cloudflare tunnel too | unnecessary public exposure; not requested |

## Verification

- `nix build .#checks.x86_64-linux.amp-deepseek` and Darwin equivalent pass.
- VM: proxy active, `/health` 200, wrong key 401, missing secret 503.
- `ss -ltnp` shows only `127.0.0.1:4014`.
- No archived unit is enabled.
- No old proxy file is present in the restored home.
