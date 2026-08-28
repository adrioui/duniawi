# Adri's Nix Config

Personal macOS setup for my Apple Silicon Mac. Managed with nix-darwin, home-manager, Homebrew, and flake-parts.

## Machine

| | |
| --- | --- |
| Host | `adri` |
| User | `adrifadilah` |
| System | `aarch64-darwin` |
| Shell | zsh + starship |
| Editors | neovim, helix, vim |
| Audio | PureData + Max/MSP with RAVE models |

## Features

- **VPN.** Tailscale, NetBird, cloudflared.
- **Audio.** PureData with the nn~ external and RAVE models.
- **Max/MSP.** Max with the nn~ external and the same RAVE models.
- **AI agents.** pi, opencode, herdr, dsh.
- **Shell.** zsh, starship, aliases, kitty, alacritty.
- **Editors.** neovim, helix, vim.
- **Dev.** go, rust, node, direnv, and Nix tooling.
- **Media.** qbittorrent, ffmpeg, yt-dlp, OBS.
- **Xcode.** XcodeBuildMCP.

## Layout

```
flake.nix
modules/
├── hosts/adri.nix
├── base.nix
├── homebrew.nix
├── vpn.nix
├── audio.nix
├── max.nix
├── ai.nix
├── shell.nix
├── editor.nix
├── dev.nix
├── media.nix
├── xcode.nix
├── options.nix
├── nixpkgs.nix
└── per-system.nix
pkgs/
```

Every file in `modules/` is a feature module. They are loaded automatically through flake-parts and import-tree.

## Commands

| Alias | What it does |
| --- | --- |
| `dr` | Apply changes |
| `drb` | Build without applying |
| `dru` | Update inputs and rebuild |
| `drn` | Preview what will change |
| `dre` | Edit the config |

## Notes

- Homebrew cleanup is `zap`. Anything installed outside the config is removed on the next rebuild.
- Unfree packages are limited to the allowlist in `modules/nixpkgs.nix`.
- Max/MSP models are installed to `~/Documents/Max 9/Packages/nn_tilde`. In Max, create an `nn~` object and use `isis`, `percussion`, or `ordinario_1024`.