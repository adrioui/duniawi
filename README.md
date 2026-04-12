# Nix Configuration

Personal nix-darwin + home-manager configuration for macOS.

## Quick Commands

| Alias | Command | Description |
|-------|---------|-------------|
| `dr`  | `sudo darwin-rebuild switch --flake ~/.config/nix` | Apply changes |
| `drb` | `sudo darwin-rebuild build --flake ~/.config/nix` | Build without applying |
| `dru` | `nix flake update && sudo darwin-rebuild switch --flake .#adri` | Update flake inputs and rebuild |
| `drn` | `sudo darwin-rebuild build && nix store diff-closures` | Preview what will change |
| `dre` | `cd ~/.config/nix && $EDITOR flake.nix` | Edit config |

## Structure

```
├── flake.nix              # Entry point - inputs and darwin config
├── flake.lock             # Locked input versions
├── homebrew.nix           # GUI apps via Homebrew casks
├── hosts/
│   └── adri/
│       └── default.nix    # System packages, services, nix settings
├── home/
│   └── adrifadilah/
│       ├── default.nix    # User config, shell aliases
│       ├── opencode.nix   # AI assistant configuration
│       └── starship.nix   # Shell prompt
├── pkgs/
│   └── humanlayer.nix     # Custom package definition
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

# Run formatter + linters (deadnix/statix)
nix flake check

# Browse dependencies
nix-tree .#darwinConfigurations.adri.system
```

## Claude Code

This setup installs `claude` via `pkgs.claude-code`.

This repo also vendors HumanLayer’s `.claude/` workflow commands and agents.

```bash
# Initialize HumanLayer's Claude Code config in another repo
humanlayer claude init --all
```

## Applying Changes

```bash
# Build and switch (alias: dr)
sudo darwin-rebuild switch --flake ~/.config/nix

# Or from the repo directory
sudo darwin-rebuild switch --flake .#adri
```
