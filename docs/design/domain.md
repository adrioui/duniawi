# Domain model

Status: **Gate 1 draft — no implementation writes yet**

This document fixes the nouns and states used by the cross-platform Den
configuration and by the paused home migration. Every status in a runbook must
name its evidence; bare strings such as `ok`, `done`, or `verified` are not
statuses.

## 1. Entities

| Entity | Identity | Cardinality | Owner | Evidence |
|---|---|---|---|---|
| Host | `host.name`, `host.system`, `host.class` | one per machine | Den entity `den.hosts.<system>.<name>` | `nix eval .#nixosConfigurations.<name>.config.nixpkgs.hostPlatform.system`, `.#darwinConfigurations.adri.config.nixpkgs.hostPlatform.system` |
| User | `user.userName`, `user.uid`, `user.gid` | one per login identity per host | Den entity `den.hosts.<system>.<host>.users.<user>` | `getent passwd`, `getent group`, `nix eval` of the host config |
| Home | `home.name`, `home.userName`, `home.hostName` | one per user/host pair | Den home context / `home-manager.users.<user>` | `home-manager` activation path, `home.username`, `home.homeDirectory` |
| System | `x86_64-linux`, `aarch64-darwin` | one per host | `den.hosts.<system>` key | `nix eval .#...config.nixpkgs.hostPlatform.system` |
| Aspect | `den.aspects.<name>` | composable; repeated by include | repository | `den.lib.capture`, `nix eval` of resolved aspect |
| Class | `nixos`, `darwin`, `homeManager` | one evaluation domain per class | Den class registry | `den.classes`, class module evaluation |
| Policy | `den.policies.<name>` / schema includes | topology, routing, enrichment only | Den policy registry | `den.lib.policyInspect`, graph artifact |
| Quirk | `den.quirks.<name>` | structured data route | Den quirk registry | `den.quirks`, pipe output |
| Package | derivation store path | one per referenced package | aspect / `pkgs` | `nix eval` of `meta.platforms`, `meta.broken`, `meta.license`, build |
| Service | unit name | one per unit | aspect / systemd | `systemctl cat`, `systemctl status`, `ss -ltnp` |
| Secret | reference path, never value | one per credential | owner + consumer | mode/owner check, sops/age metadata, rotation record |
| DataSet | path or path pattern | one per restore decision | migration operator | `gate3/source.sha256`, exclusion manifest |
| BackupManifest | SHA-256 + line count | one source, one destination | migration operator | `gate3/source.sha256`, `gate3/destination.sha256` |
| RestoreStage | `/home/adrioui.restore` | one per migration attempt | migration operator | `stat`, `findmnt`, manifest diff |
| Cutover | approved replacement of the live home | one-shot | migration operator + approver | approval record, root TTY transcript |
| Rollback | tested path back to previous home/generation | one-shot per incident | migration operator | generation list, home rename record, login proof |

### Host identities in this change

| Den host name | `hostName` | System | Class | Role | Output |
|---|---|---|---|---|---|
| `adri` | `adri` | `aarch64-darwin` | `darwin` | laptop | `darwinConfigurations.adri` |
| `t14` | `nixos` | `x86_64-linux` | `nixos` | laptop | `nixosConfigurations.t14` |

`t14` is the Den identity for the Lenovo ThinkPad T14 Gen 2i. The network
hostname remains `nixos` so existing local expectations do not change. The
Den name avoids the confusing `den.aspects.nixos.nixos` spelling that a host
named `nixos` would create.

### User identities in this change

| User | Host | UID | GID | Home | Shell | Primary |
|---|---|---|---|---|---|---|
| `adrifadilah` | `adri` | macOS-managed | macOS-managed | `/Users/adrifadilah` | zsh | yes |
| `adrioui` | `t14` | `1000` (recommended) | `1000` (recommended) | `/home/adrioui` | zsh | yes |

The old Fedora home was owned by `1000:1000` with user name `adrifadilah`.
The new NixOS account is `adrioui`, also UID 1000. The recommended mapping is a
new local group `adrioui` with GID 1000, so restored files keep their numeric
ownership without a recursive `chown`. See ADR-0004 and Approval 2.

## 2. IDs

| ID | Meaning | Where recorded |
|---|---|---|
| `host.name` | Den host key (`adri`, `t14`) | `modules/den.nix`, graph |
| `host.system` | `aarch64-darwin` or `x86_64-linux` | `den.hosts.<system>` |
| `host.class` | `darwin` or `nixos` | Den host entity |
| `user.userName` | login name (`adrifadilah`, `adrioui`) | Den user entity |
| `user.uid`, `user.gid` | numeric account identity | `den.schema.user`, `getent` |
| `home.name` | `adrioui` under `home-manager.users` | Den host-user forwarding / activation path |
| generation | NixOS or home-manager generation number | `nix-env --list-generations`, `home-manager generations` |
| Nix store path | immutable build output | `nix path-info`, `readlink /run/current-system` |
| SHA-256 digest | content digest of a manifest or artifact | `sha256sum`, evidence bundle |
| manifest line count | number of entries in a manifest | `wc -l` |
| service unit name | systemd unit identity | `systemctl`, unit files |
| listening port/protocol | intended network surface | `ss -ltnp`, firewall design |
| secret reference path | path or sops key name, never value | `docs/design/secrets.md` |
| migration state | `Blocked`, `Verified`, `Staged`, `CutOver`, `RolledBack` | runbook record |
| approval ID | `A1`–`A5` | `docs/design/approvals.md` |

## 3. Variants

| Variant | Values | Used by |
|---|---|---|
| HostClass | `Darwin`, `NixOS` | host, base, compatibility matrix |
| AspectDisposition | `Reuse`, `NixOSVariant`, `DarwinOnly`, `Retired` | compatibility matrix |
| ServiceDisposition | `Port`, `Replace`, `Containerize`, `Archive`, `Drop` | service disposition table |
| SecretState | `Plaintext`, `Encrypted`, `Rotated`, `Revoked` | secret inventory |
| MigrationState | `Blocked`, `Verified`, `Staged`, `CutOver`, `RolledBack` | migration runbook |
| DataDisposition | `Restore`, `Exclude`, `Regenerate`, `Quarantine` | exclusion policy |
| TestResult | `Pass`, `Fail`, `NotRun` | test plan and CI |

## 4. Errors and stop strategy

Every error is named in logs and reports. `Retry` is only for transient,
idempotent operations with bounded attempts and backoff. `Escape` requires a
documented alternative and explicit approval. `Die` means preserve evidence and
stop.

| Error | Strategy | Evidence / action |
|---|---|---|
| `EvalError` | Die | `nix eval` stderr, `nix flake check` log; fix or ask |
| `DarwinRegression` | Die | Darwin drv path changes unexpectedly; revert |
| `PackageUnavailable` | Escape | `meta.platforms` / build log; substitute or omit, never force Darwin derivation |
| `VMBootFailure` | Retry once, then Die | serial console log, `journalctl -b`; deterministic failure stops |
| `LoginFailure` | Die | TTY login transcript, `getent`, PAM/journal log |
| `HMActivationFailure` | Die | `home-manager switch` log, conflict list; do not disable home-manager |
| `ServiceFailure` | Retry bounded, then Die | `systemctl status`, `journalctl -u`; do not mask unit |
| `SecretLeak` | Die | revoke/rotate, purge leaked material, record incident; never paste value |
| `HashMismatch` | Die | `sha256sum --check` output; preserve evidence |
| `MetadataMismatch` | Die | `stat`, `getfacl`, `getfattr`, `find -printf` diff |
| `MissingFile` | Die | manifest path absent; do not synthesize |
| `DBCorruption` | Die | `PRAGMA integrity_check`, `.backup` verification; never overwrite live DB |
| `UnmappedOwnership` | Die | `find -nouser -o -nogroup`, `getent group 1000` |
| `OwnershipPolicyViolation` | Die | root-owned file outside approved `.herdr` and `Works/Bangunindo/BLIV`; do not map/delete without the recorded policy |
| `InsufficientSpace` | Die | `df -h`, `df -i` before copy; do not prune without approval |
| `PrivilegeUnavailable` | Escape | user-run root TTY, narrowly scoped NOPASSWD rule, or live USB; never ask for password in chat |
| `CutoverUnsafe` | Die | not on root TTY / live USB; move to safe path |
| `RollbackFailure` | Die | highest severity; preserve both homes and generations |
| `FlakeLockDrift` | Die | `sha256sum flake.lock`; only intentional documented updates |
| `NetworkTimeout` | Retry | downloads only, bounded backoff; never for hash verification |
| `BackupNotReadOnly` | Die | remount read-only and verify `findmnt` options |

## 5. Known domain facts and blockers

These are facts, not approvals.

| Fact | Evidence | Consequence |
|---|---|---|
| Backup is mounted read-only | `findmnt` shows `ro,nosuid,nodev,relatime,errors=remount-ro` | safe to read; no writes allowed |
| SMART health is PASSED | `gate5-smartctl-x.txt`; reallocated/pending/CRC = 0 | no drive replacement trigger |
| Source and destination manifests are identical | both 5,082,466 lines; both SHA-256 `7bdf05b3…` | copy integrity baseline |
| Bundle self-check passes except two self-referential lines | `sha256sum -c` filtered: all 40 remaining entries `OK` | wrapper mismatch is isolated |
| Wrapper hash differs | recorded `654c567d…`; actual `8bafbeb0…` | Approval 1 required |
| 192,782 root-owned entries; 170,171 regular files | refreshed `find -uid 0` inventory | root TTY required for full verification; map only `.herdr` and `Works/Bangunindo/BLIV` |
| Old home is ~282.73 GiB by top-level inventory | `home-top-level-sizes.txt` | target has 429 GiB free; staging fits |
| 5,082,466 manifest entries | `wc -l` | target has ~30.3M free inodes; fits |
| Old home is `1000:1000` | `stat` shows `adrioui:UNKNOWN` (gid 1000 unmapped) | Approval 2 required |
| Old user is `adrifadilah`; new user is `adrioui` | unit paths and current NixOS account | compatibility link required (ADR-0009); no rewriting |
| Old home has a plaintext GPG passphrase in a legacy unit | `gpg-preset-passphrase.service` contains an inline `--passphrase` | **SecretLeak**: do not restore; rotate GPG passphrase/key |
| Old home has a SOPS age private key at `$HOME/.config/sops/age/keys.txt` | mode 0600, 189 bytes, on an unencrypted backup drive | treat as exposed; generate a new host key; do not reuse |
| Old home has SSH, GPG, AWS, GitHub, Docker, Kubernetes, keyring, and AI-provider credentials | targeted path inventory | rotate or re-authenticate; never copy values into the repo |
| Five logical home-manager units are broken symlinks | `bliv-secrets`, `nix-gc.service`, `nix-gc.timer`, `nix-managed-probe`, `tray.target` | quarantine; do not restore dangling links |
| `sprint69-deck` payload is absent from the manifest | `grep` for `sprint-69-deck` returns nothing | archive; do not start until payload is found |
| `dsh` binary is absent from `.local/bin/dsh` | manifest grep returns nothing | archive; do not start |
| `collie` is a remote shell bridge on port 8787 | unit file | archive; do not expose |
| Old Fedora AI proxy stack is out of scope for NixOS | operator decision, recorded in `services.md` | archive; copy no old proxy unit, script, tunnel, or key |
| Repo-owned `amp-deepseek` proxy is implemented natively on `t14` | `pkgs/amp-deepseek`, `ampDeepseekNixos` design | systemd user unit + new sops credentials; no external-HDD files |
| Root/sudo is unavailable in this session | `sudo -n true` fails | root TTY or live USB required for Gates 3–5 |

## 6. Invariants

1. `main` is never committed to; all work is on `feat/cross-platform-nixos`.
2. `flake.lock` does not drift unless the change is intentional, documented,
   and reviewed.
3. The Darwin host evaluates and builds with no unintended behavior change.
4. No plaintext secret exists in the repository, Nix store, shell history,
   logs, or reports.
5. The backup is never written to; it stays `ro,nosuid,nodev,relatime`.
6. `/home/adrioui` is not touched during staging; the stage is
   `/home/adrioui.restore`.
7. No file in the restored tree has an unmapped UID or GID.
8. The live OpenCode database is never overwritten with an older copy.
9. A cutover is only performed from a root TTY or live USB, with the old home
   and at least N-1 and N-2 generations retained.
10. Every status names its evidence; `Pass` without a command and artifact is
    not a status.

## 7. Device acceptance (t14 hardening)

Status: **implemented in `scripts/device-verify.sh`; the live switch is
pending.**

The migration graph proves data can move; this graph proves the running OS is
the declared OS. It adds one invariant at evaluation time — a build from a tree
without `.git` fails — and one command that compares Home Manager's declared
file set with the live links.

### 7.1 Entities

| Entity | Identity | Source | Evidence |
|---|---|---|---|
| Device | `t14` | `hostnamectl`, `/run/current-system` | baseline row |
| LayerResult | `L1`–`L6` + check name | verifier | `verify.tsv` |
| ManagedPath | absolute target path | HM generation + `readlink` | `hm-collisions`, `managed-paths` |
| UnitDisposition | unit name | unit audit | `declared` row |
| Revision | commit SHA | `nixos-version --configuration-revision`, `git rev-parse` | `revision-format`, `revision-source` |
| Generation | generation number | `/nix/var/nix/profiles` | `generations`, `n-2` |
| ModelAccess | `provider/model` | `check-access` | `model-access` |
| Evidence | directory | `$HOME/.local/state/duniawi/evidence/<stamp>` | `verify.tsv` |

### 7.2 Variants

| Variant | Values | Used by |
|---|---|---|
| LayerResult | `Pass`, `Fail`, `NotRun` | verifier, acceptance |
| ManagedPathState | `Absent`, `HomeManagerLink`, `ForeignFile`, `ForeignSymlink`, `BackedUp` | HM audit |
| UnitDisposition | `Declared`, `Foreign`, `Archived` | unit audit |
| GenerationRole | `Current`, `N-1`, `N-2`, `ISO` | retention |
| ActivationState | `Blocked`, `Activated`, `Failed` | Home Manager |
| ModelAccess | `Served`, `Refused`, `Unknown` | L5 |

### 7.3 Errors

| Error | Class | Strategy | Detection |
|---|---|---|---|
| `ForeignPathCollision` | domain | Escape (known path) | `hm-collisions`, `*.hm-backup` |
| `HMActivationFailure` | domain | Die | `systemctl is-failed home-manager-adrioui` |
| `RevisionAbsent` | domain | Die | `configurationRevision` missing or not 40 hex |
| `StaleSource` | domain | Die | built revision ≠ durable HEAD |
| `DirtySource` | defect | Die | `git status --porcelain` non-empty |
| `GenerationShortfall` | domain | Die | fewer than 3 generations |
| `RescueMediaAbsent` | domain | Die for L6 | no booted-USB transcript |
| `ModelAccessFailure` | external | Retry once, then `Fail`; no OS rollback | `check-access` non-zero or refused |
| `LayerFail` | domain | Die; roll back the phase | `verify.tsv` `Fail` row |

### 7.4 Invariants

11. A build from a tree without `.git` fails evaluation; there is no unnamed
    running system.
12. Every Home Manager managed path is a link into the current generation's
    `-home-manager-files` tree; a foreign file or symlink is a named collision.
13. `--strict` is the acceptance mode: a required `NotRun` exits 2, so L1, L2,
    L4, L5's model row, L6, and the declared row cannot pass unobserved.
14. `check-access` is an external service probe, not an OS health signal; it
    can `Fail` without a system rollback.
15. The durable build source is `/var/lib/duniawi-src`, clean, and its HEAD is
    the recorded revision.
