# Gate 2 implementation checks

- Date: 2026-10-31
- Branch: `feat/cross-platform-nixos`
- Baseline HEAD: `030e37696587a7dc4bf73ae953225e4719c4d188`
- Implementation commit: `dd834984b1de93e20182b4bec489c408cd466ac2`
- Lock file: `5b495d350f985613c13b2b80b6fa4fe54b8c5db96d85145d39ad97d65346ee9f`
- Lock delta: only the pinned `nixpkgs-stable`, `home-manager-stable`,
  `nixos-hardware`, and `sops-nix` inputs were added; no existing node changed.
  See `flake-lock.diff`.

## Results

| Check | Result |
|---|---|
| `nix eval .#nixosConfigurations.t14.config.system.build.toplevel.drvPath` | Pass at clean commit: `/nix/store/6dam3fraw0s2979xyxrxkjx1hh9iv8ja-nixos-system-nixos-26.05.20261029.6f06d20.drv` |
| `nix build .#nixosConfigurations.t14.config.system.build.toplevel` | Pass: `/nix/store/xlkc7hb3ah7ab5gfqa7lzf1nq3lxkrnc-nixos-system-nixos-26.05.20261029.6f06d20` |
| `nix eval .#darwinConfigurations.adri.config.system.build.toplevel.drvPath` | Pass at clean commit: `/nix/store/05dmln046jcpwrdjw0ixgmghaq8gxn46-darwin-system-26.11.4cff07d.drv`; with `configurationRevision` forced to baseline rev, the drv path is exactly `/nix/store/0asmm5isa43s60wxxdmi0y03wmywap8h-darwin-system-26.11.4cff07d.drv` |
| `nix flake check --no-build --no-write-lock-file --no-update-lock-file --all-systems` | Pass |
| `nix build .#checks.x86_64-linux.nixfmt` | Pass |
| `nix build .#checks.x86_64-linux.deadnix` | Pass |
| `nix build .#checks.x86_64-linux.statix` | Pass |
| `nix build .#checks.x86_64-linux.amp-deepseek` | Pass |
| `shellcheck tests/migration-fixture.sh` | Pass |
| `actionlint .github/workflows/ci.yml` | Pass |
| `gitleaks detect --no-git` | Pass, no leaks |
| `nix build .#checks.x86_64-linux.migration-fixture` | Pass (ACL/xattr required in VM) |
| Darwin build on macOS | NotRun; requires macOS/CI runner |

## Evaluated values

- `nixosConfigurations.t14.config.users.users.adrioui.uid` = `1000`
- `...group` = `adrioui`
- `...users.groups.adrioui.gid` = `1000`
- `...system.stateVersion` = `"26.05"`
- `...nixpkgs.hostPlatform.system` = `x86_64-linux`
- `...home-manager.users.adrioui.home.stateVersion` = `"26.05"`
- `...ampDeepseekNixos.enable` = `true`
- `...amp-deepseek-proxy` environment includes `HOST=127.0.0.1`,
  `PORT=4014`
- `...services.tailscale.enable` = `true`
- `...boot.loader.systemd-boot.enable` = `true`
- `...virtualisation.podman.enable` = `true`
- Helium package name = `helium-0.17.2.1`
- `programs.firefox.enable` = `false`
