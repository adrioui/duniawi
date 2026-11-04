# Architecture

## Status

The repository is a two-host flake built with `flake-parts`, `import-tree`, and `den`: `adri` on `aarch64-darwin` and `t14` on `x86_64-linux`. Features are written as den aspects, not host files.

## Layout

| Path | Role |
|---|---|
| `flake.nix` | inputs and `flake-parts.mkFlake` |
| `flake.lock` | pinned inputs |
| `modules/flake-parts.nix` | imports `den.flakeModule`, sets both systems |
| `modules/den.nix` | host/user entities, default includes, unfree allowlist |
| `modules/host.nix` | which aspects apply to `adri` and `adrifadilah` |
| `modules/t14.nix` | which aspects apply to `t14` and `adrioui` |
| `modules/base.nix` | Nix settings, platform, overlays, system identity |
| `modules/homebrew.nix` | Homebrew casks/brews and activation policy |
| `modules/vpn.nix` | Tailscale, Netbird, VPN casks |
| `modules/audio.nix` | Pure Data and externals |
| `modules/max.nix` | Max/MSP and `nn_tilde` package |
| `modules/cli.nix` | shared portable AI/CLI home packages |
| `modules/herdr.nix` | Herdr desktop app/core platform payloads |
| `modules/nixos-user.nix` | t14 user packages and GNOME settings |
| `modules/nixos-desktop.nix` | t14 GNOME, boot, and system packages |
| `modules/shell.nix` | zsh, starship, Keychain environment |
| `modules/editor.nix` | Vim, Neovim, Helix |
| `modules/dev.nix` | language toolchains and Nix tooling |
| `modules/media.nix` | media applications |
| `modules/browser.nix` | Helium |
| `modules/xcode.nix` | XcodeBuildMCP |
| `modules/per-system.nix` | packages, dev shell, checks, formatter |
| `pkgs/` | custom derivations and vendored sources |
| `docs/` | operator documentation |

## Entities

`modules/den.nix` declares two hosts:

```nix
den.hosts.aarch64-darwin.adri.users.adrifadilah = { };
den.hosts.x86_64-linux.t14.users.adrioui = { };
```

`adri` uses the unstable `nixpkgs`; `t14` instantiates with `nixpkgs-stable`.
Both users default to the `homeManager` class:

```nix
schema.user.classes = lib.mkDefault [ "homeManager" ];
```

Default includes add the user, primary-user, hostname, and unfree batteries to every resolved entity.

## Aspects

An aspect is a single concern with per-class configuration. For example:

```nix
den.aspects.shell = {
  darwin = { pkgs, ... }: { ... };
  homeManager = { config, ... }: { ... };
};
```

`modules/host.nix` selects which aspects apply:

```nix
den.aspects.adri.includes = [
  den.aspects.base
  den.aspects.homebrew
  den.aspects.vpn
  den.aspects.audio
  den.aspects.max
  den.aspects.herdr
  den.aspects.shell
  den.aspects.editor
  den.aspects.dev
  den.aspects.media
  den.aspects.xcode
  den.aspects.browser
];
```

The user include list is narrower and describes what the user itself needs. Host includes cover machine-wide services and packages; portable tools go in the user's `den.aspects.cli` include instead.

## Why this structure

* Adding or removing a feature is one include line.
* The same concern can configure `darwin`, `homeManager`, and `homebrew` without a host file.
* The host and user are data, not code.
* Feature modules stay small and independent.
* `import-tree` imports every `.nix` file under `modules/`, so no manual import list exists.

## Per-system outputs

`modules/per-system.nix` produces:

| Output | Purpose |
|---|---|
| `packages.xcodebuildmcp` | Darwin XcodeBuildMCP |
| `packages.default` | `xcodebuildmcp` on Darwin; `device-verify` on Linux |
| `devShells.default` | Nix formatter and linters |
| `checks.darwin-system` | full Darwin system derivation |
| `checks.home-manager-activation` | Darwin Home Manager activation |
| `checks.nixos-system` | full t14 NixOS system |
| `checks.nixos-home-manager-activation` | t14 Home Manager activation |
| `checks.t14-vm` | boot and activation proof for t14 |
| `checks.nixfmt` | formatting |
| `checks.deadnix` | unused Nix code |
| `checks.statix` | Nix lint |
| `checks.lockfile` | flake.lock freshness |
| `formatter` | `nixfmt-tree` |

## Inputs

| Input | Use |
|---|---|
| `nixpkgs` | base package set for `adri` |
| `nixpkgs-cli` | current Pi and OpenCode 2 for both hosts |
| `nixpkgs-stable` | NixOS base for `t14` |
| `darwin` | nix-darwin |
| `home-manager` | user configuration |
| `bend` | Bend 2 |
| `sops-nix` | secrets on t14 |
| `nixos-hardware` | ThinkPad hardware profile |
| `xcodebuildmcp` | pinned XcodeBuildMCP source |
| `flake-parts` | flake output structure |
| `import-tree` | module discovery |
| `den` | aspect engine |
| `helium` | browser package |

`nixpkgs-cli` is separate because `t14` runs `nixpkgs-stable`, which lags Pi and
OpenCode. It does not replace the host package sets.

## Adding a feature

1. Create `modules/<feature>.nix`.
2. Define `den.aspects.<feature>` with the classes it needs.
3. Add the aspect to `modules/host.nix` or `modules/t14.nix` for the host or user.
4. Add any custom package under `pkgs/`.
5. Run `nix flake check --all-systems --no-build`.
6. Build `darwin-rebuild build --flake path:$PWD#adri` and `nix build .#nixosConfigurations.t14.config.system.build.toplevel`.

## Verification

```bash
nix flake check --all-systems --no-build
nix eval .#darwinConfigurations.adri.config --json
nix eval .#nixosConfigurations.t14.config --json
nix build .#darwinConfigurations.adri.system --print-out-paths
nix build .#nixosConfigurations.t14.config.system.build.toplevel --print-out-paths
```

## Troubleshooting

| Symptom | Check |
|---|---|
| aspect not applied | add it to `den.aspects.adri.includes` or `den.aspects.adrifadilah.includes` |
| module not loaded | file must be under `modules/` and end in `.nix` |
| user has no home-manager config | `den.hosts...users.adrifadilah` must exist and the user class must include `homeManager` |
| unknown option | the class module may not be imported by the aspect engine |
| duplicate package | check system package, home package, and Homebrew lists |
