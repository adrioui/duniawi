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

## Current decision

**No-go for live cutover.** The implementation, hermetic VM/fixture proofs,
in-scope content hash, and DB audit are green. The data path is not:
root TTY for stage/selective `chown`, secret rotation, A4/A5, and rollback
rehearsal remain open. The stage and `/home/adrioui` have not been modified.

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
