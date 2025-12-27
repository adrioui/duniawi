# Nix Configuration

Personal nix-darwin + home-manager configuration for macOS.

## Quick Commands

| Alias | Command | Description |
|-------|---------|-------------|
| `dr`  | `darwin-rebuild switch --flake ~/.config/nix` | Apply changes |
| `drb` | `darwin-rebuild build --flake ~/.config/nix` | Build without applying |
| `dru` | `nix flake update && darwin-rebuild switch` | Update flake inputs and rebuild |
| `drn` | `darwin-rebuild build && nix store diff-closures` | Preview what will change |
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
environment.systemPackages = with pkgs; [
  your-package
];
```

### GUI App (via Homebrew)
Add to `homebrew.nix`:
```nix
homebrew.casks = [
  "your-app"
];
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

# Check for issues
statix check .
deadnix .

# Browse dependencies
nix-tree .#darwinConfigurations.adri.system
```

## Applying Changes

```bash
# Build and switch (alias: dr)
darwin-rebuild switch --flake ~/.config/nix

# Or from the repo directory
darwin-rebuild switch --flake .#adri
```
