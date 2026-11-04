# Shared Modules

## The rule

A portable CLI tool is declared once in `modules/cli.nix` as a `homeManager`
aspect. Both users include it:

```nix
den.aspects.adrifadilah.includes = [ den.aspects.cli ];
den.aspects.adrioui.includes = [ den.aspects.cli ];
```

The user profile is the correct layer because both hosts run Home Manager and
the packages belong to the user, not the system. A host-level `homeManager`
block is inert; an `os` aspect puts packages in `environment.systemPackages`,
which is reserved for tools that must be visible to root or daemons.

## Package sources

| Package | Source | Why |
|---|---|---|
| Amp | `pkgs/amp-cli.nix` | upstream moves faster than nixpkgs; one cross-platform file |
| Pi | `nixpkgs-cli.pi-coding-agent` | current release without a custom derivation |
| OpenCode 2 | `pkgs/opencode2.nix` | prebuilt npm binary; avoids a large source build |
| Bend | `inputs.bend` | official flake; nixpkgs only carries Bend 1 |
| Herdr app/core | `pkgs/herdr-app.nix`, `pkgs/herdr-core.nix` | platform payloads in one file each |

`nixpkgs-cli` is pinned separately from `nixpkgs` and `nixpkgs-stable`. `t14`
runs its system from `nixpkgs-stable`, which lags Pi and OpenCode; `nixpkgs-cli`
gives both hosts the same current CLI versions without moving the NixOS base.

## Platform-only code

Keep platform payloads in `darwin`, `nixos`, or `homebrew` blocks. The shared
aspect must not contain a `mkIf isDarwin` path: that evaluates a macOS path on a
Linux host and defeats the boundary. Herdr's macOS `.app` and Linux ELF stay in
separate install branches inside one package file.

## Adding a tool

1. Add it to `modules/cli.nix` if it is portable.
2. Prefer `nixpkgs-cli` when the tool is current there.
3. Add a small `pkgs/<tool>.nix` only when nixpkgs lacks the tool or the
   upstream binary is the intended artifact.
4. Add a platform-only package to `modules/herdr.nix` or `modules/nixos-desktop.nix`.
5. Verify both package lists and build the Home Manager activation.

## Verification

```bash
nix flake check --all-systems --no-build
nix build --no-link .#checks.aarch64-darwin.home-manager-activation
nix build --no-link .#nixosConfigurations.t14.config.system.build.toplevel
nix build --no-link .#checks.x86_64-linux.nixos-home-manager-activation
```

The built t14 generation contains `opencode2-2.2.5`, `pi-coding-agent-1.5.0`,
`bend-2.0.39`, `amp-cli`, and `herdr-app`; the system contains `herdr-core`.
No generation contains the Herdr TUI, OpenCode V1, `cloudflared`, or the
Amp DeepSeek proxy.
