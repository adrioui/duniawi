# Cutover safety case

Status: **NO-GO for live cutover. The code and hermetic tests are gated; the
data path is not.**

This is the one-page decision artifact. It does not replace the evidence
ledger; it states what must remain true and what makes us stop.

## 1. Invariants

1. The backup at `/run/media/adrioui/backup` is read-only and is never
   modified. `ro,nosuid,nodev,relatime` is checked before and after every
   privileged phase.
2. The old home is retained until the new home has passed login, data, service,
   and rollback acceptance. It is never deleted during cutover.
3. The stage is `/home/adrioui.restore`, never the live home. No command writes
   to `/home/adrioui` before cutover.
4. Numeric ownership is preserved. Only root-owned files under `.herdr/` and
   `Works/Bangunindo/BLIV/` are mapped to `adrioui`; no recursive `chown` is permitted.
5. No secret, private key, keyring, token, password, or old proxy credential is
   copied, committed, logged, or passed on a command line.
6. `amp-deepseek` binds only to `127.0.0.1:4014`, has no tunnel, and reports
   HTTP 503 when credentials are missing. It never falls back to plaintext.
7. Darwin behavior is not rewritten. A baseline worktree must reproduce the
   same Darwin derivation when `configurationRevision` is normalized.
8. A4 and A5 are explicit, recorded approvals for a specific window and root
   path. Chat text such as "run it" is not approval.

## 2. Irreversible or costly steps

| Step | Why costly | Control |
|---|---|---|
| Rename `/home/adrioui` to `/home/adrioui.pre-migration` | breaks the active login until the new home is renamed in | root TTY, no logout during rename, old home retained |
| Rename stage to `/home/adrioui` | path changes are visible to every process | no active user session, explicit A4/A5 |
| `nixos-rebuild switch` | activates a new system generation | previous generation retained, A5, reboot proof |
| Secret revocation/rotation | old credentials stop working | rotate after new secrets are provisioned, provider audit |
| Bootloader change | can make the machine unbootable | no change in this migration; N-1/N-2 retained |
| Backup unplug/replug | read-only mount can be lost | verify `findmnt`, remount read-only if needed |

## 3. Blast radius

- **Primary:** `t14` boot, login, `/home/adrioui`, user services, proxy.
- **Secondary:** old home retained on the same disk; backup drive.
- **Not in scope:** `adri` Darwin host, old Fedora source machine, network
  services, provider accounts.

A failed cutover is recoverable by renaming the old home back and booting the
previous generation. A failed backup mount is not recoverable if the backup is
written; therefore the backup stays read-only.

## 4. Data classification

| Class | Examples | Decision |
|---|---|---|
| User data | `.herdr/` BLIV worktrees, `Works/Bangunindo/BLIV`, `Personal/`, user-owned `Learns/` data, Agent conversation transcripts | migrate after hash/metadata verification |
| Regenerable / not needed | `Tooling`, `Fun`, `Games`, `Downloads`, `.dlt`, `surrealdb-data`, caches, build outputs, container layers, `clickhouse-local/`, distrobox, non-BLIV `Works`, trash | exclude |
| Secrets | `.ssh`, `.gnupg`, `.config/sops`, cloud/provider credentials, keyrings, `.clawdbot/`, old proxy configs | never copy; rotate and reprovision |
| Unverifiable root-owned | root-owned files outside `.herdr` and `Works/Bangunindo/BLIV` | exclude; do not guess |
| Required root-owned | `.herdr/`, `Works/Bangunindo/BLIV/` root-owned files | hash first, then map to `1000:1000` |

## 5. Rollback triggers

Stop immediately, preserve logs, and do not continue if any of these occurs:

- content hash mismatch, missing file, or metadata mismatch;
- root-owned file outside the approved mapping;
- unmapped UID/GID, ACL, xattr, hardlink, or symlink regression;
- SQLite integrity failure or a WAL/SHM inconsistency;
- secret material in the stage, repository, store, or journal;
- failed login, failed Home Manager activation, or failed user service;
- proxy not healthy, not loopback-only, or returning 200 without credentials;
- previous generation does not boot in the rehearsal;
- `findmnt` no longer shows the backup read-only;
- unexplained build failure or flake-lock change.

## 6. Go/no-go

**Go only when all are true:**

- A1–A5 recorded against the current evidence; A4/A5 name the window and root
  path;
- fresh root hash verification is complete and differences are reconciled;
- stage metadata, ACL, xattr, hardlink, symlink, SQLite, and secret scans pass;
- new `t14` age key and `amp-deepseek` secrets are provisioned and `/health`
  returns 200;
- rollback rehearsal boots the previous generation and logs in with the old
  home;
- VM proof, failure injection, and Darwin CI/macOS build pass;
- free space and inode budget are sufficient, with a margin.

**No-go now:** root hash verification is not complete, secrets are not
rotated/provisioned, rollback rehearsal is NotRun, and A4/A5 are absent.

## 7. Independent oracles

| Claim | Oracle |
|---|---|
| Backup content unchanged | fresh `sha256sum -c` against the source manifest, plus read-only mount check |
| Stage metadata preserved | independent `find -printf`/`getfacl`/`getfattr`/`getcap` streams compared source vs stage |
| SQLite usable | `PRAGMA integrity_check` and a copy/open test |
| NixOS configuration valid | `nix eval`, `nix build`, `nix flake check`, VM boot |
| Proxy behavior | real HTTP requests: 200/401/503/413, loopback listener, restart |
| Darwin non-regression | baseline worktree drv comparison and macOS CI |
| Rollback works | previous generation boots and old home logs in |
| Secrets revoked | provider audit logs and old-key failure |

A green local log is not enough. If an oracle cannot run, the claim is
`NotRun`, not `Pass`.
