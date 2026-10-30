# Documentation

Operator documentation for this nix-darwin repository.

| Document | Covers |
|---|---|
| [Architecture](architecture.md) | flake-parts, den aspects, host/user model, per-system outputs |
| [Nix settings](nix-settings.md) | flake-first policy, registry, overlays, GC, validation |
| [Homebrew](homebrew.md) | casks, brews, zap cleanup, deterministic activation |
| [Audio](audio.md) | Pure Data, externals, Max/MSP, RAVE and vSchaos2 models |
| [Network](network.md) | Tailscale, Netbird, VPN clients, cloudflared |
| [AI tools](ai-tools.md) | Amp, Claude Code, OpenCode, Cursor, Pi, Herdr, Keychain exports |
| [Amp DeepSeek](amp-deepseek.md) | Cloudflare Tunnel, proxy, inbound key, official modes |
| [Shell](shell.md) | zsh, Starship, Keychain environment, terminals |
| [Development tools](dev-tools.md) | language runtimes, containers, Nix tooling |
| [Applications](applications.md) | editors, Helium, media apps, XcodeBuildMCP |
| [Maintenance](maintenance.md) | clean worktrees, validation gates, rebuilds, updates |

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
