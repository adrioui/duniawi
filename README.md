# Nix Configuration

Personal nix-darwin + home-manager configuration for macOS.

## Quick Commands

| Alias | Command | Description |
|-------|---------|-------------|
| `dr`  | `sudo darwin-rebuild switch --flake path:$HOME/.config/nix#adri` | Apply changes |
| `drb` | `sudo darwin-rebuild build --flake path:$HOME/.config/nix#adri` | Build without applying |
| `dru` | `cd ~/.config/nix && nix flake update && sudo darwin-rebuild switch --flake path:$PWD#adri` | Update flake inputs and rebuild |
| `drn` | `cd ~/.config/nix && sudo darwin-rebuild build --flake path:$PWD#adri && nix store diff-closures /run/current-system ./result` | Preview what will change |
| `dre` | `cd ~/.config/nix && $EDITOR flake.nix` | Edit config |

## Structure

```
├── AGENTS.md              # Repo instructions for coding agents and contributors
├── flake.nix              # Entry point - inputs and darwin config
├── flake.lock             # Locked input versions
├── homebrew.nix           # GUI apps via Homebrew casks
├── hack/
│   └── feedback_loop.sh   # Agent-friendly Nix validation harness
├── hosts/
│   └── adri/
│       └── default.nix    # System packages, services, nix settings
├── home/
│   └── adrifadilah/
│       ├── default.nix    # User config, shell aliases
│       └── starship.nix   # Shell prompt
├── pkgs/                  # Custom package definitions when needed
└── thoughts/              # Research and planning documents
```

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

## Development

```bash
# Format all Nix files
nix fmt

# Run repo checks plus darwin/home-manager build validation
nix flake check

# Browse dependencies
nix-tree .#darwinConfigurations.adri.system
```

## Agent Workflow

- Read `AGENTS.md` before making structural changes.
- Prefer `hack/feedback_loop.sh fast` while iterating, `hack/feedback_loop.sh lint` for a quick read-only repo check, and `hack/feedback_loop.sh check` before committing.
- `nix flake check` / `hack/feedback_loop.sh check` validate the real nix-darwin system derivation and Home Manager activation package in addition to repo linters.
- Feedback-loop validation commands are lockfile-read-only by default (`--no-update-lock-file --no-write-lock-file`) so agents do not mutate `flake.lock` unless the operator explicitly runs `nix flake update`.
- Use `hack/feedback_loop.sh lock` when touching `flake.lock` or reviewing input freshness.
- Keep Nix daemon settings in `hosts/adri/default.nix`; avoid reintroducing a standalone `nix.conf` source of truth.
- Keep the unfree-package allowlist in `flake.nix` explicit and narrow.
- The repo is flake-first: `nix run nixpkgs#...`, `nix shell nixpkgs#...`, and `<nixpkgs>` now resolve against the same pinned `nixpkgs` input via declarative `nix.registry` / `nix.nixPath` settings.
- Legacy Nix channels are disabled to avoid a second mutable package source.
- nix-darwin assertions now machine-check that flake-first policy too: channels stay disabled, the system `nix.registry.nixpkgs` entry stays pinned to the locked input, `nix.nixPath` stays aligned, and `experimental-features` still include `nix-command flakes`.
- Keep Homebrew activation idempotent. Update Brew metadata explicitly instead of on every rebuild; nix-darwin assertions fail early if `autoUpdate` or `upgrade` are re-enabled.
- Use explicit `path:` flake refs for `darwin-rebuild` commands to avoid local Git ownership surprises under `sudo`.
- Rebuild failures should now include richer traces and a longer log tail via declarative Nix settings in `hosts/adri/default.nix`.
- Custom launchd jobs should prefer package store paths or generated scripts over `/run/current-system/sw/bin/...` so runtime command resolution stays declarative.

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

## Coding Agents

This setup keeps the coding-agent toolchain intentionally small and installs only:

- `pi` (wrapped so user-scoped npm extensions live under `~/.pi/npm-global`)
- `codex`

Update them by refreshing flake inputs with `nix flake update` or the `dru` alias.

## Applying Changes

```bash
# Build and switch (alias: dr)
sudo darwin-rebuild switch --flake path:$HOME/.config/nix#adri

# Or from the repo directory
sudo darwin-rebuild switch --flake path:$PWD#adri
```
