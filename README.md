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

**Homebrew:** `homebrew.onActivation.cleanup = "zap"` removes undeclared brews/casks on every switch. Read `homebrew.nix` before installing anything ad hoc.

## Layout

| Path | Role |
| --- | --- |
| `flake.nix` | Entry: inputs, unfree allowlist, outputs, checks |
| `hosts/adri/default.nix` | System packages, services, nix-daemon settings |
| `home/adrifadilah/default.nix` | User packages, shell, env, aliases |
| `homebrew.nix` | Homebrew brews and casks |
| `pkgs/` | Custom package derivations |
| `hack/feedback_loop.sh` | Preferred validation harness |
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

Add to `hosts/adri/default.nix`:

```nix
environment.systemPackages = [
  pkgs.your-package
];
```

### GUI App (via Homebrew)

Add to `homebrew.nix`:

```nix
homebrew = {
  casks = [
    "your-app"
  ];
};
```

### Home-manager Program

Add to `home/adrifadilah/default.nix`:

```nix
programs.your-program.enable = true;
```

Or create a new module file and import it.

## Feedback Loop

Use the feedback loop script for quick, text-first validation.

```bash
# Fast inner loop: format and evaluate darwin + home-manager derivations
hack/feedback_loop.sh fast

# Read-only repo checks: nixfmt + deadnix + statix
hack/feedback_loop.sh lint

# Full configured checks (linters + darwin + home-manager builds)
hack/feedback_loop.sh check

# Audit flake.lock freshness/support
hack/feedback_loop.sh lock

# Build playground
hack/feedback_loop.sh dry-run
hack/feedback_loop.sh build
hack/feedback_loop.sh diff

# Package experiment
hack/feedback_loop.sh package kitty
```

Validation commands are lockfile-read-only by default. Update inputs explicitly:

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
- Keep validation agent-friendly: `hack/feedback_loop.sh` gives fast, read-only feedback without mutating `flake.lock`.
- Keep the package list explicit: unfree allowlist is narrow, Homebrew cleanup is `zap`, and package creep is visible in review.

## License

MIT. See [LICENSE](LICENSE).
