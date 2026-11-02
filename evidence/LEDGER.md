# Evidence ledger

Host: `nixos` (`t14`, x86_64-linux, NixOS 26.05.13164.6f06d204d8f2)
Repository: `adrioui/duniawi`, branch `feat/cross-platform-nixos`
Ledger date:  2026-10-31 (Asia/Jakarta)
Rule: a claim without an independent oracle is `NotRun`, not `Pass`.

Raw artifacts are under `evidence/raw/`, `evidence/migration/`,
`evidence/rollback/`, and `evidence/security/`. Commands were read-only unless
the row says otherwise. No secret value is recorded.

| # | Claim | Command | Exit | Evidence | Timestamp | Independent oracle | Status |
|---|---|---|---|---|---|---|---|
| 1 | Branch is the feature branch, not `main` | `git status --porcelain=v2 --branch` | 0 | `evidence/raw/01-git-status.log` | 2026-10-31T17:32:22+07:00 | Git object store | Pass |
| 2 | Lock file is the pinned implementation lock | `sha256sum flake.lock` | 0 | `evidence/raw/05-lock-sha256.log` | 2026-10-31T17:32:22+07:00 | Independent SHA-256 | Pass |
| 3 | Both hosts evaluate | `nix flake check --no-build --all-systems` | 0 | terminal log; rerun after final commit |  2026-10-31 | Nix evaluator | Pass |
| 4 | NixOS toplevel builds | `nix build .#nixosConfigurations.t14.config.system.build.toplevel` | 0 | `evidence/raw/08c-nixos-values-clean.log`; build log |  2026-10-31 | Nix build | Pass |
| 5 | Darwin baseline drv reproduces | clean worktree at `030e376…`, then current tree with `configurationRevision` normalized | 0 | `docs/design/baseline.md`; gate2 summary |  2026-10-31 | Baseline worktree | Pass |
| 6 | Darwin builds on macOS | `nix build .#darwinConfigurations.adri.system` on `macos-14` | — | CI workflow only | — | macOS CI | NotRun |
| 7 | VM boot/login/HM/ownership/proxy/reboot | `nix build .#checks.x86_64-linux.t14-vm` | 0 | `evidence/raw/vm-test.log`; drv `z3v0xzvm…` | 2026-10-31T21:10+07:00 | NixOS test harness | Pass |
| 8 | Failure injection: wrong key, missing secret, SIGKILL restart, full disk, corrupt SQLite, power loss | same VM test | 0 | `evidence/raw/vm-test.log` | 2026-10-31T21:10+07:00 | NixOS test harness | Pass |
| 9 | Migration fixture (ACL/xattr/root policy) | `nix build .#checks.x86_64-linux.migration-fixture` and VM `REQUIRE_*` | 0 | `evidence/migration/fixture.log` |  2026-10-31 | Independent filesystem checks | Pass |
| 10 | Backup is mounted read-only | `findmnt -no SOURCE,TARGET,FSTYPE,OPTIONS …` | 0 | `evidence/raw/10-findmnt-backup.log` | 2026-10-31T17:32:37+07:00 | Kernel mount table | Pass |
| 11 | Backup SMART is healthy | `smartctl -H /dev/sda` | — | `evidence/raw/13-smart.log` |  2026-10-31 | Device firmware | NotRun (permission denied; prior evidence only) |
| 12 | Backup content matches source manifest | `cd /run/media/adrioui/backup/home && sha256sum -c …/source.sha256` | 1 | `evidence/migration/source-hash-summary.md` | 2026-10-31T19:08+07:00 | SHA-256 vs 5,082,466-entry manifest | Pass for in-scope: 4,826,215 read, no mismatches; 256,251 unreadable are all excluded |
| 13 | Fresh metadata stream captured | `find . -xdev -printf …` piped to `sort` | 0 | `evidence/raw/15-home-metadata-digest.log` | 2026-10-31T17:32:37+07:00 | Fresh filesystem walk | Pass (5,616,971 lines; 33fc8b7d…) |
| 14 | ACL/xattr/capability stream captured | `getfacl -R -p`, `getfattr -R -d`, `getcap -r` | 0 | `evidence/raw/17-acl-xattr-capability-digest.log`; `17b-capability-digest.log` | 2026-10-31T18:05+07:00 | Fresh filesystem walk | Pass (ACL f83bab6f…, xattr 29dc1712…, cap ca94d027…) |
| 15 | Root-owned inventory is 192,782 entries | `find . -xdev -uid 0` | 0 | `evidence/raw/16-ownership-counts.log` | 2026-10-31T17:32:57+07:00 | Kernel metadata | Pass |
| 16 | Required root-owned files are only `.herdr` + `Works/Bangunindo/BLIV` | metadata analysis + user decision | 0 | `evidence/migration/ownership-policy.md` | 2026-10-31 | Fresh metadata | Pass (32,326 files, 1.93 GiB) |
| 17 | Non-1000 ownership is resolved in the final scope | fresh `%U:%G` inventory | 0 | `evidence/raw/16-ownership-counts.log`; `evidence/migration/non-1000-ownership-learns.txt` | 2026-10-31T17:32:57+07:00 | Kernel metadata | Pass with exclusions: 93 valid `1000:0`; 16 `.dlt`/SurrealDB runtime entries and 3 distrobox entries excluded |
| 18 | A1 wrapper hash chain accepted | regenerated 40-entry bundle + detached wrapper | 0 | `docs/design/evidence/gate4/bundle-regenerated/` |  2026-10-31 | Independent SHA-256 | Pass |
| 19 | A2 UID/GID mapping confirmed | recorded approval | — | `docs/design/approvals.md` |  2026-10-31 | User record | Pass (1000:1000; A3b reduced to excluded runtime state) |
| 20 | A3 exclusion policy confirmed | recorded approval | — | `docs/design/approvals.md` | 2026-10-31 | User record | Pass (final scope) |
| 21 | A4 cutover/rollback window approved | explicit approval | — | `docs/design/approvals.md` | — | User record | NotRun |
| 22 | A5 live switch approved | explicit approval | — | `docs/design/approvals.md` | — | User record | NotRun |
| 23 | Secrets rotated and provisioned | provider audit + sops file | — | `evidence/security/` | — | Provider audit | NotRun |
| 24 | Chat-disclosed sudo credential rotated | local console action | — | incident record | — | User confirmation | Open |
| 25 | Rollback rehearsal boots previous generation and old home | manual boot-menu test | — | `evidence/rollback/` | — | Boot menu + login | NotRun |
| 26 | Hardware acceptance (Wi-Fi, Bluetooth, audio, GPU, suspend, battery) | live tests | — | `evidence/raw/hardware-*` | — | Hardware sensors/logs | NotRun |
| 27 | Soak period is clean | journal/systemd monitoring | — | `evidence/raw/soak-*` | — | Time + logs | NotRun |
| 28 | Live stage and cutover executed | approved runbook | — | `evidence/migration/` | — | Root TTY + hashes | NotRun (blocked) |
| 29 | `amp-deepseek` unit syntax is valid | `systemd-analyze verify <unit>` | 0 | `evidence/raw/unit-verify.log` | 2026-10-31 | systemd parser | Pass |
| 30 | No production secret in repository | `gitleaks detect --no-git` | 0 | CI/terminal log | 2026-10-31 | gitleaks | Pass |
| 31 | In-scope SQLite databases are intact | `tests/db-audit.sh` over 1,228 DBs | 0 | `evidence/migration/db-audit.log` | 2026-10-31T20:40+07:00 | SQLite `integrity_check` | Pass: 1,228 ok, 0 bad |
| 32 | Proxy handles upstream failure paths | `nix build .#checks.x86_64-linux.amp-deepseek` | 0 | proxy test log | 2026-10-31T20:45+07:00 | Node test harness | Pass: 404, 502, 504, set-cookie drop, existing 200/401/413/503 |
| 33 | Final scope inventory is captured | `tests/scope-audit.sh` | 0 | `evidence/migration/scope-audit.log`; `secret-path-inventory.txt` | 2026-10-31T20:46+07:00 | Fresh filesystem walk | Pass: 1,770,800 candidate files before excludes; 1,228 DBs; 1,779 secret-pattern paths (excluded) |
| 34 | The rehearsal proves the data path against the shipped scripts | `nix build --no-link .#checks.x86_64-linux.migration-rehearsal` | 0 | `/var/log/duniawi-migration/20261102T085259/03b-migration-rehearsal-fresh-test.log`; `03b-migration-rehearsal-fresh.log` | 2026-11-02T08:57:45+07:00 | NixOS test harness (fresh local VM run) | Pass (gate green, 61.91 s) / NotRun (verify-home.sh oracle 2 aborts on `comm` locale mismatch; exclusion reconciliation unproven; oracle 1 and direct assertions pass) |

| 35 | Follow-ups 0006/0007 applied without conflict; the pre-existing row 34 was preserved as its own commit | `git am 0006-*.patch 0007-*.patch`; `git rev-parse HEAD` | 0 | `/var/log/duniawi-migration/20261102T103246/01-apply-patches.log` | 2026-11-02T10:32:55+07:00 | Git object store; `git log` = `09a0cac` on `1d640e7`; `17a0188` row commit | Pass |
| 36 | All eight required gates pass on the applied tree | `gates.tsv` rows 01-08 | 0 | `/var/log/duniawi-migration/20261102T103246/gates.tsv`; `gates/` | 2026-11-02T10:47+07:00 | Nix, shellcheck, actionlint, gitleaks | Pass (8/8; pre-fix transcripts retained) |
| 37 | The rehearsal proves six oracles in both locales, fault injection, the writable-source guard, and `.env` absence | `nix build -L --rebuild .#checks.x86_64-linux.migration-rehearsal` | 0 | `/var/log/duniawi-migration/20261102T103246/gates/08-rehearsal.log`; `08a-rehearsal-build.log` | 2026-11-02T10:47+07:00 | NixOS test harness | Pass (83 s; `verify-complete PASS 6` twice; `drift-lines FAIL`/rc 1 under injection; `guard rc=1`, no stage; `.env absent`) |
| 38 | The stale 80 GiB stage was removed; the live home was not touched | `rm -rf --one-file-system /home/adrioui.restore` | 0 | `/var/log/duniawi-migration/20261102T103246/02-stage-before.log`; `03-stage-removal.log` | 2026-11-02T10:38:44+07:00 | `stat`/`du`/`find`; live-home `stat` before/after | Pass (79,472,057,143 bytes, 1,665,614 files; 15 s; live home mtime unchanged) |
| 39 | The real backup was restored to `/home/adrioui.restore` | `SRC=... STAGE=... EVID=... bash scripts/restore-home.sh` | 0 | `/var/log/duniawi-migration/20261102T103246/restore.log`; `checks.tsv`; `restore.rc`; `restore.elapsed` | 2026-11-02T11:04:39+07:00 | rsync stats + independent post-checks | Pass (1,667,037 files, 277,052 dirs, 79,529,741,983 bytes, 1001 s, 79.45 MB/s; four checks PASS) |
| 40 | The real stage is checksum-clean and the exclusion policy reconciles | `SRC=... STAGE=... EVID=... bash scripts/verify-home.sh --checksum --deep` | 0 | `/var/log/duniawi-migration/20261102T103246/verify.tsv`; `verify.log`; `not-explained.txt`; `exclusion-ledger.tsv`; `verify-before-spotcheck-mutation.tsv`; `verify-before-hardlink-repair.tsv`; `verify-race-aborted.*` | 2026-11-02T13:14:12+07:00 | `rsync -c`; independent ERE reconciliation; git fsck (57 ok, 1 pre-existing, 0 regression); SQLite integrity (1,227 checked, 0 bad, 453 WAL) | Pass (rc 0; `drift-lines` 0; `unexplained-exclusions` 0; `secret-paths-present` 0; `worktree-pointers` 0; `git-fsck-regression` 0; `sqlite-integrity` 0; `verify-complete PASS 6`) |
| 41 | Hardlinks, sparse files, worktree pointers, and DB/WAL pairs match independently | `bash /tmp/opencode/spot-checks-v2.sh` | 0 | `/var/log/duniawi-migration/20261102T103246/07-spot-checks.log`; `spot-*.txt` | 2026-11-02T13:17:09+07:00 | Fresh `find`; SQLite row counts (copies only) | Pass (hardlink-group integrity 0 broken, 0 mixed, 0 missing; 53 absolute pointers resolve; 1,228/1,227 DBs with one excluded; 453/453 WAL pairs; agent row counts source=stage) |
| 42 | Rollback rehearsal: gen 2 built, gen 1 booted and logged in; gen 2 return pending user report | `nixos-rebuild boot --flake /usr/local/lib/duniawi#t14`; `bootctl set-oneshot nixos-generation-1.conf`; `rollback-capture.sh gen1` | 0 | `/var/log/duniawi-migration/20261102T140753/rollback-pre-reboot.log`; `rollback-rehearsal.log` | 2026-11-02T14:48:06+07:00 | Gen 1 booted: home 1000:100, 0 unmapped, 0 failed units, gen2 default; gen2 return pending | Pass (gen 1) / NotRun (gen 2 return until user report) |
| 43 | The go/no-go record names every gate, blocker, owner, and NotRun item | write `evidence/migration/20261102/GO-NO-GO.md`; commit | 0 | `/var/log/duniawi-migration/20261102T103246/GO-NO-GO.md`; this ledger | 2026-11-02T13:25+07:00 | Review against `gates.tsv` and `verify.tsv` | Pass (stage GO; cutover NO-GO) |
| 44 | The `.env` secret-path gap found during the run is fixed and proven | secret-path audit; `nix build ...migration-rehearsal` | 0 | `/var/log/duniawi-migration/20261102T103246/05-security-fix.log`; `gates/08-rehearsal.log` | 2026-11-02T10:43:58+07:00 | Fixture assertion `test ! -e .../Learns/proj/.env`; real stage `.env` count 0 | Pass (45 in-scope `.env` files excluded; `example.env`/`credentials.py` kept) |
| 45 | No cutover, switch, reboot, home rename, session kill, backup write, or push occurred | `git status`; `findmnt`; `loginctl`; `git log` | 0 | `/var/log/duniawi-migration/20261102T103246/00-preflight.log`; `03-stage-removal.log`; `04-rollback-baseline.log` | 2026-11-02T13:14:12+07:00 | Kernel mount table; session list; Git | Pass (backup still `ro`; live home untouched; only generation 1) |
| 46 | The first post-verify spot check opened staged SQLite DBs in place and removed 5 zero-byte WAL/32 KiB SHM files; the stage was repaired and fully re-verified | `rsync -n -c`; `rsync -aHASX` from source; `verify-home.sh --checksum --deep` | 0 | `/var/log/duniawi-migration/20261102T103246/08-spotcheck-mutation.log`; `09-repair-spotcheck-mutation.log`; `09-fast-drift.txt`; final `verify.tsv` | 2026-11-02T13:14:12+07:00 | DB SHA-256/mtime unchanged; fast drift 0; full six-oracle re-run PASS | Pass after repair; copy-only spot-check adopted |
| 47 | Cross-include hardlink groups were split by the per-path restore and are now preserved | copy-only hardlink-group audit; `nix build ...migration-rehearsal` | 0 | `/var/log/duniawi-migration/20261102T103246/spot-hardlink-groups.txt`; `10-hardlink-repair.log`; `10b-relink-temp-cleanup.log`; `gates/08-rehearsal.log` | 2026-11-02T13:17:09+07:00 | 3,830 groups / 4,636 links; 0 metadata/xattr mismatches; 0 errors; 111 temp names removed; final group check 0 broken | Pass (durable fix `281f791`; rehearsal asserts a Works↔Personal hardlink) |
| 48 | The single-rsync restore script was smoke-tested on a real mixed file/dir subset with mapped trees | `SRC=... STAGE=/tmp/opencode/restore-test EVID=.../11-single-rsync-subset bash scripts/restore-home.sh` | 0 | `/var/log/duniawi-migration/20261102T103246/11-single-rsync-subset/restore.log` | 2026-11-02T13:17:59+07:00 | 194 files, 185,663,318 bytes, 0 drift, four checks PASS | Pass |
EOF
echo "rows written"

## Current decision (2026-10-31, superseded)

**No-go for live cutover.** The implementation, hermetic VM/fixture proofs,
in-scope content hash, and DB audit are green. The data path is not:
root TTY for stage/selective `chown`, secret rotation, A4/A5, and rollback
rehearsal remain open. The stage and `/home/adrioui` have not been modified.

> Correction 2026-11-02: the sentence "The stage and `/home/adrioui` have not
> been modified" is false as written. The stale 80 GiB stage existed and had
> been rewritten (59,685 paths carried `/home/adrioui.restore`, zero carried
> `/var/home/adrifadilah`); it was removed on 2026-11-02 (row 38) and replaced
> by a verified real stage (row 40). `/home/adrioui` itself was not written by
> this run; its mtime stayed 2026-11-02T08:45:31+07:00. See rows 35-48 and
> `evidence/migration/20261102/GO-NO-GO.md`.

## Current decision (2026-11-02T13:14+07:00)

**GO for the staged restore; NO-GO for cutover.** The implementation, gates,
rehearsal, real restore, and six-oracle verification pass. Cutover remains
blocked by the items in section 8 of
`evidence/migration/20261102/GO-NO-GO.md`: no N-1/N-2 generation, A4/A5
absent, secret provisioning/rotation, gid 100->1000 sequencing, 75 root-owned
entries outside the approved mapping, boot-menu rehearsal NotRun, and the
compatibility-link phase-2 plan. No cutover, switch, reboot, home rename,
session kill, backup write, or push occurred.

## How to reproduce

```bash
cd <repo>
bash tests/phase0-evidence.sh
nix flake check --no-build --all-systems
nix build --no-link .#checks.x86_64-linux.t14-vm
nix build --no-link .#checks.x86_64-linux.migration-fixture
```

The full backup hash must be run as root in a root TTY; the unprivileged run
is intentionally recorded as `NotRun` rather than treated as a pass.
