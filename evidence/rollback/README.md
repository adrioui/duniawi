# Rollback evidence

Status: **NotRun.** No previous-generation boot or old-home login has been
tested. The automated VM attempts below failed for test-harness reasons and
were removed from the green suite rather than being reported as a pass.

## Automated attempts

| Attempt | Command | Failure | Classification |
|---|---|---|---|
| 1 | `nixos-rebuild switch --rollback` in VM | no `/etc/nixos` or `NIX_PATH` for rebuild bootstrap | harness limitation |
| 2 | `nix-env -p /nix/var/nix/profiles/system --set $(readlink -f /run/current-system)` then `--rollback` | `--set` to the same closure did not create generation 2 | invalid rehearsal |
| 3 | distinct second system closure + `system.extraDependencies` | `nix-env --set` left the profile at generation 1; closure/DB visibility mismatch | harness/closure registration |

These are documented in `docs/design/evidence/gate3/summary.md` and
`docs/design/rollback.md`.

## Required manual rehearsal

Before A4/A5:

1. Record `nix-env -p /nix/var/nix/profiles/system --list-generations` and
   `bootctl list`.
2. Build a second NixOS generation with a harmless marker; switch to it.
3. Boot the **previous** generation from the systemd-boot menu.
4. Log in as `adrioui` and verify the old home is intact and the proxy state.
5. Return to the current generation and verify login again.
6. Record generation numbers, boot entries, login transcript, and any failed
   units.

The real cutover must retain `/home/adrioui.pre-migration` and N-1/N-2
generations until acceptance.
