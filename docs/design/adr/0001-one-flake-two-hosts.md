# ADR-0001: One flake, two hosts

- Status: Proposed
- Date: 2026-10-31
- Deciders: repository owner
- Related: Approval 4, `docs/design/domain.md`, `docs/design/compatibility.md`

## Context

`duniawi` currently evaluates one `aarch64-darwin` host (`adri`) with
nix-darwin, `flake-parts`, `import-tree`, and Den. A second machine, a Lenovo
ThinkPad T14 Gen 2i, runs NixOS 26.05 on `x86_64-linux`. The old Fedora home
must be migrated into that machine.

A fork or a second repository would duplicate aspects, secrets policy, CI, and
documentation, and would make cross-platform drift likely. A single flake with
two hosts keeps shared code reviewable and gives one lockfile.

## Decision

Keep one flake in `adrioui/duniawi` and add the NixOS host as a second Den
host:

```nix
systems = [ "aarch64-darwin" "x86_64-linux" ];

den.hosts.aarch64-darwin.adri.users.adrifadilah = { };
den.hosts.x86_64-linux.t14.users.adrioui = { };
```

`t14` is the Den host name; its network `hostName` remains `nixos`. The Darwin
output remains `darwinConfigurations.adri`; the NixOS output is
`nixosConfigurations.t14`.

## Consequences

- Shared aspects must have explicit `darwin` / `nixos` / `homeManager` class
  blocks. A shared block must not import Darwin-only packages.
- The Darwin host must keep evaluating and building. Any unexpected Darwin
  drv-path change is a regression.
- CI must cover both systems; a Linux-only green build is insufficient.
- `flake.lock` is shared. Only intentional, documented input changes are
  allowed; no `--impure`, channels, or unpinned inputs.
- The NixOS host is not a fork; NixOS-specific modules live in the same
  repository and are reviewed with the Darwin changes.

## Alternatives considered

| Alternative | Why rejected |
|---|---|
| Fork `duniawi` for NixOS | duplicate aspects, secrets policy, CI, and drift |
| Separate NixOS flake in another repo | two lockfiles and no shared review |
| NixOS-only rewrite | breaks the existing Darwin host |
| Home Manager standalone on NixOS | no declarative system, boot, or services |

## Evidence

- `modules/flake-parts.nix` currently has `systems = [ "aarch64-darwin" ]`.
- Darwin baseline: `darwinConfigurations.adri.config.system.build.toplevel.drvPath`
  `/nix/store/0asmm5isa43s60wxxdmi0y03wmywap8h-darwin-system-26.11.4cff07d.drv`.
- NixOS baseline: `/nix/store/04q282abf92ypcwxqarbwzvrym4fvbcv-nixos-system-nixos-26.05.13164.6f06d204d8f2`.
