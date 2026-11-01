# ADR-0009: Keep the old home paths readable with a link; never rewrite restored data

- Status: Proposed — supersedes the rewrite step of ADR-0006; requires
  Approval 2 (revised), Approval 3, and a new Approval 6 for the link
- Date: 2026-11-01
- Deciders: repository owner
- Related: `docs/design/adr/0003-uid-gid-mapping.md`,
  `docs/design/adr/0006-staged-migration-and-rollback.md`,
  `docs/design/migration.md`, `docs/design/exclusions.md`

## Context

ADR-0003 settles ownership: the target account is `adrioui`, uid 1000, with a
local group `adrioui` at gid 1000, so restored `1000:1000` needs no mapping and
no recursive `chown`.

ADR-0006 step 6 rewrites old home paths inside text files. Four measurements
made during review show that step is unsafe and ineffective:

1. `sed -i` replaces the inode. On a file rsync had restored correctly
   (mode 640, `links=2`, `user.keep` xattr, `group:users:r--` ACL), one rewrite
   pass left `links=1`, dropped the xattr, and dropped the ACL. The hardlinked
   second name still contains the old path.
2. The rewrite is size-preserving: `/var/home/adrifadilah` and the staging
   prefix are both 21 bytes. rsync's default quick check (size + mtime)
   therefore reports the rewritten tree as identical to the source, and any
   size-based audit cannot see it.
3. The rewrite cannot reach binary payloads. SQLite path columns, archives and
   media keep the old string while text files move, so the tree ends up in a
   mixed state that no single rule describes.
4. `/home/adrioui.restore` on the target already contains such a rewrite:
   59,685 files carry the staging prefix and zero carry the original. That tree
   cannot be verified against the backup and cannot be used as a stage.

Separately, the name-only exclusion `**/credentials*` in
`scripts/root-migrate.sh` removed 563 in-scope files whose basename merely
begins with `credentials`, including 302 `.py` files (`botocore/credentials.py`,
`google/auth/oauth2/credentials.py`, `redis/credentials.py`) and 144 `.pyc`
artifacts. The inventory it was derived from lists 1,779 "secret" paths, of
which at least 703 are provably not secrets: 106 `cacert.pem` bundles, 152
`example.env` templates, 301 `credentials.py` modules, 144 `.pyc` files.

## Decision

1. **Do not rewrite restored content.** The stage is byte-identical to the
   backup for every included file. No `sed`, no in-place edit, no
   `--usermap`/`--chown` pass after the copy.
2. **Make the old paths resolve with a declarative link**, in a new aspect
   `den.aspects.homeMigration` (`modules/home-migration.nix`):

   ```nix
   systemd.tmpfiles.rules = [
     "d /var/home 0755 root root -"
     "L /var/home/adrifadilah - - - - /home/adrioui"
   ];
   ```

   `L` is the rule type NixOS itself uses for `/var/lock`. A symlink is
   resolved per lookup, so it follows the home across the cutover rename; a
   bind mount would pin the pre-migration inode.
3. **Anchor every exclusion.** Rules are absolute paths or exact basenames.
   A name-only prefix glob is a copy defect. Each rule carries a ledger row
   with its matched count and a `code removed?` flag.
4. **Verify with two independent oracles**: `rsync -c` drift, and an ERE
   restatement of the exclusion policy that fails on any file the policy
   cannot explain. A size or mtime comparison is not an oracle.
5. **Defer git worktree repair.** The link makes the existing
   `gitdir:` pointers resolve, so `git status`, `fsck` and commits work with
   zero mutation. `git worktree repair <path>` for the 53 worktrees is phase-2
   work, done together with removing the link.
6. **Discard the existing stage.** `restore-home.sh` refuses to start while
   `/home/adrioui.restore` exists.

## Consequences

- The stage can be re-verified against the immutable backup at any time,
  including immediately before the swap. That is impossible after a rewrite.
- ACLs, xattrs, file capabilities, hardlinks and sparse files survive, because
  nothing touches them after `rsync -aHASX`.
- Historical data keeps historical paths: 59,685 transcripts and the SQLite
  payloads that embed them will always mention `/var/home/adrifadilah`. That is
  correct — they describe what happened — and it is recorded as accepted rather
  than "to be cleaned up".
- The link has one measurable limitation: `find /var/home/adrifadilah` without
  a trailing slash returns the link itself, not the tree. Documented; phase-2
  work removes the link.
- The link is a residual-reference hiding place. Removal is gated on a ledger
  of remaining references per directory (Approval 6).
- The ledger row that states "the stage and `/home/adrioui` have not been
  modified" is contradicted by the stage on disk and must be corrected.

## Alternatives considered

| Alternative | Why rejected |
|---|---|
| Rewrite text files in the stage (ADR-0006 step 6) | destroys inode metadata; cannot reach binaries; unverifiable afterwards; already applied to the stage on disk |
| `users.users.adrioui.home = "/var/home/adrifadilah"` | supported by the module system, but abandons the flake's `/home/adrioui` contract, contradicts `modules/vm-test.nix`, and keeps a dead username in `$HOME` forever |
| Bind mount `/var/home/adrifadilah` | transparent to `find`, but pins the inode, so it points at the pre-migration tree after the cutover rename |
| Rename the account to `adrifadilah` | two accounts cannot share uid 1000; a declared uid change on an existing user is refused; breaks the Darwin/shared-aspect naming |
| Copy secrets and rotate later | extends the exposure window; `**/credentials*` already shows the cost of name-based guessing |

## Verification

```bash
nix eval --json .#nixosConfigurations.t14.config.systemd.tmpfiles.rules
# contains "L /var/home/adrifadilah - - - - /home/adrioui"

nix eval --json .#nixosConfigurations.t14.config.users.users.adrioui \
  --apply 'u: { inherit (u) uid home group; }'
# {"group":"adrioui","home":"/home/adrioui","uid":1000}

nix build --no-link .#checks.x86_64-linux.migration-rehearsal
# restore + verify against a fixture; drift 0, unexplained exclusions 0,
# library code kept, secrets absent, 1000:1000, ACL/xattr/setuid/cap/hardlink
# preserved, WAL database intact, worktree pointer resolves
```

The rehearsal runs the shipped `scripts/restore-home.sh` and
`scripts/verify-home.sh`, so the gate tests the code that will run on the
target, not a transcription of it.
