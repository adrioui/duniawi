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
- Add reusable package definitions under `pkgs/` and import them from modules.
- Update `README.md` when changing operator workflows or recommended commands.

## Safe Workflow

1. Read the relevant module before editing.
2. Prefer small, localized changes.
3. Run `hack/feedback_loop.sh fast` after edits.
4. Run `hack/feedback_loop.sh check` before committing.
5. For system changes, prefer `darwin-rebuild build --flake path:$PWD#adri` before any switch.

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
hack/feedback_loop.sh check
hack/feedback_loop.sh build
hack/feedback_loop.sh diff
```

## Commit Hygiene

- Make focused commits.
- Use conventional commit messages when possible.
- Stage only the files and hunks relevant to the change.
