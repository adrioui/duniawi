# ADR-0007: Two-system CI matrix

- Status: Proposed
- Date: 2026-10-31
- Deciders: repository owner
- Related: `docs/design/test-plan.md`, `docs/design/compatibility.md`

## Context

A Linux-only CI run cannot prove that the Darwin host still evaluates or
builds. A Darwin-only run cannot prove the NixOS host boots. The repository
uses `flake-parts` `perSystem` checks, so checks must be evaluated for both
systems without trying to build Darwin-only packages on Linux.

## Decision

Run a fail-closed matrix:

- `ubuntu-24.04` for `x86_64-linux` static, eval, build, proxy tests, NixOS VM
  test, migration fixture, lockfile, and secret scan.
- `macos-14` (arm64) for `aarch64-darwin` static, eval, build, and proxy tests.
- Pin every GitHub Action to a commit SHA.
- Run `nix flake check --no-build --no-write-lock-file --no-update-lock-file
  --all-systems` for evaluation; build only the current system's checks.
- Run `git diff --exit-code -- flake.lock` after all Nix commands to catch
  accidental lock writes.
- Guard Darwin-only `perSystem` outputs with `lib.meta.availableOn` or an
  explicit system check.
- Do not use `--impure`, channels, or unpinned inputs.

## Consequences

- Both hosts are proven on every push/PR.
- CI is slower and more expensive than a single Linux job; the VM test may run
  under QEMU TCG.
- The Darwin build requires a macOS runner and may hit a binary cache miss.
- A skipped or `NotRun` required job is not `Pass`.
- The lockfile job distinguishes an intentional `sops-nix` addition from an
  accidental mutation.

## Alternatives considered

| Alternative | Why rejected |
|---|---|
| Linux-only CI | cannot prove Darwin non-regression |
| Darwin-only CI | cannot prove NixOS boot |
| Local-only tests | not reproducible, no PR gate |
| Floating action tags | supply-chain and reproducibility risk |
| `--impure` workaround | forbidden by the repository policy |

## Verification

- CI matrix shows both `aarch64-darwin` and `x86_64-linux` jobs.
- Darwin drv path recorded; NixOS drv path recorded.
- VM test passes; proxy tests pass on both.
- `flake.lock` diff contains only the documented pinned inputs:
  `nixpkgs-stable`, `home-manager-stable`, `nixos-hardware`, and `sops-nix`.
- Secret scan is clean.
