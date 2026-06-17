# AGENTS

Repository guidance for AI coding agents and human contributors.

## Goal

This repository manages a personal macOS setup with:
- `nix-darwin` for system configuration
- `home-manager` for user configuration
- Homebrew only for GUI apps and the few packages that are still better managed outside Nix

## Important Files

- `flake.nix` — flake inputs, outputs, checks, dev shell
- `hosts/adri/default.nix` — system packages, system services, nix-darwin settings
- `home/adrifadilah/default.nix` — user packages, shell aliases, home-manager settings
- `homebrew.nix` — Homebrew brews and casks
- `hack/feedback_loop.sh` — preferred validation harness for local iteration
- `pkgs/` — custom derivations
- `README.md` — user-facing workflow and repo structure

## Placement Rules

- Add CLI/system-wide packages to `hosts/adri/default.nix`.
- Add user-scoped packages or shell configuration to `home/adrifadilah/default.nix`.
- Add GUI apps that should remain Homebrew-managed to `homebrew.nix`.
- Keep Nix daemon settings (substituters, trusted keys, GC, optimisation) in `hosts/adri/default.nix`.
- Do not introduce or rely on a separate tracked `nix.conf`; keep one declarative source of truth.
- Keep the unfree-package allowlist in `flake.nix` narrow and explicit via `allowUnfreePredicate`; do not fall back to blanket `allowUnfree = true` unless there is a deliberate repo-wide decision.
- Preserve the flake-first CLI policy in `hosts/adri/default.nix`: keep `nix.registry.nixpkgs` pinned to the flake input, keep `nix.nixPath` aligned with that pinned input, and do not re-enable legacy channels without a deliberate reason.
- Keep flake-first policy machine-checkable where practical; prefer nix-darwin `assertions` for repo invariants that should fail during evaluation instead of only being documented.
- Keep Homebrew activation idempotent and deterministic; `homebrew.onActivation.autoUpdate` and `upgrade` should remain `false`.
- For custom launchd jobs, prefer generated scripts or package store paths (for example via `lib.getExe`) over `/run/current-system/sw/bin/...` so runtime resolution stays declarative.
- Add reusable package definitions under `pkgs/` and import them from modules.
- Update `README.md` when changing operator workflows or recommended commands.

## Safe Workflow

1. Read the relevant module before editing.
2. Prefer small, localized changes.
3. Run `hack/feedback_loop.sh fast` after edits.
4. Run `hack/feedback_loop.sh lint` when you want a quick read-only repo check before the full build path.
5. Run `hack/feedback_loop.sh check` before committing; it should cover both repo checks and full darwin/home-manager build validation.
6. Run `hack/feedback_loop.sh lock` when touching `flake.lock` or reviewing input freshness.
7. For system changes, prefer `darwin-rebuild build --flake path:$PWD#adri` before any switch.
8. Keep Homebrew activation idempotent; do not enable automatic brew updates during rebuilds.
9. Keep the repo flake-first: prefer `nix run` / `nix shell` / `darwin-rebuild --flake` workflows over channels, and preserve the pinned `nix.registry` / `nix.nixPath` alignment when editing Nix settings.
10. Treat validation commands as read-only with respect to `flake.lock`; update inputs explicitly with `nix flake update` instead of letting routine checks rewrite the lock file.

## Flake Reference Best Practice

Use explicit `path:` flake references for local rebuild commands:

```bash
darwin-rebuild build --flake path:$PWD#adri
darwin-rebuild switch --flake path:$PWD#adri
```

This avoids local Git ownership issues that can appear when rebuilding through `sudo`.

## Editing Conventions

- Keep comments short and operational.
- Preserve the existing module split unless there is a strong reason to refactor.
- Prefer declarative fixes over imperative post-setup steps.
- Do not edit `flake.lock` unless intentionally updating inputs.
- Keep `thoughts/` uncommitted.
- Run `nix fmt` for formatting; do not hand-format around the formatter.

## Validation Commands

```bash
hack/feedback_loop.sh fast
hack/feedback_loop.sh lint
hack/feedback_loop.sh check
hack/feedback_loop.sh lock
hack/feedback_loop.sh build
hack/feedback_loop.sh diff
```

## Commit Hygiene

- Make focused commits.
- Use conventional commit messages when possible.
- Stage only the files and hunks relevant to the change.
