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

Personal setup for an Apple Silicon Mac. Uses nix-darwin, home-manager, and Homebrew. One config file tree, one command to rebuild.

**What's in it:** system packages, user dotfiles, Homebrew GUI apps, zsh aliases, AI coding agents, audio tools (PureData, Max/MSP with neural audio models), and a validation suite that checks everything before you apply.

## Quick Start

You need [Nix](https://nixos.org/download/) with flakes, and [Homebrew](https://brew.sh).

```sh
git clone git@github.com:adrioui/nix.git ~/.config/nix
cd ~/.config/nix
darwin-rebuild switch --flake path:$PWD#adri
```

After that, rebuild with the same command.

**Defaults:** user `adrifadilah`, host `adri`, `aarch64-darwin`.

**Homebrew note:** `homebrew.onActivation.cleanup = "zap"` removes anything you install outside the config. See `modules/homebrew.nix` before running `brew install` by hand.

## Layout

| Path | What it does |
| --- | --- |
| `flake.nix` | Entry point: lists inputs, hands off to modules |
| `modules/hosts/adri.nix` | Wires all features together for this machine |
| `modules/base.nix` | Core system settings: Nix config, users, host platform |
| `modules/homebrew.nix` | Homebrew apps and packages |
| `modules/vpn.nix` | VPN tools: tailscale, netbird, cloudflared |
| `modules/audio.nix` | Audio: PureData with nn~ and RAVE models |
| `modules/max.nix` | Max/MSP with nn~ external and RAVE models |
| `modules/ai.nix` | AI coding agents: pi, opencode, herdr, dsh |
| `modules/shell.nix` | Shell: zsh, starship, aliases, terminals |
| `modules/editor.nix` | Editors: neovim, helix, vim |
| `modules/dev.nix` | Dev tools: go, rust, node, direnv, nix tooling |
| `modules/media.nix` | Media tools: qbittorrent, ffmpeg, yt-dlp, obs |
| `modules/xcode.nix` | Xcode helper: XcodeBuildMCP |
| `pkgs/` | Custom packages (PureData with externals, nn~ Max, RAVE models) |
| `AGENTS.md` | Agent context: conventions and rules for AI tools |

## Quick Commands

| Alias | Command | What it does |
| --- | --- | --- |
| `dr` | `sudo darwin-rebuild switch --flake path:$HOME/.config/nix#adri` | Apply changes |
| `drb` | `sudo darwin-rebuild build --flake path:$HOME/.config/nix#adri` | Build without applying |
| `dru` | `cd ~/.config/nix && nix flake update && sudo darwin-rebuild switch --flake path:$PWD#adri` | Update inputs and rebuild |
| `drn` | `cd ~/.config/nix && sudo darwin-rebuild build --flake path:$PWD#adri && nix store diff-closures /run/current-system ./result` | Preview what will change |
| `dre` | `cd ~/.config/nix && $EDITOR flake.nix` | Edit the config |

## Adding Stuff

### CLI tool (via Nix)

Add it to the right feature module in `modules/`. For example, in `modules/dev.nix`:

```nix
{ pkgs, ... }: {
  flake.modules.darwin.dev = { ... }: {
    environment.systemPackages = [ pkgs.your-package ];
  };
}
```

### GUI app (via Homebrew)

Add it to `modules/homebrew.nix`:

```nix
{ ... }: {
  flake.modules.darwin.homebrew = { ... }: {
    homebrew.casks = [ "your-app" ];
  };
}
```

### Home-manager program

Add it to the right feature module. For example, in `modules/shell.nix`:

```nix
{ ... }: {
  flake.modules.homeManager.shell = { ... }: {
    programs.your-program.enable = true;
  };
}
```

## Max/MSP and Neural Audio

This setup includes:

- **Max/MSP** (via Homebrew cask `cycling74-max`).
- **nn~ for Max/MSP**: the nn~ external loads TorchScript audio models. Installed into `~/Documents/Max 9/Packages/nn_tilde`.
- **RAVE models**: three pretrained models (isis, percussion, vschaos2) included in the nn~ package so you can use them right away.

Open Max, create an `nn~` object, and try `isis`, `percussion`, or `ordinario_1024` as the model name.

The PureData side (in `modules/audio.nix`) has the same models available through its own nn~ external.

## Validation

Every change is checked before it gets applied.

```bash
# Format all files
nix fmt --no-write-lock-file --no-update-lock-file

# Lint, check lockfile, build the real system and home environment
nix flake check --no-write-lock-file --no-update-lock-file

# Update inputs
nix flake update
```

These commands are read-only regarding `flake.lock` except for `nix flake update`.

## Philosophy

- Declarative and reproducible. Nix for packages and services, Homebrew for GUI apps.
- Flake-only. No legacy channels, no separate nix.conf.
- Package list is explicit. Unfree packages are in a narrow allowlist. Homebrew cleanup is `zap`.
- Validation is agent-friendly. `nix flake check` is the one gate.

## License

MIT. See [LICENSE](LICENSE).