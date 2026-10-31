# ADR-0002: Den aspects, classes, and user-level NixOS metadata

- Status: Accepted as an implementation decision
- Date: 2026-10-31
- Deciders: repository owner
- Related: `docs/design/graph.md`, `docs/design/compatibility.md`, pinned Den `ba9ee3a5`

## Context

The repository already uses Den with aspects, classes, batteries, and
`import-tree`. The NixOS host must reuse as much behavior as possible without
turning every aspect into a pile of `if darwin then ... else ...` branches.
The old home is owned by uid/gid `1000:1000`; the new account needs that
mapping, but the mapping is host-specific.

## Decision

Use Den as the only composition mechanism:

- `den.hosts.<system>.<name>` for `adri` and `t14`.
- `den.aspects.<name>` with `darwin`, `nixos`, and `homeManager` class blocks.
- `den.aspects.adri` / `den.aspects.t14` for host includes.
- `den.aspects.adrifadilah` / `den.aspects.adrioui` for user includes.
- `den.aspects.adrioui.nixos` for uid 1000, gid 1000, group `adrioui`, shell,
  and extra groups. `adrioui` exists only on `t14`, so a host-qualified aspect
  would add a second name without adding a second host; the implementation
  keeps one user aspect.
- Host-qualified aspect naming remains available in Den, but is not used in
  this change. The earlier design considered it and the implementation
  simplified to one user aspect to avoid shadowing/duplication.
- Built-in batteries: `define-user`, `primary-user`, `hostname`, `unfree`, and
  `home-manager`. No custom policy or quirk is introduced.
- No custom `den.schema` metadata is introduced. `uid`/`gid` are ordinary
  NixOS user options, which is easier to audit and test.

The NixOS proxy lifecycle is a separate aspect, `ampDeepseekNixos`, included by
the `adrioui` user. The Darwin `ampDeepseek` aspect remains Darwin-only.

## Consequences

- Shared code is explicit about class. Darwin-only packages and launchd units
  cannot leak into NixOS evaluation.
- The numeric mapping is explicit in `adrioui.nixos`; a future user on a
  different host must choose its own mapping rather than inheriting one.
- Den API usage must match the pinned revision. The design was checked against
  `ba9ee3a5e8ad1f77ba8e0341b224c4a1d5999787`.
- No Effect/TypeScript, custom class, custom policy, or ad-hoc module loader is
  introduced.
- The built-in home-manager battery routes `home-manager.users.adrioui` under
  `nixosConfigurations.t14`.

## Alternatives considered

| Alternative | Why rejected |
|---|---|
| Plain NixOS modules with `mkIf` | loses Den entity/aspect composition and reviewability |
| One shared aspect with host-class conditionals | hides platform boundaries and risks Darwin leakage |
| Home Manager standalone | duplicates user/system wiring and secrets |
| Custom Den policy/quirk | unnecessary; built-in batteries cover the topology |

## Evidence

- Pinned Den source: `nix/lib/entities/host.nix`, `nix/lib/entities/home.nix`,
  `modules/aspects/batteries/home-manager.nix`, `define-user.nix`,
  `primary-user.nix`, `hostname.nix`, `unfree.nix`, `flake-scope.nix`.
- Current Darwin config: `modules/den.nix`, `modules/host.nix`,
  `modules/base.nix`.
- NixOS host schema: `den.hosts.x86_64-linux.t14.users.adrioui.classes`.
