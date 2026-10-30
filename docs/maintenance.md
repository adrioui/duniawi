# Maintenance and Rebuild Workflow

## Status

Changes are validated in a clean git worktree before they touch the live system. The live system is switched only after the flake checks and the system build pass.

## Clean worktree

```bash
cd ~/.config/nix
git worktree add -b <branch> /tmp/<branch>
cd /tmp/<branch>
```

Work in the worktree, commit there, then fast-forward `main`:

```bash
cd ~/.config/nix
git merge --ff-only <branch>
```

## Validation gates

Run all of these before a commit:

```bash
nix fmt --no-write-lock-file --no-update-lock-file
nix flake check --no-write-lock-file --no-update-lock-file
nix build .#darwinConfigurations.adri.system --print-out-paths
nix build .#checks.aarch64-darwin.home-manager-activation --print-out-paths
```

`nix flake check` covers formatting, dead code, lint, lockfile freshness, the real darwin system, the home-manager activation, and the Amp proxy tests.

## Rebuild

```bash
darwin-rebuild build --flake path:$PWD#adri
sudo darwin-rebuild switch --flake path:$PWD#adri
```

Use `path:` for local rebuilds so `sudo` does not fight Git ownership. Keep the working tree clean and remove the `result` symlink when a reproducible store path matters; `path:` includes untracked files and changes `dirtyRev`.

## Reproducibility check

```bash
nix build .#darwinConfigurations.adri.system --print-out-paths
nix store diff-closures /nix/store/<built-system> /run/current-system
```

The diff must be empty for a no-op rebuild.

## Updating inputs

Update only when intentional:

```bash
nix flake update
nix flake check --no-write-lock-file --no-update-lock-file
```

`flake.lock` is read-only during validation. Do not let a validation command rewrite it.

## Nix garbage collection

```bash
nix-collect-garbage --delete-older-than 14d
sudo nix-collect-garbage --delete-older-than 14d
```

The system also runs automatic GC after 14 days and automatic optimisation.

## Homebrew

```bash
brew update
brew upgrade
```

Homebrew activation does not auto-update or upgrade. Keep every persistent brew/cask declared; `cleanup = "zap"` removes anything undeclared.

## Amp

After the first activation, restart Amp or run `plugins: reload` so the official modes plugin loads. The DeepSeek tunnel and proxy are launchd agents; check:

```bash
launchctl list | grep amp-deepseek
curl -sS http://127.0.0.1:4014/health
```

## Commit hygiene

Use conventional, atomic commits:

```text
feat(scope): ...
fix(scope): ...
chore(scope): ...
docs(scope): ...
```

One concern per commit. Push only after the validation gates pass.

## Security

* Do not commit secrets, tokens, or Keychain values.
* Keep secrets in Keychain and read them at runtime.
* Do not put secrets in plists, launchd environment, Nix store paths, or logs.
* Review any new fetchurl/fetchFromGitHub for a pinned hash or revision.

## Troubleshooting

| Symptom | Check |
|---|---|
| `nix flake check` fails only on a dirty tree | untracked files or `result` symlink are part of `path:` |
| system path changes on every rebuild | `dirtyRev` changes; clean the tree |
| activation removes an app | it was not declared in Homebrew or Nix |
| Keychain service missing | `security find-generic-password -s <service> -w` |
| launchd agent exits | `~/Library/Logs/<agent>.error.log` |
| flake input update breaks a package | revert the input or pin a known-good revision |
| store diff is not empty | compare the built system with `/run/current-system` and inspect changed packages |
