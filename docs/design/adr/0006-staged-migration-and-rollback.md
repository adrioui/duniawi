# ADR-0006: Stage, verify, cut over, roll back

- Status: Proposed — requires Approvals 1–5
- Date: 2026-10-31
- Deciders: repository owner
- Related: `docs/design/migration.md`, `docs/design/rollback.md`,
  `docs/design/exclusions.md`

## Context

The old home is ~282.73 GiB across 5,082,466 manifest entries. It contains
192,782 root-owned entries (170,171 regular files); only
`.herdr` and `Works/Bangunindo/BLIV` are required. There are five broken home-manager symlinks,
a live OpenCode database, and plaintext secrets.
The backup HDD is read-only. An in-place copy into `/home/adrioui` would
destroy the only working home if anything failed.

## Decision

Use a staged migration:

1. Freeze and baseline.
2. Verify the read-only backup: mount options, SMART, manifest digests, root
   hash verification.
3. Apply the approved exclusion policy.
4. Copy with `rsync -aHAX --numeric-ids` into `/home/adrioui.restore`.
5. Verify stage hashes, metadata, ownership, ACL/xattr/hardlinks, SQLite
   integrity, and secret absence.
6. Rewrite old home paths in text files only.
7. Provision new keys/secrets; do not copy old ones.
8. Prove the NixOS generation in a VM, including reboot and rollback.
9. Cut over from a root TTY: stop user processes, make a consistent live DB
   backup, rename the old home to `/home/adrioui.pre-migration`, rename the
   stage to `/home/adrioui`, activate, reboot, log in.
10. Rehearse rollback and retain the old home and N-1/N-2 generations until
    acceptance.

No `nixos-rebuild switch` until the VM/test gates pass and Approval 5 is
recorded.

## Consequences

- The live home is untouched during the long copy.
- The old home remains available for rollback.
- The migration needs root, ~350 GiB free, and a maintenance window.
- Secrets are rotated, not migrated; old services are archived.
- The live OpenCode DB is preserved in place; the backup copy is never
  restored over it.
- A failed step stops the migration; no destructive retry.

## Alternatives considered

| Alternative | Why rejected |
|---|---|
| `rsync` directly into `/home/adrioui` | destroys the only working home on failure |
| Fresh home, copy only documents | loses app data and requires manual reconstruction |
| Restore from backup over live DB | corrupts/loses the live OpenCode state |
| Copy secrets and rotate later | extends the exposure window |
| Cut over before VM proof | violates the gate and risks an unbootable host |

## Verification

- Stage manifest diff empty (except approved path rewrites).
- No unmapped UID/GID; no dangling symlinks; no secret hits.
- VM boot/login/HM/proxy/reboot/rollback pass.
- Cutover login and data spot-checks pass.
- Rollback rehearsal passes.
- Old home and generations retained.
