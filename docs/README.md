# Documentation

Operator documentation for the two-host Nix flake repository.

| Document | Covers |
|---|---|
| [Architecture](architecture.md) | flake-parts, den aspects, host/user model, per-system outputs |
| [Nix settings](nix-settings.md) | flake-first policy, registry, overlays, GC, validation |
| [Homebrew](homebrew.md) | casks, brews, zap cleanup, deterministic activation |
| [Audio](audio.md) | Pure Data, externals, Max/MSP, RAVE and vSchaos2 models |
| [Network](network.md) | Tailscale, Netbird, VPN clients |
| [AI tools](ai-tools.md) | Amp, OpenCode 2, Pi, Bend, Herdr, Keychain exports |
| [Shared modules](module-sharing.md) | one CLI declaration for both hosts |
| [Shell](shell.md) | zsh, Starship, Keychain environment, terminals |
| [Development tools](dev-tools.md) | language runtimes, containers, Nix tooling |
| [Applications](applications.md) | editors, Helium, media apps, XcodeBuildMCP |
| [Maintenance](maintenance.md) | clean worktrees, validation gates, device acceptance, rebuilds, updates |

## Device acceptance

The t14 gate is a Nix package and a Den aspect, not a copied script:

- `pkgs/device-verify.nix` packages `scripts/device-verify.sh` with
  `writeShellApplication` and pinned parsers;
- `modules/device-verify.nix` exposes `duniawi.deviceVerify.{enable,package,rescueIsoSha256}`,
  installs `/run/current-system/sw/bin/device-verify`, keeps
  `/etc/duniawi/device-verify.sh` as a compatibility path, and declares the
  root-only `/var/lib/duniawi/evidence` tree;
- `modules/t14.nix` includes `den.aspects.deviceVerify`; `modules/per-system.nix`
  exposes `packages.x86_64-linux.device-verify`.

Run the strict gate as root; a user run is a preview whose root-only rows are
`NotRun`. The evidence schema and the `Attested` rules are in
[Maintenance](maintenance.md#device-acceptance-gate-t14).

## Reading order

1. `architecture.md` for the repository shape.
2. `nix-settings.md` for the flake-first invariants.
3. The feature document for the area being changed.
4. `maintenance.md` before committing or switching.

## Conventions

* Every feature document follows the same shape: status, configuration, verification, security, troubleshooting.
* Commands assume the repository is at `~/.config/nix` unless stated otherwise.
* Keychain service names are documented; secret values are never included.
* File paths are relative to the repository root.
