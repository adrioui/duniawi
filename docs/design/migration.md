# Migration runbook

Status: **Gate 1 draft — blocked until Approvals 1–5 and root access**

This runbook migrates the old Fedora home from the read-only `backup` HDD into
the new NixOS host `t14` **without touching `/home/adrioui` during staging**.
It is written to be executed from a root TTY or live USB, not from the live
desktop session.

## 0. Non-negotiable rules

1. Never write to `/run/media/adrioui/backup`. It stays
   `ro,nosuid,nodev,relatime`.
2. Never copy secrets from the backup. Rotate or recreate them.
3. Never copy the old proxy stack. The only proxy on NixOS is the repo-owned
   `amp-deepseek-proxy`, with new sops secrets.
4. Never copy the live OpenCode database from the backup over the live one.
5. Never `rsync` directly into `/home/adrioui`. Stage at
   `/home/adrioui.restore`.
6. Never run `nixos-rebuild switch` until VM gates pass and Approval 5 is
   recorded.
7. Stop on any hash mismatch, metadata mismatch, missing file, DB corruption,
   unmapped ownership, insufficient space, secret leak, failed login, or
   failed rollback.
8. Do not put a password, passphrase, token, or key on a command line.
9. Keep the old home and N-1/N-2 generations until acceptance.
10. Record every command and result in `/var/log/duniawi-migration/` with
    secrets redacted.

## 1. Prerequisites

| Requirement | Check | Blocker if absent |
|---|---|---|
| Root TTY or live USB | `tty`, `id -u` = 0 | yes |
| Backup mounted read-only | `findmnt -no OPTIONS /run/media/adrioui/backup` contains `ro` | yes |
| Backup identity | label `backup`, UUID `cdb0183d-7f36-4415-802c-0a36e8f7df10` | yes |
| SMART health | `smartctl -H /dev/sda` = PASSED | yes |
| Manifest pair | both 5,082,466 lines; SHA-256 `7bdf05b3…` | yes |
| Wrapper mismatch accepted | Approval 1 | yes |
| UID/GID mapping accepted | Approval 2 | yes |
| Exclusion policy accepted | Approval 3 | yes |
| Cutover/rollback window accepted | Approval 4 | yes |
| Live switch accepted | Approval 5 | yes |
| Target space | `df -h /` ≥ 350 GiB free; `df -i /` ≥ 6M free inodes | yes |
| Target host evaluates | `nix eval .#nixosConfigurations.t14.config.system.build.toplevel.drvPath` | yes |
| VM proof | Gate 4 evidence | yes |
| Secrets rotated | `secrets.md` Phase 1 complete | yes |
| No old proxy enabled | `systemctl --user list-unit-files --state=enabled` | yes |

## 2. Gate map

| Gate | Name | Exit condition |
|---|---|---|
| 0 | Freeze / baseline | HEAD, lock hash, Darwin eval, NixOS baseline, backup evidence recorded |
| 1 | Design review | domain, graph, compatibility, packages, services, secrets, exclusions, migration, rollback, test plan, ADRs approved |
| 2 | Implementation | NixOS host evaluates/builds; Darwin unchanged; static checks pass |
| 3 | VM proof | VM boots, login works, HM activates, proxy health passes, no old units |
| 4 | Migration integration | Stage copy, drift/exclusion/DB/pointer checks, link installed, login proof |
| 5 | Cutover | Approved rename/switch/reboot, rollback rehearsal |
| 6 | Release / handoff | PR, docs, evidence, old home retention, closeout |

This runbook covers Gates 4–6. Gate 3 must be complete first.

## 3. Pre-flight (read-only)

Run as root from the backup root. Capture all output.

```bash
export EV=/var/log/duniawi-migration/$(date +%Y%m%d-%H%M%S)
install -d -m 0700 "$EV"
exec > >(tee -a "$EV/preflight.log") 2>&1

findmnt -no TARGET,SOURCE,FSTYPE,OPTIONS /run/media/adrioui/backup
blkid /dev/sda1
smartctl -H /dev/sda
smartctl -A /dev/sda | grep -E 'Reallocated_Sector_Ct|Current_Pending_Sector|Offline_Uncorrectable|UDMA_CRC_Error_Count'
df -h / /run/media/adrioui/backup
df -i / /run/media/adrioui/backup

sha256sum /run/media/adrioui/backup/evidence-20261030/gate3/source.sha256
sha256sum /run/media/adrioui/backup/evidence-20261030/gate3/destination.sha256
wc -l /run/media/adrioui/backup/evidence-20261030/gate3/source.sha256
wc -l /run/media/adrioui/backup/evidence-20261030/gate3/destination.sha256
```

Expected: mount options include `ro,nosuid,nodev,relatime`; SMART PASSED;
reallocated/pending/CRC zero; both manifests 5,082,466 lines and SHA-256
`7bdf05b3ae049c8b1dd7a5e4e5f3052ffca7004fb3caccb1f28b0e89a222c06d`.

Stop on any mismatch. Do not "fix" the backup.

## 4. Manifest and root hash verification

The wrapper `BUNDLE.sha256.sha256` has a recorded/actual mismatch
(`654c567d…` vs `8bafbeb0…`). Approval 1 must explicitly accept that the
remaining 40 bundle entries verify and the wrapper line is the only mismatch.

```bash
cd /run/media/adrioui/backup
grep -avE '  \./(BUNDLE\.sha256|BUNDLE\.sha256\.sha256)$' BUNDLE.sha256 > "$EV/BUNDLE.sha256.filtered"
sha256sum -c "$EV/BUNDLE.sha256.filtered" | tee "$EV/bundle-check.log"
```

Then verify the full home manifest as root. The earlier unprivileged run did
not complete because root-owned content was not readable. A later inventory
found 192,782 root-owned entries and 170,171 root-owned regular files; only
`.herdr/` and `Works/Bangunindo/BLIV/` are required. The ownership policy in
`docs/design/exclusions.md` section 4.1 applies: only those root-owned files
are mapped to `adrioui`; other root-owned files are excluded.

A read-only wrapper for the root portion is in `tests/root-verify.sh`. Run it
from a root TTY; it writes reports to `/var/tmp/duniawi-root-verify-*` and
does not copy, chown, or switch anything.

```bash
cd /run/media/adrioui/backup/home
sha256sum -c /run/media/adrioui/backup/evidence-20261030/gate3/source.sha256 \
  | tee "$EV/home-hash-check.log"
```

`sha256sum -c` writes failures to the log. A single `FAILED` line is a stop.
Do not proceed with a partial verification. If the manifest contains paths
outside the backup root, absolute paths, or `..`, stop and inspect.

## 5. Metadata inventory

Capture the source metadata before copying:

```bash
cd /run/media/adrioui/backup/home
find . -xdev -printf '%y %m %U:%G %s %p -> %l\n' | sort > "$EV/source-metadata.txt"
find . -xdev -type f -printf '%n %p\n' | awk '$1 > 1' | sort > "$EV/source-hardlinks.txt"
getfacl -R -p . > "$EV/source-acl.txt" 2> "$EV/source-acl.err" || true
getfattr -R -d -m - . > "$EV/source-xattr.txt" 2> "$EV/source-xattr.err" || true
```

Do not read secret file contents. Metadata is enough for the copy check.

## 6. Exclusion manifest

Apply the approved policy from `docs/design/exclusions.md`. The rules are one
reviewed file, `scripts/rsync-filter.rules`, which `scripts/restore-home.sh`
copies into `$EV`, hashes, and passes to rsync. Review it before staging:

```bash
$EDITOR scripts/rsync-filter.rules
```

Every rule must be an anchored path or an exact basename. A prefix glob
(`credentials*`, `*.pem`, `id_*`) is a copy defect: on this backup
`**/credentials*` alone removed 563 files, including 302 `.py` modules
(ADR-0009). Section 8 turns over-exclusion into a failing check rather than a
silent property.

## 7. Stage copy

Preconditions: Approval 3 recorded; stage path does not exist; target free
space ≥ 80 GiB.

```bash
SRC=/run/media/adrioui/backup/home \
STAGE=/home/adrioui.restore \
EVID="$EV" \
  bash scripts/restore-home.sh
```

The script refuses when the stage exists, checks free space, copies with
`rsync -aHASX --numeric-ids --relative` and the reviewed filter file,
re-applies `1000:1000` and mode `0700` to the stage root, and applies the
approved root-owned mapping only after counting setuid and capability files in
the mapped trees (it refuses rather than destroying them silently).

The copy must not write to the backup. Verify with `findmnt` after the copy.
Do not run `--delete` against the backup or the live home.

## 8. Stage verification

### 8.1 Two independent oracles

```bash
SRC=/run/media/adrioui/backup/home STAGE=/home/adrioui.restore EVID="$EV" \
  bash scripts/verify-home.sh --checksum --deep
```

- **Oracle 1 — per-file drift.** `rsync -n -c` with the same filter. Any line
  is drift; the gate is `drift-lines 0`. Without `-c` this is blind to an edit
  that preserves size and mtime, which is exactly the shape of the old rewrite.
- **Oracle 2 — exclusion reconciliation.** An ERE restatement of the exclusion
  policy, implemented independently of the rsync filter file. Any file present
  in the source and absent from the stage that the policy cannot explain is a
  copy defect: `unexplained-exclusions 0`.

A source-versus-stage checksum manifest is not required: with no rewrite the
oracles compare the stage against the immutable backup directly.

### 8.2 Metadata and ownership

```bash
cd /home/adrioui.restore
find . -xdev -printf '%y %m %U:%G %s %p -> %l\n' | sort > "$EV/stage-metadata.txt"
diff -u "$EV/source-metadata.txt" "$EV/stage-metadata.txt" > "$EV/metadata-diff.txt" || true
find . -xdev \( -nouser -o -nogroup \) -print > "$EV/unmapped-ownership.txt"
find . -xdev -xtype l -print > "$EV/dangling-symlinks.txt"
getfacl -R -p . > "$EV/stage-acl.txt" 2> "$EV/stage-acl.err" || true
getfattr -R -d -m - . > "$EV/stage-xattr.txt" 2> "$EV/stage-xattr.err" || true
```

Expected:
- `unmapped-ownership.txt` empty; `getent group 1000` is `adrioui`;
- `dangling-symlinks.txt` empty;
- ACL/xattr diffs explainable and approved;
- hardlink counts preserved (`rsync -H`);
- timestamps preserved (`rsync -a`).

#### 8.2.1 Root-owned mapping

The user-approved policy is narrow: map root-owned files under `.herdr/` and
`Works/Bangunindo/BLIV/`; exclude other root-owned files. Generate the source
lists before the copy and add the non-approved root-owned files to the
exclusion file:

```bash
cd /run/media/adrioui/backup/home
find . -xdev -uid 0 -type f -print | sort > "$EV/root-owned-files.txt"
grep -E '^\./(\.herdr/|Works/Bangunindo/BLIV/)' "$EV/root-owned-files.txt" > "$EV/root-owned-map.txt"
grep -vE '^\./(\.herdr/|Works/Bangunindo/BLIV/)' "$EV/root-owned-files.txt" > "$EV/root-owned-exclude.txt"
```

Review both lists. Then copy with `scripts/rsync-filter.rules` containing the approved
`root-owned-exclude.txt` entries. After the copy, map only the approved files
and their parent directories:

```bash
cd /home/adrioui.restore
xargs -r chown 1000:1000 < "$EV/root-owned-map.txt"
find .herdr Works/Bangunindo/BLIV -xdev -uid 0 -type d -print0 | xargs -0 -r chown 1000:1000
find . -xdev -uid 0 -type f -print > "$EV/root-owned-after.txt"
test ! -s "$EV/root-owned-after.txt"
```

Any remaining root-owned file in an included path is a stop condition. Do not
run a recursive `chown` over the home. Do not map root-owned credential files;
they are excluded earlier.

#### 8.2.2 Non-1000 ownership

Container and database runtime IDs are not part of the approved mapping. After
excluding container storage, `node_modules`, Yarn caches, and generated build
output, list every remaining `uid:gid` that is not `1000:1000` and is not an
excluded root-owned path:

```bash
cd /run/media/adrioui/backup/home
find . -xdev -printf '%U:%G %y %p\n' \
  | awk '$1 != "1000:1000" && $1 != "0:0"' \
  | grep -vE '(/node_modules/|^[^ ]+ [^ ]+ \./\.local/share/containers/|^[^ ]+ [^ ]+ \./Personal/financial/actual/\.yarn/cache/|^[^ ]+ [^ ]+ \./clickhouse-local/|^[^ ]+ [^ ]+ \./Works/)' \
  | sort > "$EV/non-1000-ownership.txt"
```

Of the 109 entries in Learns, 93 are valid `1000:0`; 16 are
`999:999`/`65532:65532` under `.dlt` and `surrealdb-data`, which are excluded
as runtime state. The 3 distrobox entries are excluded. If a future include
introduces an unapproved ID, stop and obtain approval naming the path, old ID,
new ID, and service impact. Do not run a blanket `chown`.

### 8.3 Database checks

Never overwrite the live OpenCode DB with the backup copy. The stage excludes
`.local/share/opencode/opencode.db*`. For any database that **is** restored
from backup, verify a copy, not the original:

```bash
for db in $(find /home/adrioui.restore -xdev -type f \( -name '*.sqlite' -o -name '*.db' \) -print); do
  cp --reflink=auto "$db" "$EV/check.db"
  sqlite3 "$EV/check.db" 'PRAGMA integrity_check;' | tee "$EV/db-check.log"
  rm -f "$EV/check.db"
done
```

A result other than `ok` is `DBCorruption`; stop.

### 8.4 Secret scan

```bash
grep -RInaE '(BEGIN (OPENSSH|RSA|EC|PGP) PRIVATE KEY|age1[a-z0-9]{20,}|sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16})' \
  /home/adrioui.restore > "$EV/secret-scan.txt" || true
```

This is a backstop, not a substitute for the exclusion policy. Any hit is a
`SecretLeak`; stop, identify the file, revoke/rotate, and remove it from the
stage.

## 9. No path rewrite

There is no rewrite step. Restored files stay byte-identical to the backup, and
old absolute paths are resolved by a declarative link installed with the system
generation (ADR-0009, `modules/home-migration.nix`):

```nix
systemd.tmpfiles.rules = [
  "d /var/home 0755 root root -"
  "L /var/home/adrifadilah - - - - /home/adrioui"
];
```

`sed -i` over the tree replaces every inode it touches: hardlinks break and
ACLs, xattrs and file capabilities are dropped. It also cannot reach SQLite or
other binary payloads, so the result is a mixed tree that no single rule
describes and that can no longer be verified against the backup.

Live configuration is repaired explicitly instead:

| Target | Action |
|---|---|
| `~/.bashrc`, `~/.profile`, `~/.config/fish/config.fish` | Home Manager owns them; the restored copies become `*.hm-backup` on first activation |
| `~/.config/herdr/session.json` (`identity_cwd`, `worktree_space.key`) | edit by hand |
| 53 linked worktrees under `.herdr/worktrees` | phase 2: `git worktree repair <path>` per worktree, then remove the link |
| transcripts, databases, archives | leave as history |

## 10. New secrets and keys

Before cutover, provision the new host:

1. New SSH key pair, mode 0600; public key installed on required servers.
2. New GPG key/passphrase if needed; old key revoked.
3. New age key for sops; old age key never used.
4. New proxy secrets in sops:
   - `amp-deepseek/upstream-key`
   - `amp-deepseek/inbound-key`
5. No old `.ssh`, `.gnupg`, `.config/sops`, `.aws`, `.kube`, `.docker`, or
   provider env files restored.

Verify file modes and that the proxy starts with the new secrets. Do not put a
secret on a command line.

## 11. Gate 3 VM proof (must precede cutover)

```bash
nix build --no-write-lock-file --no-update-lock-file \
  .#checks.x86_64-linux.t14-vm
```

The test (`modules/vm-test.nix`) automates boot, login, Home Manager
activation, ownership `1000:1000`, proxy health/auth/missing-secret, loopback
listener, old-unit absence, failed-unit absence, journal secret scan, and a
reboot. It passed on 2026-10-31. For manual inspection, build the VM image with
`nixos-rebuild build-vm --flake .#t14` and run the generated script; do not
switch the live host.

Rollback rehearsal is **NotRun** in the automated test because it requires a
second generation and boot-menu selection. Before cutover, perform it manually
in the VM and record the generation numbers, as described in `rollback.md`.

## 12. Cutover (Approval 4 and 5)

Cutover is performed from a root TTY or live USB, not from the desktop
session. The user must explicitly approve the window and the live switch.

### 12.1 Prepare

```bash
loginctl list-sessions
loginctl terminate-user adrioui
pkill -u adrioui || true
# verify no processes remain
pgrep -u adrioui -a
```

Stop OpenCode and any user service that writes to the home. Make a consistent
backup of the live OpenCode DB **outside** the home if needed:

```bash
install -d -m 0700 /var/backups/duniawi
sqlite3 /home/adrioui/.local/share/opencode/opencode.db \
  ".backup '/var/backups/duniawi/opencode-live.db'"
sqlite3 /var/backups/duniawi/opencode-live.db 'PRAGMA integrity_check;'
```

Do not copy the backup's old OpenCode DB over the live one.

### 12.2 Rename and activate

```bash
mv /home/adrioui /home/adrioui.pre-migration
mv /home/adrioui.restore /home/adrioui
```

Do **not** run a recursive `chown`. The stage already has `1000:1000` for the
restored user data, and the approved `.herdr`/`Works/Bangunindo/BLIV` root-owned files were
selectively mapped in section 8.2.1. Verify instead:

```bash
find /home/adrioui -xdev -uid 0 -print > "$EV/root-owned-cutover.txt"
find /home/adrioui -xdev \( -nouser -o -nogroup \) -print
stat -c '%U:%G %a %n' /home/adrioui
```

A non-empty root-owned list is a stop condition unless every entry is on the
approved mapping list and has been fixed before login. Do not guess.

Then activate the new generation:

```bash
nixos-rebuild switch --flake /path/to/duniawi#t14
```

If the switch fails, stop and roll back; do not patch the live system by hand.

### 12.3 Reboot and login proof

```bash
reboot
```

After reboot, log in as `adrioui` on the console/TTY. Verify:

| Check | Command | Pass |
|---|---|---|
| Login | TTY login | succeeds |
| Home ownership | `stat -c '%U:%G' ~` | `adrioui:adrioui` |
| Shell | `echo $SHELL`, `zsh -lic 'echo ok'` | zsh, `ok` |
| Git | `git config --get user.email` | expected identity |
| SSH | `ssh -T git@github.com` | authenticated with new key |
| GPG | `gpg --list-secret-keys` | new key only |
| Editor | `nvim --version`, `helix --version` | runs |
| Proxy | `curl -fsS http://127.0.0.1:4014/health` | 200 |
| No old units | `systemctl --user list-unit-files --state=enabled` | no archived unit |
| No failed units | `systemctl --failed` | empty |
| No secret leak | `journalctl -b -p err`; secret scan | clean |
| Data spot-check | open representative files from `Works/Bangunindo/BLIV` and Agent history | present and readable |

Any failure is a stop. Do not declare success from a partial check.

## 13. Rollback rehearsal

Before accepting the migration, rehearse rollback in the VM and, if possible,
on the live machine during the approved window. The full procedure is in
`docs/design/rollback.md`.

Minimum rehearsal:

1. Boot the previous NixOS generation.
2. Rename `/home/adrioui` back to `/home/adrioui.post-migration` and
   `/home/adrioui.pre-migration` back to `/home/adrioui`.
3. Log in as `adrioui`.
4. Verify shell, SSH, editor, and data.
5. Reboot and repeat.
6. Restore the new home and generation only after the rollback proof is
   recorded.

If rollback fails, stop at highest severity and preserve both homes and all
generations.

## 14. Acceptance and retention

Acceptance requires:

- Gate 3 VM proof and reboot proof.
- Gate 4 stage hash/metadata/DB/secret checks.
- Cutover login proof.
- Rollback rehearsal proof.
- No secret leak; old secrets revoked.
- No old proxy unit enabled.
- `amp-deepseek-proxy` health 200 on loopback.
- Darwin host still evaluates/builds unchanged.
- PR reviewed and merged on `feat/cross-platform-nixos` (never `main` directly).

Retain:

- `/home/adrioui.pre-migration` until the acceptance window ends.
- N-1 and N-2 NixOS generations.
- `/var/log/duniawi-migration/` evidence.
- The read-only backup, unchanged.

Do not delete the old home or GC generations until the user explicitly accepts
the migration.

## 15. Stop conditions

Stop immediately and preserve evidence on:

- any `sha256sum -c` failure;
- any manifest line count or digest mismatch;
- any missing file, metadata mismatch, ACL/xattr loss, or hardlink loss;
- any unmapped UID/GID;
- any SQLite integrity failure;
- any secret hit in the stage or logs;
- insufficient space or inodes;
- failed VM boot, login, HM activation, or proxy health;
- failed cutover or rollback;
- any unexplained build failure or Darwin regression.

Do not retry a destructive step blindly. Record the error, the command, and
the evidence path; ask for a decision.
