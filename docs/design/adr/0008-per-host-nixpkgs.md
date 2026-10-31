# ADR-0008: Pin `t14` to NixOS 26.05 while Darwin stays on unstable

- Status: Accepted as an implementation decision
- Date: 2026-10-31
- Deciders: repository owner
- Related: `docs/design/research.md`, `docs/design/baseline.md`,
  `docs/design/packages.md`

## Context

The flake originally had one root `nixpkgs` input on `nixpkgs-unstable`, locked
at `8825bebf6324e0579d012936eff73379af284b6d` (`26.11pre-git`); `llm-agents`
carried its own `b6c98e9e6633ee64753b594ff4a5febf0367fc00`. Darwin evaluates
against the root input and must keep working.

The NixOS laptop already runs `26.05.13164.6f06d204d8f2`. The `nixos-26.05`
branch head at the time of this change is the same commit,
`6f06d204d8f2d8761d9da78778745974a3216381`. Using the shared unstable input for
`t14` would combine the home migration with a distribution upgrade to 26.11.

## Decision

Add two pinned inputs:

```nix
nixpkgs-stable.url = "github:NixOS/nixpkgs/6f06d204d8f2d8761d9da78778745974a3216381";
home-manager-stable.url = "github:nix-community/home-manager/24f2190587513b9c2f73db112a17844ae912d965";
home-manager-stable.inputs.nixpkgs.follows = "nixpkgs-stable";
```

Use `inputs.nixpkgs-stable.lib.nixosSystem` as the `t14` host instantiation and
`inputs.home-manager-stable.nixosModules.home-manager` as its Home Manager
module. Darwin continues to use `inputs.nixpkgs` and `inputs.home-manager`.

## Consequences

- The OS packages on `t14` stay at the release the machine already runs.
- Darwin's package set and current build behavior are not moved to 26.05.
- The flake now intentionally carries two nixpkgs revisions. This is visible in
  `flake.lock` and must be explained in the PR.
- `llm-agents`, `helium`, `nixos-hardware`, and `sops-nix` are pinned
  separately. `llm-agents` and `helium` packages come from those inputs, not
  from the host nixpkgs, so their closures remain self-contained.
- A future OS upgrade is a separate change: update `nixpkgs-stable` and
  `home-manager-stable`, run the VM tests, and only then switch the live host.
- `system.stateVersion` remains `26.05`; it is not changed by this ADR.

## Alternatives considered

| Alternative | Why rejected |
|---|---|
| Use only the existing unstable input | combines migration with a 26.11 upgrade |
| Move Darwin to 26.05 too | unrelated Darwin regression risk |
| Use a channel or `builtins.fetchTarball` | violates the pinned-input rule |
| Use `nixos-unstable` “because it is newer” | newer is not safer during a migration |

## Verification

- `nix eval --raw .#nixosConfigurations.t14.config.nixpkgs.hostPlatform.system`
  → `x86_64-linux`.
- `nix eval --json .#nixosConfigurations.t14.config.system.stateVersion` →
  `"26.05"`.
- `nix build .#nixosConfigurations.t14.config.system.build.toplevel` succeeds.
- `nix eval --raw .#darwinConfigurations.adri.config.nixpkgs.hostPlatform.system`
  → `aarch64-darwin`.
- The `flake.lock` diff shows only the documented pinned inputs.
