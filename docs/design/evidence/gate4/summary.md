# Gate 4 migration fixture summary

- Date: 2026-10-31
- Build check: `nix build .#checks.x86_64-linux.migration-fixture` → **Pass**
- VM check: `REQUIRE_ACL=1 REQUIRE_FULL_DISK=1 REQUIRE_ROOT=1 TMPDIR=/tmp
  bash /etc/migration-fixture.sh` inside `checks.x86_64-linux.t14-vm` →
  **Pass** (exit 0, 3.84 s)
- Fixture source: `tests/migration-fixture.sh`
- VM derivation: `/nix/store/03b822j6s49kfi2k4nx5204wrli913fk-vm-test-run-t14-vm.drv`

The fixture verifies:

- content preservation;
- hardlink inode/link count;
- relative symlink;
- timestamps;
- numeric ownership;
- ACL preservation (required in VM);
- xattr preservation (required in VM);
- exclusion of `.config/` secret/personal files, `.clawdbot/`, and
  `clickhouse-local/`;
- SQLite `PRAGMA integrity_check` on the copied database;
- a corrupted SQLite copy fails the check;
- a 1 MiB full destination fails the copy with `ENOSPC`;
- root-owned `.herdr/` and `Works/Bangunindo/BLIV/` fixtures map to
  `1000:1000`; a root-owned `Personal/` fixture is excluded.

Limits:

- The Nix build sandbox does not support ACLs, xattrs, or root-owned fixtures,
  so the build check skips those with a printed result. The VM run requires
  them (`REQUIRE_ACL=1 REQUIRE_FULL_DISK=1 REQUIRE_ROOT=1`) and passes on the
  VM ext4 filesystem.
- The fixture does not prove the real 282 GiB copy. It proves the copy flags,
  exclusion logic, metadata preservation, and failure behavior before the real
  stage.
- No real backup data was read or written for this fixture.

## Bundle hash-chain remediation

`bundle-regenerated/` contains the corrected A1 evidence: 40 entries, detached
wrapper hash, no self-reference. `sha256sum -c` passes 40/40 and the wrapper
check passes. The user accepted this regenerated chain on 2026-10-31; the
original mismatch was not waived.
