# Duniawi home migration — go/no-go record (2026-11-02)

Status: **Final (no cutover performed).** Stage: GO for byte-faithful restore
and six-oracle verification. Cutover: NO-GO. See section 8.
Host: `nixos` / `t14`, NixOS 26.05.13164.6f06d204d8f2
Repo: `/usr/local/lib/duniawi`, branch `feat/home-migration`
Evidence stamp: `20261102T103246`
Source: `/run/media/adrioui/backup/home` (`/dev/sda1`, ext4, read-only)
Stage: `/home/adrioui.restore`
Live home: `/home/adrioui` (not modified by this run; not cut over)

## 1. Decision

**GO for the staged restore** if every real-stage oracle below is `PASS`.
**NO-GO for cutover.** The stage is a verified copy, not an authorization to
switch. Cutover blockers are listed in section 8; none was waived.

This record does not authorize `nixos-rebuild switch`, a reboot for cutover, a
rename of `/home/adrioui`, or deletion of the backup.

### 1.1 Owner decisions applied

| Decision | Action in this run |
|---|---|
| Delete stale 80 GiB stage | done (79.47 GB, 1,665,614 files; 15 s) |
| Map root-owned `.herdr`/BLIV files to `1000:1000` | done by `restore-home.sh` (`MAP_ROOT_OWNED=1`, no setuid/caps found) |
| `Learns/**/surrealdb-data` disposable | excluded by filter; backup left read-only (not deleted from backup) |
| n8n disposable / out of scope | no n8n DB row check; n8n `.env` remains excluded; no deletion from backup |
| Create sops keys | **not performed** here; secret provisioning/rotation remains an owner action |
| Rotate exposed credentials | **not performed** by this run; owner: user, tomorrow |
| When to remove the compatibility link | recommendation: phase 2, after a per-directory remaining-reference ledger and one accepted login; not removed now |

## 2. Preflight

| Check | Result | Evidence |
|---|---|---|
| HEAD before patches | `1d640e7` | `00-preflight.log` |
| `sha256sum flake.lock` | `5b495d350f985613c13b2b80b6fa4fe54b8c5db96d85145d39ad97d65346ee9f` | `00-preflight.log` |
| Backup mount options | `/dev/sda1 ... ro,nosuid,nodev,relatime,errors=remount-ro`; ERE `(^|,)ro(,|$)` = PASS | `00-preflight.log` |
| Free space / inodes under `/home` | 326G free before removal, 405G after; 26,854,399 inodes free | `00-preflight.log`, `03-stage-removal.log` |
| Stale stage before removal | 79,472,057,143 bytes, 1,665,614 files, 277,010 dirs; 2,088 new-path lines / 0 old-path lines in `.claude/history.jsonl` | `02-stage-before.log` |
| Live home before | 2,094,563,275 bytes, 17,220 files; mtime 2026-11-02T08:45:31+07 | `02-stage-before.log` |

## 3. Patches and ledger preservation

| Item | Commit | Result |
|---|---|---|
| Existing row 34 | `17a0188` | committed separately, not folded into the fix |
| 0006 locale fix | `9c98cb1` | `git am`, no conflict |
| 0007 completion/fault/guard | `09a0cac` | `git am`, no conflict |
| Legacy SC2012 lint fix | `665fdf4` | separate, lint-only; `find -print -quit` replaces `ls | head` |
| `.env` exact-basename exclusion | `676617e` | separate security fix: 45 in-scope `.env` files; filter, oracle, rehearsal, docs |
| Cross-include hardlink fix | `281f791` | one rsync invocation; rehearsal asserts a Works↔Personal hardlink |
| `flake.lock` after | unchanged, hash above | `01-apply-patches.log` |

## 4. Gate transcript

Command exit codes are in `gates.tsv`; full logs are under `gates/`.

| # | Gate | Exit | Elapsed | Evidence |
|---|---|---|---|---|
| 01 | `nix flake check --no-build --all-systems` | 0 | 24 s | `gates/01-flake-check.log` |
| 02 | `nix build --no-link .#checks.x86_64-linux.nixfmt` | 0 | 2 s | `gates/02-nixfmt.log` |
| 03 | `nix build --no-link .#checks.x86_64-linux.deadnix` | 0 | 1 s | `gates/03-deadnix.log` |
| 04 | `nix build --no-link .#checks.x86_64-linux.statix` | 0 | 1 s | `gates/04-statix.log` |
| 05 | `shellcheck -S style scripts/*.sh` | 0 | 1 s | `gates/05-shellcheck.log` |
| 06 | `actionlint .github/workflows/ci.yml` | 0 | 0 s | `gates/06-actionlint.log` |
| 07 | `gitleaks detect --no-git --source . --config .gitleaks.toml --redact` | 0 | 0 s | `gates/07-gitleaks.log` |
| 08 | `nix build -L --rebuild .#checks.x86_64-linux.migration-rehearsal` | 0 | 83 s | `gates/08-rehearsal.log` |

The initial shellcheck run failed only on SC2012 in `scripts/root-migrate.sh`;
the pre-fix transcript is kept as `gates-pre-shellcheck-fix.tsv` and
`gates-pre-shellcheck-fix/`. The fix is commit `665fdf4`.

### 4.1 Rehearsal oracle proof

The rehearsal exercises the shipped scripts in a NixOS VM. Both locales show
six oracle rows plus the completion row.

| Oracle | C run | en_US.UTF-8 run |
|---|---|---|
| drift-lines | PASS 0 | PASS 0 |
| unexplained-exclusions | PASS 0 | PASS 0 |
| secret-paths-present | PASS 0 | PASS 0 |
| worktree-pointers | PASS 0 | PASS 0 |
| git-fsck-regression | PASS 0 | PASS 0 |
| sqlite-integrity | PASS 0 | PASS 0 |
| verify-complete | PASS 6 | PASS 6 |

Fault injection: PASS (same-size/same-mtime mutation; `drift-lines FAIL`,
`verify-complete FAIL`, `rc=1`; restored file goes green again with rc 0).
Writable-source guard: PASS (non-zero, message `not mounted read-only`, no
stage created). Exact `.env` basename: `excluded .env: absent`, and the final
rehearsal assertion checks the path is gone.

## 5. Real restore

Command:

```bash
SRC=/run/media/adrioui/backup/home \
STAGE=/home/adrioui.restore \
EVID=/var/log/duniawi-migration/20261102T103246 \
  bash scripts/restore-home.sh
```

| Check | Result |
|---|---|
| Refusal while stage existed | PASS (script refuses an existing stage) |
| First attempt | aborted at 3:32 before data transfer (4 KiB stage) after the `.env` audit; stage removed; fix `676617e` |
| Source read-only guard | PASS (ERE) |
| Copy start / end / elapsed | 2026-11-02T10:47:58+07 / 11:04:39+07 / 1,001 s |
| Transferred bytes / stage bytes | 79,528,076,464 / 79,529,741,983 |
| Actual copy throughput | 79.45 MB/s (75.77 MiB/s) |
| `no-uid-0-in-mapped-trees` | PASS 0 |
| `no-foreign-uid` | PASS 0 |
| `no-foreign-gid` | PASS 0 |
| `home-mode` | PASS 700 |
| Root-owned entries outside mapped trees | 75 (52 `Personal/financial/actual`, 23 `Learns`); byte-faithful but outside the approved mapping |
| Stage files / dirs / bytes | 1,667,037 / 277,052 / 79,529,741,983 |

## 6. Real verification

Command:

```bash
SRC=/run/media/adrioui/backup/home \
STAGE=/home/adrioui.restore \
EVID=/var/log/duniawi-migration/20261102T103246 \
  bash scripts/verify-home.sh --checksum --deep
```

| Oracle | Result | Evidence |
|---|---|---|
| exit code | 0 | `verify.rc` |
| drift-lines | PASS 0 | `verify.tsv`, `drift.txt` |
| unexplained-exclusions | PASS 0 | `verify.tsv`, `not-explained.txt` |
| secret-paths-present | PASS 0 | `verify.tsv` |
| worktree-pointers | PASS 0 | `verify.tsv` |
| git-fsck-regression | PASS 0 | `verify.tsv`, `git-regression.txt` |
| sqlite-integrity | PASS 0 (1,227 checked; 453 WAL) | `verify.tsv`, `db-fail.txt` |
| gitleaks (stage) | NotRun (path-only; no secret values read) | `verify.tsv` |
| verify-complete | PASS 6 | `verify.tsv` |
| elapsed / start / end | 2021 s / 2026-11-02T12:40:31+07 / 13:14:12+07 | `verify.rc`, `verify.elapsed` |

### 6.1 Verification-integrity incident (caught and repaired)

The first full verify passed at 11:39:41. The first post-verify spot-check then
opened five staged `.cursor/chats` SQLite databases directly with `sqlite3`.
SQLite removed their **zero-byte** `-wal` files and 32 KiB `-shm` files. The
database files themselves remained byte-identical (SHA-256 and mtime matched),
and no transaction data was lost. A fast `rsync -n -c` check caught the loss.

Repair: `rsync -aHASX --numeric-ids` from the read-only source for
`.cursor/chats/` restored the five WAL/SHM pairs and directory mtimes; fast
drift returned to 0. The flawed spot-check was replaced with a copy-only query
(never opens a staged database in place), and the **full six-oracle verify was
rerun after the repair**. The table above and `verify.tsv` are from that
post-repair run. Evidence: `08-spotcheck-mutation.log`,
`09-repair-spotcheck-mutation.log`, `09-fast-drift.txt`,
`verify-before-spotcheck-mutation.tsv`.

The same copy-only audit found a second, independent fidelity defect:
`restore-home.sh` ran `rsync -H` once per include path, so **3,830 hardlink
groups (3,470 BLIV↔worktree, 360 Learns↔BLIV; 4,636 links) were split**. Every
affected file had identical content and metadata; only inode topology differed.
The durable fix is `281f791` (one rsync invocation; the rehearsal now asserts a
Works↔Personal hardlink). The current stage was relinked in place
(`10-hardlink-repair.log`: 3,830 groups / 4,636 links, 0 metadata/xattr
mismatches, 0 errors), 111 temporary link names were removed
(`10b-relink-temp-cleanup.log`), and the group check reports 0 broken groups.
The final full verify below was run after both repairs. Evidence:
`10-hardlink-repair.log`, `10b-relink-temp-cleanup.log`,
`spot-hardlink-groups.txt`, `spot-stage-inodes-final.tsv`.

A directory-mtime refresh then used `rsync -a`, which includes owner/group,
and reverted **32,945** mapped entries in `.herdr`/BLIV to root. The approved
mapping was re-applied (`chown -h 1000:1000` only in those trees); the mapped
count returned to 0, the 75 outside entries stayed root, and the final verify
was restarted. This regression is exactly what `no-uid-0-in-mapped-trees` and
the independent `find -uid 0` census catch. Evidence:
`10c-dir-mtime-refresh.log`, `10d-remap-after-refresh.log`.

## 7. Independent spot checks

| Check | Source | Stage | Result |
|---|---|---|---|
| hardlinked files (`nlink > 1`) | 31,386 (82 links not in stage, excluded) | 31,304 (11,407 groups) | hardlink-group integrity PASS: 0 broken groups, 0 mixed source groups, 0 missing source paths |
| sparse files (`blocks*512 < size`) | 0 (source fully allocated) | 3,760 (8.28 GB apparent / 8.11 GB allocated) | `rsync -S` sparsified zero runs; content proven by oracle 1 |
| worktree pointers (`gitdir:`) | 53 absolute worktree pointers | 53, all resolve; 33 relative submodule gitdirs external | PASS 0 unresolved |
| DB + WAL pairs | 1,228 DBs / 453 pairs | 1,227 DBs / 453 pairs | one DB excluded under `Personal/.../node_modules`; explained |
| n8n DB rows | — | — | Out of scope (owner decision 2026-11-02) |
| agent-history DB rows | `.cursor` store.db: blobs 3,178 / meta 1 | same counts | PASS (copies only; no stage mutation) |

## 8. Cutover blockers

| # | Blocker | Evidence | Owner | Status |
|---|---|---|---|---|
| 1 | No N-1/N-2 system generation; only generation 1 and one boot entry | `04-rollback-baseline.log` | operator | open |
| 2 | A4/A5 approvals absent; no window, no live-switch authorization | `docs/design/approvals.md` | repo owner | open |
| 3 | Secrets not rotated/provisioned; proxy remains fail-closed 503 | `docs/design/secrets.md`; ledger row 23 | user | open (rotation tomorrow) |
| 4 | Running system gid is 100; target gid 1000; `getent group 1000` is absent until first switch | `id`; `00-preflight.log` | operator | expected pre-switch; verify after switch |
| 5 | Boot-menu rollback rehearsal NotRun (hardware) | `04-rollback-baseline.log`; `evidence/rollback/README.md` | operator | NotRun |
| 6 | Stage content secret scan not run (path oracle only; avoids reading secret values) | `verify.tsv` | security owner | NotRun |
| 7 | Worktree count is 82 gitdir files (52 unique names), not 53; all resolve, phase-2 repair not done | `07-spot-checks.log` | maintainer | deferred |
| 8 | DB+WAL pair count measured 453, not the brief's 494; reconcile the claim | `07-spot-checks.log` | maintainer | open |
| 9 | `/home/adrioui` is live and being written by the running desktop/agent; cutover needs no sessions | `02-stage-before.log`; `loginctl` | operator | open |
| 10 | Compatibility link `/var/home/adrifadilah` is not installed until the switch; phase-2 removal plan still needed | `04-rollback-baseline.log` | maintainer | deferred |
| 11 | n8n is explicitly out of scope; its DB is absent from the scoped backup and no row check is required | owner decision 2026-11-02; `06-restore-post.log` | user | out of scope, not a blocker |
| 12 | 75 root-owned entries outside `.herdr`/BLIV (52 `Personal/financial/actual`, 23 `Learns`) are in the stage; policy says exclude or map | `06-restore-post.log`; `root-owned-outside-mapped.txt` | repo owner | open decision |

## 9. Rollback plan

Baseline: **1 generation** (generation 1, current, built 2026-10-31); `bootctl list`
has `nixos-generation-1.conf` and the firmware entry. There is no N-1/N-2.

### 9.1 Home rollback (no reboot)

```bash
loginctl terminate-user adrioui || true
pkill -u adrioui || true
mv /home/adrioui /home/adrioui.post-migration.<stamp>
mv /home/adrioui.pre-migration.<stamp> /home/adrioui
stat -c '%U:%G %a %n' /home/adrioui
```

Naming: the pre-cutover home is `/home/adrioui.pre-migration.<stamp>` and the
failed new home is retained as `/home/adrioui.post-migration.<stamp>`. Both
renames are on the same filesystem (`/`), so they are `rename(2)`, not copies.

### 9.2 Generation rollback

`bootctl` currently has only generation 1, so **no generation rollback is
possible today**. Before cutover, create and retain N-1/N-2 by an approved
switch. Then boot the previous entry or run `nixos-rebuild switch --rollback`
from a root TTY. This rehearsal is **NotRun**: it needs hardware/boot-menu
access and an existing previous generation.

### 9.3 Data rollback

The backup remains read-only and untouched; the stage can be re-created from it
with `restore-home.sh` after removing the failed stage. Do not delete the
backup or the retained homes.

## 10. NotRun

- Boot-menu selection of a previous generation (no N-1 exists; hardware menu).
- Live login as the restored home (no cutover).
- Proxy health with production sops keys (keys not provisioned).
- Provider credential rotation (owner: user, tomorrow).
- Stage-wide content secret scan (path-only oracle; no secret values read).
- macOS/Darwin build on macOS hardware (out of scope for this run).
- Hardware acceptance/soak (out of scope; no cutover).

## 11. New defects found

| Defect | Detected by | Fix/status |
|---|---|---|
| `shellcheck -S style scripts/*.sh` fails on SC2012 in retired `root-migrate.sh` | gate 05 | fixed in `665fdf4`; rerun green |
| Running system has gid 100, not the declared target gid 1000; stage group 1000 is `UNKNOWN` pre-switch | `id` / `getent group 1000` | record as sequencing condition; verify after first switch |
| Worktree count claim: 53 absolute worktree pointers; 33 relative submodule gitdirs are separate | corrected spot count | 53 all resolve; phase-2 repair remains |
| DB+WAL pair claim 494 vs measured 453 | spot count | actual source/stage 453 pairs; one DB excluded under `node_modules`; reconcile brief |
| No previous system generation exists | `nix-env --list-generations` / `bootctl list` | cutover blocker |
| 45 in-scope `.env` files were not excluded by the filter/oracle | secret-path audit against `evidence/migration/secret-path-inventory.txt` | fixed in `676617e`; rehearsal asserts `excluded .env: absent`; real stage re-checked |
| n8n DB absent from the scoped backup | `find Learns/vibing/n8n` | out of scope per owner 2026-11-02; no row check, not a blocker |
| First spot-check opened staged SQLite DBs in place and removed 5 zero-byte WAL/32 KiB SHM files | `rsync -n -c` after spot check | repaired from read-only source; copy-only spot check; full verify rerun; `08`/`09` evidence |
| 75 root-owned entries outside `.herdr`/BLIV are in the stage | `06-restore-post.log` | record as ownership-policy deviation; owner to map or exclude before cutover |
| `restore-home.sh` per-path rsync split 3,830 cross-include hardlink groups | copy-only hardlink-group audit (`spot-hardlink-groups.txt`) | fixed in `281f791` (single rsync); current stage relinked; final verify rerun |
| The in-place relink left 111 temporary `.relink.*` names | post-relink inode-group audit | removed; 0 temp names remain; group check 0 broken |
| Directory-mtime refresh with `rsync -a` reverted 32,945 mapped owners to root | `find -uid 0` / `no-uid-0-in-mapped-trees` | re-applied `chown -h 1000:1000` in `.herdr`/BLIV only; mapped count 0; full verify restarted |

## 12. Evidence index

- `/var/log/duniawi-migration/20261102T103246/00-preflight.log`
- `01-apply-patches.log`
- `02-stage-before.log`
- `03-stage-removal.log`
- `04-rollback-baseline.log`
- `gates.tsv`, `gates/`
- `restore.log`, `restore.rc`, `restore.elapsed`
- `06-restore-post.log`, `root-owned-outside-mapped.txt`
- `verify.log`, `verify.tsv`, `not-explained.txt`, `exclusion-ledger.tsv`
- `verify-before-spotcheck-mutation.tsv` (first green run, preserved)
- `08-spotcheck-mutation.log`, `09-repair-spotcheck-mutation.log`, `09-fast-drift.txt`
- `10-hardlink-repair.log`, `10b-relink-temp-cleanup.log`, `spot-hardlink-groups.txt`, `spot-stage-inodes-final.tsv`
- `10c-dir-mtime-refresh.log`, `10d-remap-after-refresh.log`
- `07-spot-checks.log`, `spot-*.txt`
- `go-no-go.md`
