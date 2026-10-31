# Gate 0 baseline

Status: **Captured and refreshed 2026-10-31 — root-owned verification remains
blocked; counts corrected from the earlier 9,224 figure**

This is the frozen baseline for the cross-platform change and the paused home
migration. It records facts, not approvals. Commands were run without
`--impure`, channels, or unpinned inputs.

## 1. Repository baseline

| Item | Value |
|---|---|
| Repository | `https://github.com/adrioui/duniawi` |
| Working clone | `/tmp/nix-shell-4085-2004343516/opencode/duniawi` |
| Branch | `feat/cross-platform-nixos` |
| Baseline HEAD | `030e37696587a7dc4bf73ae953225e4719c4d188` |
| Implementation commit | `dd834984b1de93e20182b4bec489c408cd466ac2` |
| Baseline status | clean before design docs; implementation branch is dirty but never on `main` |
| Baseline `flake.lock` SHA-256 | `441170412b5e5a05dde94f9c18c5351c85828e2f6753a6a9bd54615163ce45da` |
| Implementation `flake.lock` SHA-256 | `5b495d350f985613c13b2b80b6fa4fe54b8c5db96d85145d39ad97d65346ee9f` (pinned inputs added) |
| Den revision | `ba9ee3a5e8ad1f77ba8e0341b224c4a1d5999787` |
| Nixpkgs revision (Darwin root) | `8825bebf6324e0579d012936eff73379af284b6d` |
| `llm-agents` revision | `06830d044f23ec9bc55cec62771122d2941c634d` |
| `llm-agents` nixpkgs | `b6c98e9e6633ee64753b594ff4a5febf0367fc00` |
| NixOS `nixpkgs-stable` | `6f06d204d8f2d8761d9da78778745974a3216381` |

No commit, push, or PR was made before this baseline. `main` was not modified.

## 2. Darwin host baseline (`adri`)

| Item | Value | Command |
|---|---|---|
| Output | `darwinConfigurations.adri` | `nix eval` |
| Toplevel drv | `/nix/store/0asmm5isa43s60wxxdmi0y03wmywap8h-darwin-system-26.11.4cff07d.drv` | `nix eval .#darwinConfigurations.adri.config.system.build.toplevel.drvPath` |
| Primary user | `adrifadilah` | `nix eval .#darwinConfigurations.adri.config.system.primaryUser` |
| Platform | `aarch64-darwin` | `nix eval .#darwinConfigurations.adri.config.nixpkgs.hostPlatform.system` |
| State version | `6` | `nix eval .#darwinConfigurations.adri.config.system.stateVersion` |
| Systems list | `[ "aarch64-darwin" ]` | `modules/flake-parts.nix` |

The Darwin build was **not** run on macOS in this session. Evaluation was
proven on Linux; Gate 2/CI must build it on an `aarch64-darwin` runner.

## 3. NixOS baseline (`t14` / network host `nixos`)

| Item | Value |
|---|---|
| NixOS version | `26.05.13164.6f06d204d8f2` (Yarara) |
| Current system | `/nix/store/04q282abf92ypcwxqarbwzvrym4fvbcv-nixos-system-nixos-26.05.13164.6f06d204d8f2` |
| `/etc/nixos/configuration.nix` SHA-256 | `61f57fc8e288101578b0677f47f0065a56db69cfa581bd8d2084bf1fa7bd2732` |
| `/etc/nixos/hardware-configuration.nix` SHA-256 | `714d9c114f718a978931fe3cb5da3f15563274cd6f0b697deaa44f5810140251` |
| Current user | `adrioui`, uid 1000, gid 100 (`users`), home `/home/adrioui`, shell `bash` |
| Home mode | `0700 adrioui:users` |
| Hardware | Lenovo ThinkPad T14 Gen 2i, `20W1S0F500` |
| Firmware | `N34ET41W (1.41)`, 2021-07-08 |
| CPU | 11th Gen Intel Core i7-1185G7, 4C/8T, Tiger Lake |
| GPU | Intel TigerLake-LP GT2 Iris Xe (`8086:9a49`) |
| Wi-Fi | Intel AX210 (`8086:2725`) |
| Bluetooth | Intel AX210 (`8087:0032`) |
| Audio | Intel Tiger Lake HD Audio (`8086:a0c8`) |
| Fingerprint | Synaptics Prometheus MIS (`06cb:00bd`) |
| Battery | Celxpert 5B10W51830, 41.34 Wh full, 81% capacity, 811 cycles |
| Power management (live) | TLP disabled; power-profiles-daemon active; new config reverses this |
| Root filesystem | `/dev/nvme0n1p2` ext4, UUID `768a42bb-a1ff-4fae-8020-8e6bffd89a4e`, 475.9G |
| `/boot` | `/dev/nvme0n1p1` vfat, UUID `44D0-3F20`, 1G |
| Boot loader | systemd-boot, `canTouchEfiVariables = true` |
| Network | NetworkManager, hostName `nixos` |
| Desktop | Plasma 6 / SDDM, X11 enabled |
| Time zone | `Asia/Jakarta` |
| Locale | `en_US.UTF-8` |
| State version | `26.05` |
| Free space | 417 GiB; 29,752,580 free inodes; `/boot` 968 MiB free |
| Secure Boot | disabled (setup) |
| Current failed user unit | `drkonqi-coredump-pickup.service` (baseline; not caused by this change) |

Current `/etc/nixos` is a minimal hand-written configuration. It is the source
for hardware UUIDs, boot loader, filesystems, swap, microcode, and desktop
settings; it is not the final repository config.

## 4. Backup baseline

| Item | Value |
|---|---|
| Mount | `/run/media/adrioui/backup` |
| Device | `/dev/sda1` |
| Filesystem | ext4, label `backup` |
| UUID | `cdb0183d-7f36-4415-802c-0a36e8f7df10` |
| Mount options | `ro,nosuid,nodev,relatime,errors=remount-ro` |
| Capacity | 916G total, 355G used, 552G free |
| Inodes | 61,054,976 total, 5,740,728 used, 55,314,248 free |
| SMART health | PASSED (prior evidence); `smartctl` now blocked by permissions |
| Reallocated sectors | 0 |
| Current pending sectors | 0 |
| Offline uncorrectable | 0 |
| UDMA CRC errors | 0 |
| Error log | empty |

The backup is never written to. Any remount that loses `ro` is a stop
condition.

## 5. Manifest and bundle baseline

| Item | Value |
|---|---|
| Source manifest | `/run/media/adrioui/backup/evidence-20261030/gate3/source.sha256` |
| Destination manifest | `/run/media/adrioui/backup/evidence-20261030/gate3/destination.sha256` |
| Source lines | 5,082,466 |
| Destination lines | 5,082,466 |
| Source SHA-256 | `7bdf05b3ae049c8b1dd7a5e4e5f3052ffca7004fb3caccb1f28b0e89a222c06d` |
| Destination SHA-256 | same as source |
| `BUNDLE.sha256` path | `/run/media/adrioui/backup/evidence-20261030/BUNDLE.sha256` |
| `BUNDLE.sha256` actual hash | `b2821778253ba1bf256a5addeb320aff1595584027bce30c220794509bf5ef76` |
| Wrapper file | `/run/media/adrioui/backup/evidence-20261030/BUNDLE.sha256.sha256` |
| Wrapper recorded hash in `BUNDLE.sha256` | `654c567d6dcd8ac6a9a982933661a4c3d0744fb1f4ffe2c6989606f8f4129b9b` |
| Wrapper actual hash | `8bafbeb0d1ae3413afaf92d36ee2a4895f86c7c12307b408d2fb027b9b54bbb4` |
| Wrapper file content | `b2821778…  /var/mnt/backup/evidence-20261030/BUNDLE.sha256` (matches actual `BUNDLE.sha256`) |
| Filtered bundle check | 40 entries `OK`; self-referential empty-file line and wrapper line excluded |

The wrapper mismatch is isolated. A1 was **not waived**: the corrected
40-entry chain is in `docs/design/evidence/gate4/bundle-regenerated/`
(`BUNDLE.sha256` `bed412d8…`, wrapper `8e7646bf…`, 40/40 OK), and the user
accepted it. The full home manifest has not been verified as root. The earlier
9,224 figure was incomplete. Fresh unprivileged metadata found 192,782
root-owned entries (170,171 files, 22,413 directories); permission-denied
subtrees are still missing from the stream. Most of the root-owned files are
generated: 103,708 under `Personal/` (121,464 entries including directories,
mostly `Personal/financial/actual/node_modules`, Yarn cache, and build output)
and 32,908 under `.pi/`. The required `.herdr/` and `Works/Bangunindo/BLIV` root-owned files
are 32,326 files, 1.93 GiB. The user-approved policy maps only `.herdr` and `Works/Bangunindo/BLIV`
and excludes the rest.

## 6. Old home inventory

| Item | Value |
|---|---|
| Old host | Fedora Silverblue/Bluefin; no layered RPMs |
| Old user | `adrifadilah`, uid 1000, gid 1000 |
| Old home ownership | `1000:1000`; gid 1000 is unmapped on the new host |
| Top-level data | ~282.73 GiB by `home-top-level-sizes.txt` |
| Enabled user services | 27 `default.target.wants` symlinks (26 user-defined + `podman-restart` from `/usr/lib`) |
| Enabled timers | 5 |
| Unit files in manifest | 59 |
| RPM packages | 1,837 |
| Flatpak refs | 12 |
| Broken home-manager units | 5 logical units / 8 symlink paths: `bliv-secrets.service`, `nix-gc.service`, `nix-gc.timer`, `nix-managed-probe.service`, `tray.target` |
| Root-owned entries | 192,782 total: 170,171 files, 22,413 directories; permission-denied subtrees omitted |
| Root-owned by tree | `Personal` 103,708 files; `.pi` 32,908; `.herdr` 27,453; `Works` 4,875; `.clawdbot` 920; `.adalflow` 250; `clawd` 25; `Learns` 15; `.local` 9; `wt` 7; `.claude` 1 |
| Required root-owned files | `.herdr` + `Works/Bangunindo/BLIV`: 32,326 files, 1.93 GiB |
| Root-owned hash | NotRun; requires root TTY; permission-denied subtrees remain |
| `Personal/` | 2.3 GiB; financial data, resume PDFs, books; included by user decision |
| Non-1000 ownership | 93 valid `1000:0` in Learns; 16 runtime entries in `.dlt`/`surrealdb-data` excluded; 3 distrobox excluded |
| Root-owned policy | map `.herdr` and `Works/Bangunindo/BLIV`; exclude other root-owned files; selective chown only |
| Live OpenCode DB | `/home/adrioui/.local/share/opencode/opencode.db` plus WAL/SHM; must not be overwritten |

Largest top-level areas (from `home-top-level-sizes.txt`): `.local` 41G,
`.herdr` 33G, `Works` 32G, `Tooling` 27G, `.config` 21G, `.cache` 15G,
`.var` 14G, `.pi` 11G, `Learns` 11G, `Games` 7.4G, `.claude` 7G,
`.magnitude-sessions-old` 6.8G, `Downloads` 6.1G, `.bun` 5.4G,
`.rustup` 3.9G.

## 7. Secret findings at baseline

| Finding | Evidence | Status |
|---|---|---|
| Inline GPG passphrase | `gpg-preset-passphrase.service` | **SecretLeak**; rotate; never restore |
| Exposed SOPS age private key | `.config/sops/age/keys.txt`, mode 0600, 189 bytes | **SecretLeak**; do not reuse |
| SSH private key | `.ssh/id_ed25519`, mode 0600, 464 bytes | exposed; rotate |
| GPG private keys | `.gnupg/private-keys-v1.d/*.key` (two keys) | exposed; rotate |
| AWS credentials | `.aws/credentials` | exposed; revoke |
| GitHub token | `.config/gh/hosts.yml` | exposed; revoke |
| Docker auth | `.docker/config.json`, `.docker/.token_seed` | exposed; revoke |
| Kubernetes config | `.kube/config` | exposed; rotate |
| Desktop keyrings | `.local/share/keyrings/*` | exposed; recreate |
| Provider/proxy keys and logs | `.config/litellm`, `.config/cline-shim`, `.config/opencode/commandcode.key`, `.config/qodercli2api`, `.config/collie`, `.config/amp`, `commandcode-proxy.service`, `deepseek-direct-effort-proxy.service` | exposed; archive/rotate |

No secret value is recorded in this baseline.

## 8. Verification status

| Claim | Status | Evidence |
|---|---|---|
| Darwin evaluates on Linux | Verified | `nix eval` drv path above |
| Darwin builds on macOS | NotRun | needs macOS runner |
| NixOS current system captured | Verified | `/run/current-system`, `nixos-version` |
| Backup mount read-only | Verified | `findmnt` |
| SMART health | Verified | `gate5-smartctl-x.txt` |
| Manifest pair identical | Verified | line counts + SHA-256 |
| Bundle filtered check | Verified | 40 entries `OK` |
| Wrapper hash matches record | **Accepted via regenerated chain** | A1 |
| Full home hash as user | Partial pass | 4,826,215 files read, zero mismatches; 256,251 unreadable are all excluded (`source-hash-summary.md`) |
| Full home hash as root | NotRun | root TTY required |
| Metadata/ACL/xattr inventory | Partial | fresh unprivileged metadata; root verification pending |
| UID/GID mapping | Confirmed for 1000:1000 and `.herdr`/`Works/Bangunindo/BLIV`; A3b resolved by exclusion | 0 in revised scope |
| Exclusion policy | Confirmed 2026-10-31 | BLIV code/worktrees, Agent transcripts, Personal, Learns; everything else excluded |
| Secret rotation | NotRun | Phase 1 in `secrets.md` |
| NixOS toplevel build | Verified | `/nix/store/a4hdxq98rspl6csm9lrdsij28ra4xg07-nixos-system-nixos-26.05.20261029.6f06d20.drv` (clean HEAD 04d9c73; output /nix/store/5iyga6kmcf4jnlj4lw09gal9nlmhfay2-nixos-system-nixos-26.05.20261029.6f06d20) |
| NixOS VM proof | Pass (rollback NotRun) | `checks.x86_64-linux.t14-vm`; boot/login/HM/proxy/reboot, kill-restart, crash/reboot |
| Migration fixture | Pass | `checks.x86_64-linux.migration-fixture`; VM `REQUIRE_ACL=1 REQUIRE_FULL_DISK=1` |
| Static checks | Verified | `nixfmt`, `deadnix`, `statix`, `amp-deepseek` |
| Flake eval both systems | Verified | `nix flake check --no-build --all-systems` |
| Cutover | NotRun | Approvals 4–5 |

## 9. Gate 0 exit

Gate 0 is **captured** with these exceptions:

- root-owned hash verification of excluded state is NotRun; in-scope content
  hashed with zero mismatches;
- the wrapper mismatch is accepted via the regenerated chain;
- UID/GID mapping is confirmed; the exclusion policy is revised to BLIV
  code/worktrees + Agent transcripts + Personal + Learns;
- secrets are not rotated;
- Darwin build is not proven on macOS.

No implementation writes were made before this baseline. Design review and
Approvals 1–5 are the next gate.

## 10. Gate 2/3 refresh (2026-10-31)

| Check | Result | Evidence |
|---|---|---|
| NixOS host evaluates | Pass | `nixosConfigurations.t14.config.system.build.toplevel` |
| NixOS host builds | Pass | clean commit drv `/nix/store/6dam3fraw0s2979xyxrxkjx1hh9iv8ja-nixos-system-nixos-26.05.20261029.6f06d20.drv`; output `/nix/store/xlkc7hb3ah7ab5gfqa7lzf1nq3lxkrnc-nixos-system-nixos-26.05.20261029.6f06d20` |
| Darwin host evaluates | Pass | clean commit drv `/nix/store/05dmln046jcpwrdjw0ixgmghaq8gxn46-darwin-system-26.11.4cff07d.drv`; baseline-renormalized proof below |
| Darwin build on macOS | NotRun | requires macOS/CI |
| `nix flake check --no-build --all-systems` | Pass | both systems evaluate |
| `nixfmt`, `deadnix`, `statix` | Pass | `checks.x86_64-linux.*` built |
| Proxy Node tests | Pass | `checks.x86_64-linux.amp-deepseek` |
| VM boot/login/HM/proxy/reboot | Pass | `checks.x86_64-linux.t14-vm`, exit 0 |
| VM rollback rehearsal | NotRun | needs a second generation and boot-menu automation |
| Root-owned hash verification | Blocked | no root TTY |
| Secret rotation | NotRun | no credentials written or rotated |

The Darwin drv path differs from the frozen baseline only because
`system.configurationRevision` changes with the dirty worktree and the commit
revision. Proof: a clean worktree at baseline HEAD
`030e37696587a7dc4bf73ae953225e4719c4d188` evaluates to
`/nix/store/0asmm5isa43s60wxxdmi0y03wmywap8h-darwin-system-26.11.4cff07d.drv`.
The current tree, with `system.configurationRevision` temporarily forced to
that same baseline revision, evaluates to the **same** drv path. The evaluated
values are unchanged: `primaryUser = adrifadilah`, platform
`aarch64-darwin`, stateVersion `6`. A macOS build and CI comparison remain
required before release.
