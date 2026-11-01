# ADR-0003: UID/GID mapping 1000:1000

- Status: Proposed — requires Approval 2
- Date: 2026-10-31
- Deciders: repository owner
- Related: `docs/design/migration.md`, `docs/design/domain.md`

## Context

The old Fedora home is owned by `1000:1000` with user name `adrifadilah`. The
new NixOS account is `adrioui`. The current NixOS account uses uid 1000 and gid
100 (`users`); gid 1000 is unmapped (`UNKNOWN` in `stat`). A recursive `chown`
of 282 GiB is slow, risks metadata changes, and can hide ownership mistakes.

## Decision

Create a local group `adrioui` with gid 1000 and user `adrioui` with uid 1000,
primary group `adrioui`:

```nix
users.groups.adrioui.gid = 1000;
users.users.adrioui = {
  uid = 1000;
  group = "adrioui";
  home = "/home/adrioui";
  shell = pkgs.zsh;
  isNormalUser = true;
};
```

Restored files keep numeric ownership `1000:1000`; no recursive `chown` is
used. The existing system group with gid 100 is left alone.

## Consequences

- `find /home/adrioui -nouser -o -nogroup` must be empty after restore.
- `getent passwd adrioui` and `getent group adrioui` must show 1000.
- New files created by `adrioui` are `1000:1000`, matching the old home.
- Any old file with a gid other than 1000 is a mapping decision, not an
  automatic chown. Stop and ask.
- The old user name `adrifadilah` is not recreated; a compatibility link
  resolves `/var/home/adrifadilah` to `/home/adrioui` (ADR-0009).
- The NixOS user must not be a `systemd` `DynamicUser`; the home is persistent.

## Alternatives considered

| Alternative | Why rejected |
|---|---|
| `chown -R adrioui:users` | changes gid, loses old ownership semantics, slow |
| Keep gid 100 | old files become `adrioui:users`; inconsistent with backup |
| Recreate user `adrifadilah` | login identity changes; not the requested user |
| `systemd-homed` | not compatible with the existing ext4 home and Den setup |

## Verification

- `getent passwd adrioui` → `adrioui:x:1000:1000:...:/home/adrioui:...`
- `getent group adrioui` → `adrioui:x:1000:`
- `stat -c '%u:%g' /home/adrioui` → `1000:1000`
- `find /home/adrioui -xdev \( -nouser -o -nogroup \) -print` → empty
- VM login as `adrioui` succeeds; `id` shows `uid=1000(adrioui) gid=1000(adrioui)`.
