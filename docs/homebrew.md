# Homebrew

## Status

Homebrew owns GUI applications and a small number of formulae that are still better managed outside Nix. Nix owns system packages, services, and user configuration.

## Configuration

`modules/homebrew.nix` sets:

```nix
homebrew = {
  enable = true;
  enableZshIntegration = true;

  onActivation = {
    autoUpdate = false;
    cleanup = "zap";
    upgrade = false;
  };

  casks = [
    "anydesk"
    "dbeaver-community"
    "discord"
    "firefox"
    "font-hack-nerd-font"
    "ghostty"
    "obsidian"
    "orbstack"
    "steam"
    "typora"
    "warp"
    "yoink"
    "zen"
    "zed"
    "raycast"
    "codex"
  ];

  brews = [ "beads" ];
};
```

## Activation policy

`cleanup = "zap"` is intentional. Every brew and cask must be declared in this module or a feature aspect. Anything installed by hand is removed on the next `darwin-rebuild switch`.

`autoUpdate = false` and `upgrade = false` keep activation deterministic. A rebuild should not silently update Homebrew metadata or upgrade formulae. Update explicitly:

```bash
brew update
brew upgrade
```

or update the declared set and rebuild.

Assertions fail the build if either setting is changed:

```nix
assertion = !config.homebrew.enable || !config.homebrew.onActivation.autoUpdate;
assertion = !config.homebrew.enable || !config.homebrew.onActivation.upgrade;
```

## Adding an application

1. Add the cask or brew to the list.
2. Run `darwin-rebuild build --flake path:$PWD#adri`.
3. Run `sudo darwin-rebuild switch --flake path:$PWD#adri`.
4. Confirm it appears in `brew list --cask` or `brew list --formula`.

If the application is also packaged in nixpkgs, prefer the Nix package unless the cask is required for macOS integration, licensing, or auto-update behavior.

## Verification

```bash
brew bundle check --file /nix/store/*-homebrew-bundle/Brewfile
brew list --cask
brew list --formula
```

`brew bundle` runs during activation and prints the resolved dependency set.

## Security

* No secrets belong in Homebrew declarations.
* Casks can auto-update outside Nix; that is accepted for GUI apps.
* `zap` removes unmanaged state, so do not rely on manual `brew install` for anything persistent.
* Review new casks before adding them; they run vendor installers.

## Troubleshooting

| Symptom | Check |
|---|---|
| app disappears after rebuild | it was not declared; add it to `casks` or `brews` |
| activation updates unexpectedly | `autoUpdate` or `upgrade` was changed; restore both to `false` |
| cask install fails | run `brew install --cask <name>` manually to see the vendor error, then declare it |
| duplicate app | remove the cask or the Nix package, not both |
| brew command not found | `enableZshIntegration` must be true and the shell restarted |
| bundle check reports missing | run a switch, then re-check |
