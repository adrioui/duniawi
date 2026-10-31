# Gate 3 VM proof summary

- Date: 2026-10-31
- Command: `nix build --no-link .#checks.x86_64-linux.t14-vm`
- Derivation: `/nix/store/z3v0xzvmypyzkcq97d0jr23y3ci0g4ir-vm-test-run-t14-vm.drv`
- Result: **Pass**, exit 0
- Runtime: ~305 seconds under QEMU TCG (no `/dev/kvm` in this session). This run includes root-owned migration fixtures, full-disk failure, SIGKILL restart, graceful reboot, and a power-loss crash/reboot.

Verified:

- boot to `multi-user.target`;
- `home-manager-adrioui.service` active;
- user manager `user@1000.service` active;
- `/home/adrioui` ownership `1000:1000`;
- `getent passwd adrioui` = uid/gid `1000:1000`;
- `getent group 1000` = `adrioui`;
- no `-nouser`/`-nogroup` entries in the test home;
- `amp-deepseek-proxy.service` active;
- `/health` HTTP 200 with test keys;
- wrong inbound key HTTP 401;
- missing credentials HTTP 503;
- listener only on `127.0.0.1:4014`, not `0.0.0.0`;
- no archived old proxy unit enabled;
- no failed system units;
- no test key in the journal;
- reboot and repeat: `/health` 200 again.
- SIGKILL of the proxy main process restarted the unit and returned to `/health` 200;
- immediate power-loss crash followed by boot of the same disk returned to `/health` 200;
- full 1 MiB destination failed the copy with ENOSPC; corrupted SQLite copy failed `PRAGMA integrity_check`;
- root-owned `.herdr` and `Works/Bangunindo/BLIV` fixtures mapped to `1000:1000`; root-owned `Personal` fixture excluded.

NotRun:

- rollback rehearsal to a previous generation. Three automated attempts were
  made and rejected:
  1. `nixos-rebuild switch --rollback` failed because the test VM has no
     `/etc/nixos` or `NIX_PATH` for the rebuild bootstrap.
  2. `nix-env --set` to the same closure did not create a second generation
     (`no profile version older than the current (1) exists`).
  3. A distinct second system closure was added via `system.extraDependencies`,
     but `nix-env --set` still left the profile at generation 1.
  The rollback code was removed from the automated test so the suite remains
  green. Manual rollback rehearsal in the VM and on the live machine is still
  required before A4/A5. This is a `NotRun`, not a pass.
- real sops decryption (test keys are injected; production sops file is not
  provisioned);
- hardware acceptance (Wi-Fi, Bluetooth, audio, GPU, touchpad, suspend);
- live migration/cutover.

The full transcript is `vm-test.log` in this directory.
