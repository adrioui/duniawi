# Adri Nix Config — Agent Context

You are working on a personal macOS developer environment managed with
[nix-darwin](https://github.com/LnL7/nix-darwin), [home-manager](https://github.com/nix-community/home-manager),
and Homebrew.

## Goal

One reproducible macOS setup: Nix owns system packages, services, and user
configuration; Homebrew owns GUI apps and a few things that are still better
managed outside Nix.

## Repository Layout

```
flake.nix              # flake inputs, unfree allowlist, outputs, checks
flake.lock             # locked input versions
hosts/adri/default.nix # system packages, services, nix-daemon settings
home/adrifadilah/      # user packages, shell, env, aliases
homebrew.nix           # Homebrew brews and casks
pkgs/                  # custom package derivations
AGENTS.md              # this file
README.md              # user-facing workflow
```

## Placement Rules

- **CLI/system-wide packages** → `hosts/adri/default.nix`.
- **User-scoped packages/shell config** → `home/adrifadilah/default.nix`.
- **GUI apps (Homebrew-managed)** → `homebrew.nix`.
- **Nix daemon settings** → `hosts/adri/default.nix`; do not introduce a separate tracked `nix.conf`.
- **Custom package definitions** → `pkgs/`; import them from modules.
- **Unfree allowlist** → keep narrow and explicit in `flake.nix` via `allowUnfreePredicate`.
- **Flake-first CLI policy** → keep `nix.registry.nixpkgs` pinned to the flake input and `nix.nixPath` aligned; do not re-enable legacy channels.
- **Homebrew activation** → keep `homebrew.onActivation.autoUpdate` and `upgrade` `false`; activation must stay idempotent.

## Non-Negotiable Decisions

Do not silently revert these:

- `homebrew.onActivation.cleanup = "zap"` is intentional. Every brew/cask must be declared in `homebrew.nix`; ad-hoc `brew install` is removed on the next rebuild.
- The repo is flake-first. Keep `nix.channel.enable = false`, the exact system `nix.registry.nixpkgs` entry, aligned `nix.nixPath`, and `experimental-features = "nix-command flakes"`.
- `flake.lock` is read-only during validation. Update inputs only with an explicit `nix flake update`.
- `thoughts/` stays uncommitted and is excluded from checks.

## Engineering Principles

- Prefer declarative fixes over imperative post-setup steps.
- Prefer small, localized changes over broad rewrites.
- Reuse the existing module split; do not create new top-level config layers without a strong reason.
- Keep comments short and operational. Delete comments that stop being true.
- Do not commit secrets, API keys, tokens, or private configuration. Keychain lookups and env variables stay in user configuration without inline secret values.
- Keep abstractions meaningful: a `pkgs/*.nix` file must earn its place, not just wrap one attribute.
- Update `README.md` when operator workflows or recommended commands change.

## Safe Workflow

1. Read the relevant module before editing.
2. Run `nix fmt --no-write-lock-file --no-update-lock-file` after edits.
3. Run `nix flake check --no-write-lock-file --no-update-lock-file` before committing; it covers nixfmt, deadnix, statix, lockfile freshness, and the real darwin/home-manager derivations.
4. For system changes, prefer `darwin-rebuild build --flake path:$PWD#adri` before any switch.
5. Treat validation commands as read-only with respect to `flake.lock`.

## Validation Commands

```bash
# Format Nix files
nix fmt --no-write-lock-file --no-update-lock-file

# Full native gate: lint + lockfile + darwin/home-manager builds
nix flake check --no-write-lock-file --no-update-lock-file

# Build without applying
darwin-rebuild build --flake path:$PWD#adri

# Apply
darwin-rebuild switch --flake path:$PWD#adri
```

Use explicit `path:` flake references for local rebuilds to avoid Git ownership
issues under `sudo`:

```bash
darwin-rebuild build --flake path:$PWD#adri
darwin-rebuild switch --flake path:$PWD#adri
```

## Commit Hygiene

- Make focused, atomic commits.
- Use conventional commit messages (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`).
- Stage only files and hunks relevant to the change.
- Commit the package definition together with the module that consumes it so the repo stays buildable at every commit.
- Do not commit docs churn in the same commit as unrelated package changes.
