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

## Device acceptance gate (t14)

`t14` installs the gate from the flake as
`/run/current-system/sw/bin/device-verify`; `/etc/duniawi/device-verify.sh` is
kept as the runbook-compatible path. The source is
`scripts/device-verify.sh`, packaged by `pkgs/device-verify.nix` with pinned
parsers (`coreutils`, `findutils`, `gawk`, `git`, `gnugrep`, `gnused`, `jq`) and
enabled by `modules/device-verify.nix`.

```bash
# Root acceptance: L1 bootctl rows, journal binding and evidence need root.
sudo /run/current-system/sw/bin/device-verify \
  --thread "$AMP_THREAD_ID" --strict

# User preview: root-only rows are NotRun; everything user-scoped still runs.
/run/current-system/sw/bin/device-verify --thread "$AMP_THREAD_ID"
```

Evidence defaults to a root-only tree:

```text
/var/lib/duniawi/evidence/<stamp>/verify.tsv
/var/lib/duniawi/evidence/<stamp>/context.json
/var/lib/duniawi/evidence/<stamp>/manifest.sha256
/var/lib/duniawi/evidence/<stamp>/menu-rehearsal.txt
/var/lib/duniawi/evidence/<stamp>/rescue-media.txt
```

Directories are `0750 root:root`; files are `0640 root:root`. A non-root run
uses `${XDG_STATE_HOME:-$HOME/.local/state}/duniawi/evidence/<stamp>` and its
required physical rows stay `NotRun`. Root evidence is never chowned to the
login user.

Rows are TSV: `layer check expected actual result evidence`, followed by one
`verify-complete checks=N pass=N fail=N notrun=N attested=N` line. Results are
`Pass`, `Fail`, `NotRun`, and `Attested`. `Attested` is reserved for the two
physical transcripts: the menu transcript is Attested only when its `boot_id`
is in the journal and that boot's kernel command line carries the N-1
`init=`; the rescue transcript is Attested only when its `iso_sha256` matches
`duniawi.deviceVerify.rescueIsoSha256` and its `loader.conf` block is present.
A missing transcript is a required `NotRun`; a wrong binding is `Fail`.

Exit is `0` when every required row passes or is Attested, `1` on any `Fail`,
and `2` when `--strict` meets a required `NotRun`. A run without the final line
or without `manifest.sha256` aborted; treat it as a failure, not a pass.

`NotRun` is allowed for physical checks (suspend/resume, audio playback,
Bluetooth pairing, backlight, touchpad, camera, fingerprint, firmware update,
hibernation, encryption) and for the migration handoff. The required
`Attested` rows are L6/menu-rehearsal and L6/rescue-media.

L6 proves more than the revision string:

- `revision-format` and `revision-source` compare `nixos-version` with the
  durable clone's HEAD;
- `revision-build` evaluates
  `nixosConfigurations.t14.config.system.build.toplevel.outPath` from
  `/etc/nixos` and requires it to equal `/run/current-system`;
- `generations` requires exact `system-<N>-link`, `system-<N-1>-link` and
  `system-<N-2>-link` targets;
- `n-2-intact` runs `nix store verify --recursive --no-trust` on N-2;
- `n-2-boot` scans the journal for a boot whose kernel command line has the
  N-2 `init=`;
- `menu-rehearsal` and `rescue-media` are the Attested rows above.

The negative gate is part of the proof:

```bash
/run/current-system/sw/bin/device-verify --expect-revision deadbeef \
  --thread "$AMP_THREAD_ID"
# exit 1, with a FAIL on L6/revision-source
```

To attach transcripts written outside the evidence directory:

```bash
sudo /run/current-system/sw/bin/device-verify \
  --evidence /var/lib/duniawi/evidence/<stamp> \
  --menu-evidence /path/to/menu-rehearsal.txt \
  --rescue-evidence /path/to/rescue-media.txt \
  --thread "$AMP_THREAD_ID" --strict
```

The menu transcript must contain a `boot_id=` line from the N-1 boot. The
rescue transcript must contain `iso_sha256=94c9...` and the `loader.conf` block
printed by `bootctl --esp-path`. A transcript is operator evidence, not a
cryptographic proof of a physical keypress; `Attested` means the boot or ISO
binding checks out.

### Recorded revision

`modules/base.nix` asserts `system.configurationRevision != null`, so a build
from a tree without `.git` fails evaluation. Build the live system from the
durable clone:

```bash
sudo git -C /etc/nixos status --porcelain   # empty
sudo nixos-rebuild switch --flake /etc/nixos#t14
nixos-version --configuration-revision               # 40 hex = git rev-parse HEAD
```

NixOS 26.05 does not write `/run/current-system/configurationRevision`; the
value is baked into `nixos-version` at build time. `dirtyRev` (`<sha>-dirty`)
still evaluates; `L6/revision-source` rejects it because it is not the durable
HEAD.

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
