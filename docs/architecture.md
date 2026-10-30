# Architecture

## Status

The repository is a single `aarch64-darwin` flake built with `flake-parts`, `import-tree`, and `den`. Features are written as den aspects, not host files.

## Layout

| Path | Role |
|---|---|
| `flake.nix` | inputs and `flake-parts.mkFlake` |
| `flake.lock` | pinned inputs |
| `modules/flake-parts.nix` | imports `den.flakeModule`, sets `aarch64-darwin` |
| `modules/den.nix` | host/user entities, default includes, unfree allowlist |
| `modules/host.nix` | which aspects apply to `adri` and `adrifadilah` |
| `modules/base.nix` | Nix settings, platform, overlays, system identity |
| `modules/homebrew.nix` | Homebrew casks/brews and activation policy |
| `modules/vpn.nix` | Tailscale, Netbird, VPN casks, cloudflared |
| `modules/audio.nix` | Pure Data and externals |
| `modules/max.nix` | Max/MSP and `nn_tilde` package |
| `modules/ai.nix` | Amp, Claude Code, OpenCode, Cursor, Pi, Herdr |
| `modules/amp-deepseek.nix` | Amp DeepSeek proxy, tunnel, official modes |
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

`modules/den.nix` declares:

```nix
den.hosts.aarch64-darwin.adri.users.adrifadilah = { };
```

This gives the pipeline one host (`adri`) and one user (`adrifadilah`). The user defaults to the `homeManager` class:

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
  den.aspects.ai
  den.aspects.ampDeepseek
  den.aspects.shell
  den.aspects.editor
  den.aspects.dev
  den.aspects.media
  den.aspects.xcode
  den.aspects.browser
];
```

The user include list is narrower and describes what the user itself needs. Host includes cover machine-wide services and packages.

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
| `packages.xcodebuildmcp` | XcodeBuildMCP |
| `packages.default` | XcodeBuildMCP |
| `devShells.default` | Nix formatter and linters |
| `checks.darwin-system` | full system derivation |
| `checks.home-manager-activation` | home-manager activation derivation |
| `checks.nixfmt` | formatting |
| `checks.deadnix` | unused Nix code |
| `checks.statix` | Nix lint |
| `checks.lockfile` | flake.lock freshness |
| `checks.amp-deepseek` | proxy contract tests |
| `formatter` | `nixfmt-tree` |

## Inputs

| Input | Use |
|---|---|
| `nixpkgs` | package set |
| `darwin` | nix-darwin |
| `home-manager` | user configuration |
| `llm-agents` | AI CLI packages |
| `xcodebuildmcp` | pinned XcodeBuildMCP source |
| `flake-parts` | flake output structure |
| `import-tree` | module discovery |
| `den` | aspect engine |
| `helium` | browser package |

The `nixpkgs` input follows through `darwin` and `home-manager`. `helium` follows `nixpkgs`.

## Adding a feature

1. Create `modules/<feature>.nix`.
2. Define `den.aspects.<feature>` with the classes it needs.
3. Add the aspect to `modules/host.nix` for the host or user.
4. Add any custom package under `pkgs/`.
5. Run `nix flake check --no-write-lock-file --no-update-lock-file`.
6. Build the system with `darwin-rebuild build --flake path:$PWD#adri`.

## Verification

```bash
nix flake check --no-write-lock-file --no-update-lock-file
nix eval .#darwinConfigurations.adri.config --json
nix build .#darwinConfigurations.adri.system --print-out-paths
```

## Troubleshooting

| Symptom | Check |
|---|---|
| aspect not applied | add it to `den.aspects.adri.includes` or `den.aspects.adrifadilah.includes` |
| module not loaded | file must be under `modules/` and end in `.nix` |
| user has no home-manager config | `den.hosts...users.adrifadilah` must exist and the user class must include `homeManager` |
| unknown option | the class module may not be imported by the aspect engine |
| duplicate package | check system package, home package, and Homebrew lists |
