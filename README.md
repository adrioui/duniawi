# Adri's Nix Config

A personal macOS setup that rebuilds itself from one config repo. It manages system packages, user settings, Homebrew apps, and audio tools.

Built on [nix-darwin](https://github.com/LnL7/nix-darwin), [home-manager](https://github.com/nix-community/home-manager), [flake-parts](https://flake.parts), and [Homebrew](https://brew.sh).

## Quick Start

You need [Nix](https://nixos.org/download/) with flakes enabled, and [Homebrew](https://brew.sh).

```sh
git clone git@github.com:adrioui/nix.git ~/.config/nix
cd ~/.config/nix
darwin-rebuild switch --flake path:$PWD#adri
```

To apply later changes, run the same command again.

**Defaults:** user `adrifadilah`, host `adri`, `aarch64-darwin`.

## What's Inside

This repo sets up one machine. The config is split into small feature files, each in `modules/`. Features include:

- **Base system.** Nix settings, users, and host platform.
- **Homebrew.** GUI apps that prefer their own update path.
- **VPN.** Tailscale, NetBird, and Cloudflare tools.
- **Audio.** PureData with the nn~ external and RAVE neural models.
- **Max/MSP.** Max with the nn~ external and the same RAVE models.
- **AI agents.** pi, opencode, herdr, and dsh.
- **Shell.** zsh, starship, aliases, and terminal apps.
- **Editors.** neovim, helix, and vim.
- **Dev tools.** go, rust, node, direnv, and Nix tooling.
- **Media.** qbittorrent, ffmpeg, yt-dlp, and OBS.
- **Xcode.** XcodeBuildMCP helper.

## Layout

| Path | What it does |
| --- | --- |
| `flake.nix` | Entry point. Lists inputs and hands off to the modules. |
| `modules/hosts/adri.nix` | Wires all features together for this machine. |
| `modules/base.nix` | Core system settings: Nix config, users, host platform. |
| `modules/homebrew.nix` | Homebrew apps and packages. |
| `modules/vpn.nix` | Tailscale, NetBird, cloudflared. |
| `modules/audio.nix` | PureData with nn~ and RAVE models. |
| `modules/max.nix` | Max/MSP with nn~ and RAVE models. |
| `modules/ai.nix` | AI coding agents. |
| `modules/shell.nix` | zsh, starship, aliases, terminals. |
| `modules/editor.nix` | neovim, helix, vim. |
| `modules/dev.nix` | Dev tools and Nix tooling. |
| `modules/media.nix` | qbittorrent, ffmpeg, yt-dlp, OBS. |
| `modules/xcode.nix` | XcodeBuildMCP. |
| `modules/options.nix` | Shared values like username and system. |
| `modules/nixpkgs.nix` | Nixpkgs config and the unfree allowlist. |
| `modules/per-system.nix` | Checks, packages, and the dev shell. |
| `pkgs/` | Custom packages built from source. |
| `AGENTS.md` | Rules and context for AI tools working here. |

Every `.nix` file under `modules/` is a feature module. They are loaded automatically. There is no import list to maintain.

## Common Tasks

### Add a CLI tool

Add it to the matching feature module in `modules/`. For a dev tool, edit `modules/dev.nix`:

```nix
{ pkgs, ... }: {
  flake.modules.darwin.dev = { ... }: {
    environment.systemPackages = [ pkgs.your-package ];
  };
}
```

### Add a GUI app

Add it to `modules/homebrew.nix`:

```nix
{ ... }: {
  flake.modules.darwin.homebrew = { ... }: {
    homebrew.casks = [ "your-app" ];
  };
}
```

### Add a home-manager program

Add it to the matching feature module. For a shell program, edit `modules/shell.nix`:

```nix
{ ... }: {
  flake.modules.homeManager.shell = { ... }: {
    programs.your-program.enable = true;
  };
}
```

### Add a new feature

Create a new file in `modules/`, for example `modules/gaming.nix`. Define what it should do for the system and for the user:

```nix
{
  flake.modules.darwin.gaming = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.steam ];
  };
}
```

Then add the feature name to the module lists in `modules/hosts/adri.nix`. It is now part of the machine.

## Max/MSP and Neural Audio

This setup includes Max/MSP through Homebrew, plus the nn~ external for Max. The nn~ external loads neural audio models.

Three RAVE models are included: `isis`, `percussion`, and `ordinario_1024`. They are installed into `~/Documents/Max 9/Packages/nn_tilde` so Max can find them.

To use one, open Max, create an `nn~` object, and type a model name like `isis`.

PureData has the same setup through its own nn~ external. The models work in both programs.

## Homebrew Note

`homebrew.onActivation.cleanup = "zap"` is on. Anything installed with `brew install` that is not declared in this repo gets removed on the next rebuild.

Check `modules/homebrew.nix` before installing anything by hand.

## Unfree Packages

A small allowlist of unfree packages lives in `modules/nixpkgs.nix`. Only packages on that list are allowed. This keeps package creep visible in code review.

## Keeping It Working

Every change is checked before it is applied.

```bash
# Format all files
nix fmt --no-write-lock-file --no-update-lock-file

# Lint, check the lockfile, and build the real system and home environment
nix flake check --no-write-lock-file --no-update-lock-file

# Build without applying
darwin-rebuild build --flake path:$PWD#adri

# Apply
darwin-rebuild switch --flake path:$PWD#adri
```

Update inputs explicitly:

```sh
nix flake update
```

These commands do not touch `flake.lock` except for `nix flake update`.

## Everyday Aliases

The zsh config in `modules/shell.nix` defines these:

| Alias | What it does |
| --- | --- |
| `dr` | Apply changes |
| `drb` | Build without applying |
| `dru` | Update inputs and rebuild |
| `drn` | Preview what will change |
| `dre` | Open the config for editing |

## License

MIT. See [LICENSE](LICENSE).