<p align="center">
  <strong>A macOS dev environment that rebuilds itself.</strong>
  <strong><a href="https://github.com/adrioui/nix">github.com/adrioui/nix</a></strong>
</p>

<p align="center">
  <a href="https://github.com/LnL7/nix-darwin"><img src="https://img.shields.io/badge/nix--darwin-5277C3?style=flat&colorA=222222" alt="nix-darwin"></a>
  <a href="https://github.com/nix-community/home-manager"><img src="https://img.shields.io/badge/home--manager-7D6B91?style=flat&colorA=222222" alt="home-manager"></a>
  <a href="https://github.com/NixOS/nixpkgs"><img src="https://img.shields.io/badge/nixpkgs-unstable-7D6B91?style=flat&colorA=222222" alt="nixpkgs unstable"></a>
  <a href="https://github.com/adrioui/nix/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-58A6FF?style=flat&colorA=222222" alt="License"></a>
</p>

Personal Apple Silicon Mac setup managed with **nix-darwin**, **home-manager**, and **Homebrew**. One repo, one flake, same machine every time.

**Stack:** nix-darwin system profile, home-manager user profile, Homebrew GUI apps, flake-first CLI, zsh + starship, AI coding agents, and a validation harness agents can actually run.

## Install

Requires [Nix](https://nixos.org/download/) with flakes enabled, and [Homebrew](https://brew.sh).

```sh
git clone git@github.com:adrioui/nix.git ~/.config/nix
cd ~/.config/nix
darwin-rebuild switch --flake path:$PWD#adri
```

After that, apply changes with:

```sh
darwin-rebuild switch --flake path:$PWD#adri
```

**Defaults:** user `adrifadilah`, host `adri`, `aarch64-darwin`.

**Homebrew:** `homebrew.onActivation.cleanup = "zap"` removes undeclared brews/casks on every switch. Read `modules/homebrew.nix` before installing anything ad hoc.

## Layout

| Path | Role |
| --- | --- |
| `flake.nix` | Entry: inputs, thin flake-parts + import-tree shell |
| `modules/hosts/adri.nix` | Host assembly: wires aspects into darwinConfigurations |
| `modules/` | Feature aspects: each file is a cross-cutting flake-parts module |
| `modules/base.nix` | Base darwin config (nix settings, users, system) |
| `modules/homebrew.nix` | Homebrew brews and casks |
| `modules/vpn.nix` | VPN: tailscale, netbird, cloudflared, protonvpn, cloudflare-warp |
| `modules/audio.nix` | Audio: puredata, plugdata |
| `modules/ai.nix` | AI agents: llm-agents, herdr, dsh |
| `modules/shell.nix` | Shell: zsh, starship, aliases, terminals |
| `modules/editor.nix` | Editors: neovim, helix, vim |
| `modules/dev.nix` | Dev tools: go, rust, node, direnv, nix tooling |
| `modules/media.nix` | Media: qbittorrent, ffmpeg, yt-dlp, obs |
| `modules/xcode.nix` | Xcode: XcodeBuildMCP |
| `pkgs/` | Custom package derivations |
| `AGENTS.md` | Agent context and non-negotiables |

## Quick Commands

| Alias | Command | Description |
| --- | --- | --- |
| `dr` | `sudo darwin-rebuild switch --flake path:$HOME/.config/nix#adri` | Apply changes |
| `drb` | `sudo darwin-rebuild build --flake path:$HOME/.config/nix#adri` | Build without applying |
| `dru` | `cd ~/.config/nix && nix flake update && sudo darwin-rebuild switch --flake path:$PWD#adri` | Update flake inputs and rebuild |
| `drn` | `cd ~/.config/nix && sudo darwin-rebuild build --flake path:$PWD#adri && nix store diff-closures /run/current-system ./result` | Preview what will change |
| `dre` | `cd ~/.config/nix && $EDITOR flake.nix` | Edit config |

## Adding Packages

### CLI Tool (via Nix)

Add to the relevant aspect module in `modules/` (e.g. `modules/dev.nix`):

```nix
{ pkgs, ... }: {
  flake.modules.darwin.dev = { ... }: {
    environment.systemPackages = [
      pkgs.your-package
    ];
  };
}
```

### GUI App (via Homebrew)

Add to `modules/homebrew.nix`:

```nix
{ ... }: {
  flake.modules.darwin.homebrew = { ... }: {
    homebrew = {
      casks = [
        "your-app"
      ];
    };
  };
}
```

### Home-manager Program

Add to the relevant aspect module (e.g. `modules/shell.nix`):

```nix
{ ... }: {
  flake.modules.homeManager.shell = { ... }: {
    programs.your-program.enable = true;
  };
}
```

## Native Validation

Everything is a first-class flake check — no shell wrapper needed.

```bash
# Format all Nix files
nix fmt --no-write-lock-file --no-update-lock-file

# Evaluate darwin system + home-manager derivations (fast feedback)
nix eval --raw --no-write-lock-file --no-update-lock-file .#darwinConfigurations.adri.system.drvPath
nix eval --raw --no-write-lock-file --no-update-lock-file .#darwinConfigurations.adri.config.home-manager.users.adrifadilah.home.activationPackage.drvPath

# Lint Nix files: nixfmt --check, deadnix, statix
# Audit flake.lock freshness
# Build the real darwin system + home-manager activation
nix flake check --no-write-lock-file --no-update-lock-file
```

Update inputs explicitly:

```sh
nix flake update
```

## Development

```bash
# Format all Nix files
nix fmt

# Run repo checks plus darwin/home-manager build validation
nix flake check

# Browse dependencies
nix-tree .#darwinConfigurations.adri.system
```

## Philosophy

Key ideas:

- Keep the system declarative and reproducible: Nix for what Nix is good at, Homebrew for GUI apps that prefer their own update path.
- Keep the repo flake-first: pinned nixpkgs, no legacy channels, no separate tracked `nix.conf`.
- Keep validation agent-friendly: `nix flake check` is the native read-only gate and never mutates `flake.lock`.
- Keep the package list explicit: unfree allowlist is narrow, Homebrew cleanup is `zap`, and package creep is visible in review.

## License

MIT. See [LICENSE](LICENSE).
