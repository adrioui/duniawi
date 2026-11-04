# AI Tools

## Status

Portable AI/CLI tools are declared once in `modules/cli.nix` as a
`homeManager` aspect and included by both users, `adrifadilah` on `adri` and
`adrioui` on `t14`. Platform-only payloads stay in `modules/herdr.nix` or
`modules/nixos-desktop.nix`.

The shared aspect covers Amp, OpenCode 2, Pi, Bend, and the Amp official-modes
activation. Herdr's terminal TUI and OpenCode V1 are removed; only the Herdr
desktop app/core remain. See [Shared modules](module-sharing.md) for the layer
and source rules.

## Shared packages

| Package | Source | Role |
|---|---|---|
| `amp-cli` | `pkgs/amp-cli.nix` | Amp CLI, pinned upstream build |
| `pi-coding-agent` | `nixpkgs-cli` | Pi 1.5.0 |
| `opencode2` | `pkgs/opencode2.nix` | OpenCode 2.2.5, prebuilt npm binary |
| `bend` | `inputs.bend` | Bend 2 |
| `official-modes` | `pkgs/amp-official-modes` | writable Amp plugin |

`nixpkgs-cli` is a pinned nixpkgs input used only for Pi and OpenCode 2. The
NixOS host uses `nixpkgs-stable` for its system, and stable lags both tools;
the separate input keeps the CLI current without moving the whole NixOS base.

`opencode2` is installed from the official `@opencode/cli` npm tarball for the
host platform and wrapped with `ripgrep`. The package name is `opencode2` so it
cannot collide with the removed V1 command.

`pkgs/amp-cli.nix` pins the upstream Amp build and supports both
`aarch64-darwin` and `x86_64-linux`:

```text
0.0.1793462430-g2650be
linux-x64:    sha256-vi8KehFrc1Xoexbgdk1wjs4VKpPeVb+m2oyIQU1F2YY=
darwin-arm64: sha256-oqACkG+PJeBI4DVldP9AbrvZEWFzMnxkqR1MYhr5DJE=
```

It is unfree and allowed narrowly in `modules/cli.nix`.

## Platform-only packages

| Package | Host | Location |
|---|---|---|
| `herdr-app`, `herdr-core` | `adri` | `environment.systemPackages` |
| `herdr-app` | `t14` | `home.packages` |
| `herdr-core` | `t14` | `environment.systemPackages` |

`pkgs/herdr-app.nix` and `pkgs/herdr-core.nix` each contain both the macOS and
Linux payload behind `stdenv.hostPlatform`. The Herdr TUI (`pkgs.herdr` /
`llm.herdr`) is not installed.

## Official modes

`modules/cli.nix` copies `pkgs/amp-official-modes/` to
`~/.config/amp/plugins/official-modes` during Home Manager activation. Amp
requires a writable plugin directory, so this cannot be a read-only Nix store
link.

## Keychain environment

`modules/shell.nix` exports keys at shell start from Keychain:

| Variable | Keychain service |
|---|---|
| `HCNOTE_API_KEY` | `hcnote` |
| `COMMANDCODE_API_KEY` | `commandcode-api-key` |
| `OPENCODE_API_KEY` | `opencode-api-key` |
| `OPENCODE_GO_API_KEY` | same as `OPENCODE_API_KEY` |

Values are read with `security find-generic-password` at runtime. They are not
written to Nix, plists, or logs.

## Verification

```bash
amp --version
opencode2 --version
pi --version
bend guide
herdr-core --version
```

Check the package list directly:

```bash
nix eval --json .#darwinConfigurations.adri.config.home-manager.users.adrifadilah.home.packages \
  --apply 'ps: map (p: p.name) ps'
nix eval --json .#nixosConfigurations.t14.config.home-manager.users.adrioui.home.packages \
  --apply 'ps: map (p: p.name) ps'
```

## Security

* API keys live in Keychain, never in the repository.
* Amp provider credentials are stored in Amp's encrypted cloud config.
* The unfree allowlist is narrow.
* The official modes plugin is vendored from the official Amp plugin cache and
  pinned in `pkgs/amp-official-modes/SOURCE.md`.
* No AI tool receives a repository-stored secret.

## Troubleshooting

| Symptom | Check |
|---|---|
| `amp` missing | rebuild and check `pkgs/amp-cli.nix` |
| `opencode2` missing | check `pkgs/opencode2.nix` and `nixpkgs-cli` |
| `pi` resolves to a Homebrew shim | remove the old `/opt/homebrew/bin/pi` wrapper |
| Amp model list only shows built-ins | restart Amp or run `plugins: reload`; check `amp plugins list` |
| Keychain variable empty | item name and login keychain |
