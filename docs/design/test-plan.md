# Test plan and two-system CI matrix

Status: **Gate 1 draft — no implementation writes yet**

The test plan proves both hosts and the migration path. It is fail-closed: a
skipped required test is `NotRun`, not `Pass`.

## 1. Test environments

| Environment | System | Purpose | Secrets |
|---|---|---|---|
| CI Linux | `x86_64-linux` | static checks, NixOS eval/build, proxy tests, migration fixture | test-only |
| CI macOS | `aarch64-darwin` | static checks, Darwin eval/build, proxy tests | test-only |
| VM `t14` | `x86_64-linux` | boot, login, HM, proxy, services, reboot, rollback | test age key + test values |
| Live `t14` | `x86_64-linux` | `nixos-rebuild test`/`switch` only after approvals | production sops |
| Live `adri` | `aarch64-darwin` | Darwin non-regression build | production Keychain, not read by tests |
| Migration fixture | Linux | ACL/xattr/hardlink/symlink/timestamp/ownership | none |

## 2. CI matrix

Implemented in `.github/workflows/ci.yml`. Every action is pinned to a commit
SHA. Do not use floating tags. Do not pass `--impure`. Do not let CI write
`flake.lock`.

| Job | Runner | Checks |
|---|---|---|
| `linux` | `ubuntu-24.04` | flake eval, static, proxy tests, migration fixture, NixOS build, NixOS VM test, shellcheck/actionlint, gitleaks, lockfile |
| `darwin` | `macos-14` | flake eval, static, proxy tests, Darwin system build, Home Manager activation, non-regression values, lockfile |

| Job | Runner | Commands | Gate | Pass condition |
|---|---|---|---|---|
| `static-linux` | `ubuntu-24.04` | `nix build .#checks.x86_64-linux.nixfmt .#checks.x86_64-linux.deadnix .#checks.x86_64-linux.statix`; `shellcheck` on scripts; `bash -n`; `zsh -n` | 2 | all checks build |
| `static-darwin` | `macos-14` | same checks for `aarch64-darwin` | 2 | all checks build |
| `eval-linux` | `ubuntu-24.04` | `nix eval .#nixosConfigurations.t14.config.system.build.toplevel.drvPath`; `nix eval .#nixosConfigurations.t14.config.nixpkgs.hostPlatform.system` | 2 | drv path and `x86_64-linux` |
| `eval-darwin` | `macos-14` | `nix eval .#darwinConfigurations.adri.config.system.build.toplevel.drvPath`; `nix eval .#darwinConfigurations.adri.config.system.primaryUser` | 2 | drv path recorded; `adrifadilah` |
| `build-linux` | `ubuntu-24.04` | `nix build .#nixosConfigurations.t14.config.system.build.toplevel --no-link` | 2 | builds |
| `build-darwin` | `macos-14` | `nix build .#darwinConfigurations.adri.system --no-link` | 2 | builds |
| `proxy-linux` | `ubuntu-24.04` | `nix build .#checks.x86_64-linux.amp-deepseek --no-link` | 2 | Node test suite passes |
| `proxy-darwin` | `macos-14` | `nix build .#checks.aarch64-darwin.amp-deepseek --no-link` | 2 | Node test suite passes |
| `vm-linux` | `ubuntu-24.04` | `nix build .#checks.x86_64-linux.t14-vm --no-link` | 3 | VM test passes |
| `migration-fixture` | `ubuntu-24.04` | `nix build .#checks.x86_64-linux.migration-fixture --no-link` | 3 | metadata preserved |
| `lockfile` | `ubuntu-24.04` | `nix flake check --no-build --no-write-lock-file --no-update-lock-file --all-systems`; `git diff --exit-code -- flake.lock` | 2 | eval passes; no command mutates lock |
| `secret-scan` | `ubuntu-24.04` | `gitleaks detect --no-git --source .` | 2 | no findings |
| `docs` | `ubuntu-24.04` | markdown link check; `grep` for forbidden secret patterns | 1/6 | no broken links; no secrets |

Notes:

- `macos-14` is the arm64 GitHub runner used for `aarch64-darwin`. If the
  runner image changes, pin the image and record it in the workflow.
- A NixOS VM test runs under QEMU. If KVM is unavailable, use TCG; it is slower
  but deterministic. Do not skip the VM gate because CI is slow.
- `nix flake check --no-build --all-systems` evaluates both systems; it must
  not try to build Darwin-only packages on Linux. Guard Darwin-only
  `perSystem` outputs with `lib.meta.availableOn` or system checks.
- The lockfile job runs after all Nix commands so an accidental
  `nix build`/`nix eval` lock write is caught.
- The intentional lock delta is the pinned `nixpkgs-stable`,
  `home-manager-stable`, `nixos-hardware`, and `sops-nix` inputs. The PR records
  the old and new lock hashes and the reason. No existing input changed.

## 3. Static and evaluation tests

| Test | Command | Expected |
|---|---|---|
| Format | `nix build .#checks.<system>.nixfmt` | clean |
| Dead code | `nix build .#checks.<system>.deadnix` | clean |
| Nix lint | `nix build .#checks.<system>.statix` | clean |
| Shell syntax | `bash -n <script>`; `zsh -n <script>` | clean |
| Flake eval | `nix flake check --no-build --no-write-lock-file --no-update-lock-file --all-systems` | both systems evaluate |
| Darwin host | `nix eval .#darwinConfigurations.adri.config.system.build.toplevel.drvPath` | expected drv path or explained delta |
| Darwin primary user | `nix eval --raw .#darwinConfigurations.adri.config.system.primaryUser` | `adrifadilah` |
| Darwin platform | `nix eval --raw .#darwinConfigurations.adri.config.nixpkgs.hostPlatform.system` | `aarch64-darwin` |
| Darwin state version | `nix eval .#darwinConfigurations.adri.config.system.stateVersion` | `6` |
| NixOS host | `nix eval .#nixosConfigurations.t14.config.system.build.toplevel.drvPath` | drv path |
| NixOS platform | `nix eval --raw .#nixosConfigurations.t14.config.nixpkgs.hostPlatform.system` | `x86_64-linux` |
| NixOS state version | `nix eval .#nixosConfigurations.t14.config.system.stateVersion` | `26.05` |
| NixOS user | `nix eval --json .#nixosConfigurations.t14.config.users.users.adrioui` | uid/gid 1000, home `/home/adrioui` |
| NixOS group | `nix eval --json .#nixosConfigurations.t14.config.users.groups.adrioui` | gid 1000 |
| No Darwin-only import | `nix eval .#nixosConfigurations.t14.config.system.build.toplevel.drvPath` | no `bun-1.3.14`, Xcode, PD, Max |
| Helium present | inspect `home-manager.users.adrioui.home.packages` | `helium-0.17.2.1` |
| Firefox absent | `nix eval .#nixosConfigurations.t14.config.programs.firefox.enable` | `false` |
| No old proxy | `grep -R` in NixOS config for archived unit names | no matches |
| Proxy package | `nix build .#nixosConfigurations.t14.config.home-manager.users.adrioui.home.activationPackage --no-link` | builds; proxy derivation is in the HM closure |
| Proxy service | `nix eval .#nixosConfigurations.t14.config.home-manager.users.adrioui.systemd.user.services.amp-deepseek-proxy` | exists, `ExecStart` points to proxy |

## 4. Proxy tests

The repo already has Node tests under `pkgs/amp-deepseek/test/`. They must run
on both systems.

| Test | Input | Expected |
|---|---|---|
| Health with keys | `GET /health` | 200 `{ok:true}` |
| Missing upstream key | `GET /health` | 503 |
| Missing inbound key | `GET /health` | 503 |
| Wrong inbound key | `POST /v1/messages` | 401; upstream not called |
| Forward body | valid POST | body unchanged; upstream `x-api-key` injected; inbound auth/CF headers dropped |
| SSE passthrough | upstream `text/event-stream` | content-type and events preserved |
| Oversized body | body > `MAX_BODY_BYTES` | 413 |
| Non-JSON body | `text/plain` | passed through unchanged |
| Loopback only | start service | `ss -ltnp` shows `127.0.0.1:4014`, not `0.0.0.0` |
| No secret log | inspect journal | no authorization, key, body, or header values |

VM-only tests:

| Test | Command | Expected |
|---|---|---|
| Service active | `systemctl --user status amp-deepseek-proxy` | active |
| Health | `curl -fsS http://127.0.0.1:4014/health` | 200 |
| Missing sops secret | remove/stop secret | 503, no plaintext fallback |
| Reboot | reboot VM; repeat | still healthy |
| No old units | `systemctl --user list-unit-files --state=enabled` | no archived unit |
| No tunnel | `ss -ltnp`; `systemctl --user list-units` | no Cloudflare tunnel unit |

## 5. NixOS VM test

Implemented as `checks.x86_64-linux.t14-vm` in `modules/vm-test.nix`. The test
uses the resolved Den host module, `machine.start(allow_reboot=True)`, a
test-only password, and test proxy keys injected into the same systemd user
service. It does not decrypt production sops data.

Latest run (2026-10-31): **Pass**, exit 0. Verified: boot, login/user manager,
Home Manager activation, ownership `1000:1000`, no unmapped IDs in the test
home, migration fixture with ACL/xattr/full-disk/root-policy required, proxy
health 200, wrong key 401, missing secret 503, listener only on
`127.0.0.1:4014`, no old proxy units, no failed system or user units, no test
key in the journal, SIGKILL restart, graceful reboot, and immediate power-loss
crash/reboot. Rollback rehearsal remains `NotRun`.

The VM test should:

1. Boot the `t14` configuration.
2. Log in as `adrioui` (or autologin).
3. Verify `home-manager.users.adrioui.home.activationPackage` activated.
4. Verify `amp-deepseek-proxy` is active and `/health` returns 200.
5. Verify wrong inbound key returns 401.
6. Verify `ss -ltnp` has no `0.0.0.0` proxy listener.
7. Verify no archived unit is enabled.
8. Verify `systemctl --failed` is empty and `journalctl -b -p err` is clean.
9. Reboot and repeat steps 2–8.
10. Rehearse rollback: boot the previous generation, verify login, then return
    to the new generation. Record generation numbers.

A NixOS test can run these with `machine.succeed`, `machine.wait_for_unit`,
`machine.wait_for_open_port`, and `machine.reboot`. If a step cannot be
automated, mark it `NotRun` and perform it manually before Gate 4; do not mark
it `Pass`.

## 6. Migration fixture

Implemented in `tests/migration-fixture.sh` and exposed as
`checks.x86_64-linux.migration-fixture`. The Nix build sandbox may not support
ACLs/xattrs or root-owned files, so the check skips those there with a printed
result. The VM test runs the same script with `REQUIRE_ACL=1
REQUIRE_FULL_DISK=1 REQUIRE_ROOT=1` on the VM ext4 filesystem and fails if ACLs,
xattrs, root mapping, or the full-disk failure injection is unsupported.

Create a fixture tree with:

- regular files with known hashes;
- hardlinks (same inode, `nlink=2`);
- symlinks (relative and absolute, one dangling);
- ACLs (`setfacl -m u:nobody:r--`);
- xattrs (`setfattr -n user.test -v value`);
- timestamps (`touch -d '2020-01-02 03:04:05'`);
- ownership mapping (`1000:1000` → `adrioui:adrioui`);
- root-owned `.herdr`/`Works/Bangunindo/BLIV` fixtures (mapped) and a root-owned
  `Personal` fixture (excluded);
- `.clawdbot/` and `clickhouse-local/` fixtures (excluded);
- a SQLite database with `PRAGMA integrity_check` and a corrupted copy that
  must fail the check;
- a copy into a 1 MiB tmpfs that must fail with `ENOSPC`;
- a file that matches a secret pattern (must be excluded).

Run the approved `rsync -aHAX --numeric-ids` and verify:

| Property | Check | Expected |
|---|---|---|
| Content | `sha256sum` diff | identical |
| Hardlinks | `stat -c '%i %h'` | same inode/link count |
| Symlinks | `readlink` diff | identical |
| ACL | `getfacl` diff | identical |
| xattr | `getfattr` diff | identical |
| Timestamps | `stat -c '%y'` | identical |
| Ownership | `stat -c '%u:%g'` | `1000:1000` |
| Root-owned `.herdr` fixture | `stat -c '%u:%g'` after selective chown | `1000:1000` |
| Root-owned `Works` fixture | `stat -c '%u:%g'` after selective chown | `1000:1000` |
| Root-owned `Personal` fixture | absent from stage | excluded |
| Root-owned credential fixture | absent from stage | excluded |
| Secret exclusion | `find` | excluded file absent |
| Dangling symlink | `find -xtype l` | only the approved fixture link, or none |

The fixture does not replace the real backup verification. It proves the copy
flags and exclusion logic before the 282 GiB copy.

## 7. Live tests

Only after Gate 3 and Approvals 4–5:

| Step | Command | Expected |
|---|---|---|
| Pre-flight | `findmnt`, `df`, SMART, manifest hashes | pass |
| `nixos-rebuild test` | `nixos-rebuild test --flake .#t14` | activates without reboot; rollback ready |
| Login | TTY login as `adrioui` | succeeds |
| Proxy | `curl /health` | 200 |
| Services | `systemctl --failed` | empty |
| Data | spot-check representative files | present |
| Rollback | previous generation + old home | login succeeds |
| `nixos-rebuild switch` | approved window only | activates; reboot proof |

If `nixos-rebuild test` fails, roll back and stop. Do not proceed to `switch`.

## 8. Evidence

Every test writes:

- command line (without secrets);
- exit code;
- stdout/stderr;
- artifact path (log, drv path, store path, screenshot);
- timestamp and host/system;
- result `Pass`, `Fail`, or `NotRun`.

Store under `/var/log/duniawi-migration/<timestamp>/` on the target and attach
the relevant logs to the PR. Do not attach decrypted secrets or raw
environment files.

## 9. Acceptance criteria

- Both `aarch64-darwin` and `x86_64-linux` evaluate.
- Darwin toplevel drv path is unchanged or the delta is explained and
  approved.
- NixOS toplevel builds.
- VM boots, login works, HM activates, proxy health 200, no old units.
- VM reboot and rollback rehearsal pass.
- Migration fixture passes.
- Stage hash/metadata/DB/secret checks pass.
- Cutover login and data spot-checks pass.
- Rollback rehearsal passes.
- No secret leak; old secrets revoked.
- `flake.lock` delta is only the documented pinned inputs.
- PR is reviewed; no direct commit to `main`.

## 10. Test R substitutions

The graph is unchanged when substituting:

| Production | Test |
|---|---|
| host `t14` | VM host `t14-test` |
| user `adrioui` | test user `adrioui` with test password/autologin |
| production age key | test age key |
| production sops ciphertext | test sops ciphertext |
| backup HDD | fixture tree |
| DeepSeek upstream | local fake upstream |
| Cloudflare tunnel | none; tunnel not ported |
| live OpenCode DB | temporary SQLite fixture |

No test may read the production age key or the old backup secrets.
