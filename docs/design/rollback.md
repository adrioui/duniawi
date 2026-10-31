# Rollback procedure

Status: **Rehearsal required before cutover — automated VM attempt NotRun**

The VM suite covers reboot but not a previous-generation rollback. Three
profile-level automation attempts failed for test-harness reasons (no
`/etc/nixos`/`NIX_PATH`, and `nix-env --set` did not create a second
generation). See `docs/design/evidence/gate3/summary.md`. A manual VM
rehearsal using the boot menu and a real previous generation remains required
before A4/A5; do not treat the automated reboot as a rollback proof.

Rollback is a first-class path, not an emergency afterthought. It must be
rehearsed in the VM and, where possible, on the live machine during the
approved window. A rollback that has not been rehearsed is not a rollback.

## 1. Triggers

Roll back immediately on:

- failed console/TTY login as `adrioui`;
- failed home-manager activation or missing shell/editor/git;
- failed `amp-deepseek-proxy` health check that cannot be fixed within the
  approved window;
- data missing, unreadable, or corrupted after cutover;
- unmapped ownership or permission regression;
- secret leak in the restored home or logs;
- failed NixOS boot or failed service set;
- any unexplained Darwin regression caused by shared code.

Do not "fix forward" with manual edits to the live home or system. Roll back
first, then diagnose from evidence.

## 2. Preconditions

| Requirement | Check |
|---|---|
| Root TTY or live USB | `id -u` = 0; console access |
| Old home retained | `/home/adrioui.pre-migration` exists and is intact |
| Previous generation retained | `nix-env --list-generations --profile /nix/var/nix/profiles/system` shows N-1 and N-2 |
| Boot menu accessible | systemd-boot entries visible; `boot.loader.systemd-boot.configurationLimit` ≥ 3 |
| Evidence directory | `/var/log/duniawi-migration/` writable |
| No GC during window | `nix.gc.automatic` paused or not triggered |
| Approvals | Approval 4 (window) and Approval 5 (live switch) recorded |

If the old home or previous generation is missing, **do not start cutover**.
That is a `RollbackFailure` risk and a stop condition.

## 3. Scenario A — cutover renamed homes, switch not yet run

This is the cheapest rollback. No reboot is required.

```bash
# Stop user processes first.
loginctl terminate-user adrioui || true
pkill -u adrioui || true
pgrep -u adrioui -a

# If the new home is at /home/adrioui and the old home is at
# /home/adrioui.pre-migration:
mv /home/adrioui /home/adrioui.post-migration
mv /home/adrioui.pre-migration /home/adrioui

# Verify ownership and that no unmapped IDs exist.
stat -c '%U:%G %a %n' /home/adrioui
find /home/adrioui -xdev \( -nouser -o -nogroup \) -print
```

Log in as `adrioui` and verify shell, data, SSH, editor, and services. Keep
`/home/adrioui.post-migration` for diagnosis; do not delete it.

## 4. Scenario B — switch succeeded, system or login is broken

### 4.1 Boot the previous generation from the boot menu

1. Reboot.
2. At the systemd-boot menu, select the previous NixOS generation.
3. Boot and log in as `adrioui`.
4. Verify the old home is mounted/visible.

### 4.2 Or switch back from a working root TTY

```bash
nix-env --list-generations --profile /nix/var/nix/profiles/system
nixos-rebuild switch --rollback
```

`nixos-rebuild switch --rollback` activates the previous system generation,
including the home-manager generation that is embedded in it. If the command
fails, use the boot menu instead; do not hand-edit `/nix/var/nix/profiles`.

### 4.3 Restore the old home if it was renamed

```bash
# Only if /home/adrioui is the new home and /home/adrioui.pre-migration is
# the old home.
mv /home/adrioui /home/adrioui.post-migration
mv /home/adrioui.pre-migration /home/adrioui
chown -R adrioui:adrioui /home/adrioui
```

If the old home was not renamed, do not move anything; just boot the previous
generation.

## 5. Scenario C — home-manager activation failed

If the NixOS generation booted but the home-manager activation failed:

1. Do not disable home-manager.
2. Capture `home-manager`/activation logs and the conflict list.
3. Boot the previous NixOS generation (which contains the previous HM
   generation).
4. If the old home was renamed, restore it with Scenario A/4.3.
5. Re-run the VM test that should have caught the conflict; fix the aspect;
   do not bypass with `force`.

## 6. Scenario D — data corruption or missing files

1. Stop all writes to the affected home.
2. Preserve the new home as `/home/adrioui.corrupt-<timestamp>`; do not delete.
3. Restore the old home from `/home/adrioui.pre-migration` if it is intact.
4. If the old home is also affected, restore from the read-only backup into a
   **new** stage; never write to the backup.
5. Verify hashes, metadata, ownership, and SQLite integrity before login.
6. Record the corrupted paths and the evidence; do not silently re-copy.

## 7. Scenario E — secret leak after cutover

1. Revoke the affected credential at the provider first.
2. Rotate it and update sops ciphertext.
3. Roll back if the service or home is unsafe.
4. Purge the leaked file from the new home and logs; preserve evidence without
   copying the secret value.
5. Audit for use of the old credential.
6. Re-run the secret scan and proxy health check.

## 8. Verification after rollback

| Check | Command | Pass |
|---|---|---|
| Login | TTY login as `adrioui` | succeeds |
| Home | `stat -c '%U:%G' ~` | `adrioui:adrioui` |
| Shell | `zsh -lic 'echo ok'` | `ok` |
| Data | open representative files | present/readable |
| Git/SSH | `git config --get user.email`; `ssh -T git@github.com` | expected |
| Editor | `nvim --version`; `helix --version` | runs |
| System | `systemctl --failed` | empty |
| Generation | `readlink /run/current-system` | previous generation path |
| Old home | `test -d /home/adrioui.pre-migration` | retained if not renamed back |
| Backup | `findmnt -no OPTIONS /run/media/adrioui/backup` | still read-only |

If any check fails, stop. Do not attempt a second destructive rollback without
a new decision.

## 9. Rollback failure

A failed rollback is the highest-severity outcome.

1. Stop all writes.
2. Preserve both homes and all generations.
3. Boot from a live USB if the system cannot boot.
4. Capture `journalctl -b -1`, boot logs, generation list, and filesystem
   state.
5. Do not delete, reformat, or reinstall.
6. Ask the user for a recovery decision.

## 10. Rehearsal

Before cutover, rehearse in the VM:

1. Build and boot the new VM generation.
2. Create a marker file in the new home.
3. Boot the previous generation.
4. Rename homes as in Scenario A.
5. Verify login and marker absence/presence as expected.
6. Reboot and repeat.
7. Record the generation numbers, commands, and results in the Gate 3/4
   evidence.

On the live machine, rehearse only within the approved window and only after
the old home and N-1/N-2 generations are confirmed. A rehearsal that risks the
only copy is not allowed.

## 11. Retention

- Keep `/home/adrioui.pre-migration` until the user accepts the migration.
- Keep `/home/adrioui.post-migration` after a rollback until the incident is
  closed.
- Keep N-1 and N-2 generations until acceptance.
- Keep `/var/log/duniawi-migration/` evidence.
- Do not GC during the cutover/rollback window.
- Delete nothing without explicit approval.
