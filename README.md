# Adri's Nix Config

This is my personal macOS setup. It builds my system, my user environment, and my GUI apps from one Nix flake. I keep it here so my Mac is always one command away from being the same Mac again.

## How I Use It

My machine is an Apple Silicon Mac. I use nix-darwin for system-level stuff, home-manager for my user config, and Homebrew for GUI apps that prefer their own update path. The config is split by feature, not by layer, so a feature like VPN or audio lives in one place.

I'm currently learning DAW. PureData and Max/MSP both get the same neural audio models through the nn~ external. The RAVE models are part of the config, so they show up in both programs without me copying files around.

I also use AI coding agents heavily. The AI feature module installs pi, opencode, herdr, and dsh together, because they are part of the same workflow for me.

## What's In It

| Area | What I use |
| --- | --- |
| System | nix-darwin, Nix flakes, Homebrew |
| Shell | zsh, starship, kitty, alacritty |
| Editors | neovim, helix, vim |
| Browser | Helium |
| VPN | Tailscale, NetBird, cloudflared |
| Audio | PureData, nn~, RAVE models |
| Max/MSP | Max, nn~, RAVE models |
| AI agents | pi, opencode, herdr, dsh |
| Dev | go, rust, node, direnv, Nix tooling |
| Media | qbittorrent, ffmpeg, yt-dlp, OBS |
| Xcode | XcodeBuildMCP |

## Layout

```
flake.nix
modules/
├── den.nix               # host/user declarations, defaults, batteries
├── flake-parts.nix       # flake-parts + Den module
├── host.nix              # wires features into host and user aspects
├── base.nix              # Nix settings, overlays, host platform
├── homebrew.nix          # Homebrew apps
├── vpn.nix               # tailscale, netbird, cloudflared
├── audio.nix             # PureData + nn~ + RAVE models
├── max.nix               # Max/MSP + nn~ + RAVE models
├── ai.nix                # pi, opencode, herdr, dsh
├── shell.nix             # zsh, starship, aliases, terminals
├── editor.nix            # neovim, helix, vim
├── browser.nix           # Helium
├── dev.nix               # dev tools and Nix tooling
├── media.nix             # qbittorrent, ffmpeg, yt-dlp
├── xcode.nix             # XcodeBuildMCP
├── dsh.nix               # dsh-nix profile management
└── per-system.nix        # checks, packages, dev shell
pkgs/
```

Every file under `modules/` is a feature module. flake-parts and import-tree load them automatically. I never maintain an import list.

## Commands I Actually Run

| Alias | What it does |
| --- | --- |
| `dr` | Apply changes |
| `drb` | Build without applying |
| `dru` | Update inputs and rebuild |
| `drn` | Preview what will change |
| `dre` | Open the config for editing |

Full validation before I apply:

```sh
nix fmt --no-write-lock-file --no-update-lock-file
nix flake check --no-write-lock-file --no-update-lock-file
darwin-rebuild build --flake path:$PWD#adri
```

## Things To Remember

- Homebrew cleanup is `zap`. If I install something with `brew` but forget to declare it here, the next rebuild deletes it.
- Unfree packages are limited to a small allowlist in `modules/nixpkgs.nix`.
- Max/MSP models live in `~/Documents/Max 9/Packages/nn_tilde`. In Max, an `nn~` object loads them by name: `isis`, `percussion`, or `ordinario_1024`.
- `flake.lock` is read-only during validation. I only change it with `nix flake update`.
