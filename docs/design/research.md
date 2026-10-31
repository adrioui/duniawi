# NixOS practice research and decisions

Status: **Gate 1 research completed; Gate 2 implementation follows the
decisions below**

This note records what established NixOS projects do and why the `t14` host is
built the way it is. It is deliberately not a copy of the Darwin host and not a
copy of the old Fedora home.

## 1. Sources reviewed

| Source | What was taken from it |
|---|---|
| NixOS manual, stable 26.05 | `system.stateVersion` is fixed at install time; users, firewall, GC, and module options are declarative |
| `NixOS/nixos-hardware` README and `lenovo/thinkpad/t14` module | use a maintained hardware profile instead of local kernel-parameter guesses |
| `Mic92/sops-nix` README and Home Manager module | secrets decrypted at activation into `$XDG_RUNTIME_DIR/secrets.d`, not the Nix store |
| Home Manager manual / NixOS module docs | Home Manager as a NixOS module; `useGlobalPkgs`, `useUserPackages`, `backupFileExtension` |
| `Misterio77/nix-starter-configs` | keep host hardware config generated and separate; Home Manager is optional but normal on a desktop |
| systemd `systemd.exec` manual | `LoadCredential`/credential files are preferred over environment variables for secrets |
| Den pinned source `ba9ee3a5` | hosts, users, aspects, classes, batteries, host-qualified aspects |
| Current `/etc/nixos` | authoritative UUIDs, boot loader, filesystems, desktop and locale |
| Current NixOS system | running revision `6f06d204d8f2` = `nixos-26.05` |

## 2. What other NixOS users commonly do

### 2.1 Hardware

- Laptop users normally import a `nixos-hardware` profile rather than writing
  their own backlight, touchpad, SSD, or CPU workarounds.
- The generated `hardware-configuration.nix` remains the source of truth for
  filesystem UUIDs and initrd modules. It is not rewritten by hand.
- Laptops commonly enable TLP **or** power-profiles-daemon, not both. TLP is
  the conservative ThinkPad choice; Plasma still shows battery state.
- `zramSwap`, `fstrim`, `fwupd`, and `hardware.enableRedistributableFirmware`
  are common laptop quality-of-life settings. None of them changes the
  filesystem layout.

### 2.2 Secrets

- `sops-nix` is the most common age-based, flake-friendly secret module.
- The Home Manager module decrypts to `$XDG_RUNTIME_DIR/secrets.d` and exposes
  symlinks under `$XDG_CONFIG_HOME/sops-nix/secrets`.
- Secrets are never placed in the Nix store, unit files, or shell history.
- Home Manager services that need secrets order after `sops-nix.service`.
- A per-host age key is standard. Reusing a key found on an unencrypted backup
  is not.

### 2.3 Home Manager on NixOS

The common NixOS-module configuration is:

```nix
home-manager = {
  useGlobalPkgs = true;
  useUserPackages = true;
  backupFileExtension = "hm-backup";
  sharedModules = [ sops-nix.homeManagerModules.sops ];
};
```

- `useGlobalPkgs` avoids a second nixpkgs evaluation.
- `useUserPackages` lets `nixos-rebuild` manage the user profile.
- `backupFileExtension` is a migration aid, not a permanent dotfile policy.
- User CLI tools belong in Home Manager; system packages stay small and
  recovery-oriented.

### 2.4 Services

- Tailscale, Podman, Plasma, PipeWire, printing, Bluetooth, and firmware update
  all have first-class NixOS modules. Custom units are unnecessary.
- The old Fedora proxy stack is not a reason to copy custom units. The only
  service this change implements is the repository-owned `amp-deepseek` proxy.
- A user service is appropriate for a per-user loopback proxy. A system
  service would also work, but would add root-owned state for a tool that only
  the user consumes.
- systemd hardening is cheap and appropriate: `NoNewPrivileges`,
  `PrivateTmp`, `ProtectSystem=strict`, `ProtectHome=read-only`, and a
  restricted address-family list. Node/V8 rules out `MemoryDenyWriteExecute`.

### 2.5 Release pinning

- The running NixOS system is `26.05.13164.6f06d204d8f2`, and the
  `nixos-26.05` branch head is the same commit.
- Combining home migration with a jump to `26.11pre` would add an unrelated
  OS upgrade to an already risky window.
- Therefore `t14` uses a pinned `nixpkgs-stable` input at that exact commit,
  plus `home-manager-stable` from `release-26.05`.
- Darwin keeps its existing `nixpkgs-unstable` input. The two hosts share the
  repository, aspects, and policy, not one package set.
- This is a deliberate exception to "one nixpkgs for everything", documented
  in ADR-0008. It is the safer choice for this device.

## 3. What is deliberately not used

| Practice | Why not here |
|---|---|
| Impermanence / ephemeral root | the machine is already installed on ext4; converting it is a separate, destructive project |
| `disko` | no partitioning change is needed; the generated hardware config is authoritative |
| `nixos-unified` or another wrapper | the repo already uses `flake-parts` + `import-tree` + Den |
| Docker daemon | rootless Podman is enough; no need for a privileged daemon |
| Homebrew on Linux | not applicable; Nix packages and NixOS modules replace it |
| Global `allowUnfree = true` | Den's unfree battery keeps the exception list explicit |
| Cloudflare tunnel by default | unnecessary public exposure; the proxy is loopback-only |
| Copying old Fedora units | unreviewed code, inline secrets, and missing payloads |
| Copying the old age/SSH/GPG keys | exposed on an unencrypted backup |
| A second home-manager standalone setup | the NixOS module already manages the user environment |
| `--impure` or channels | reproducibility and the existing repo policy |

## 4. Consequence for the implementation

The NixOS host is composed of:

1. `nixosHardware` — generated hardware config plus `nixos-hardware` T14 and
   Intel modules.
2. `base.nixos` — flake-first Nix settings, stateVersion, GC, firewall,
   users, and recovery packages.
3. `nixosDesktop` — Plasma 6, SDDM, PipeWire, Bluetooth, printing, fonts,
   TLP, zram, fwupd, and the Intel graphics stack.
4. `vpn.nixos` — Tailscale system service only; NetBird remains an explicit
   opt-in because two overlapping VPN clients are not a safe default.
5. `dev.nixos` — rootless Podman; no old `podman-restart` unit.
6. `nixosUser` — curated Home Manager packages and shell integration.
7. `ampDeepseekNixos` — hardened user service for the repository-owned proxy,
   with optional sops secrets; it never copies the old proxy stack.

## 5. Device-care checklist

| Concern | Setting |
|---|---|
| Filesystem identity | keep UUIDs from `hardware-configuration.nix` |
| Rollback | `boot.loader.systemd-boot.configurationLimit = 10`; keep N-1/N-2 |
| SSD writes | `fstrim`, `noatime` only if already used, no aggressive tuning |
| Memory pressure | `zramSwap.enable = true` |
| Firmware | `hardware.enableRedistributableFirmware`, `services.fwupd` |
| Power | TLP; power-profiles-daemon disabled |
| Thermal | kernel/TLP defaults; no custom fan curves |
| Suspend | nixos-hardware T14 backlight/touchpad parameters; no unverified `mem_sleep` override |
| Network | NetworkManager, firewall on, no open ports, no SSH server by default |
| Logs | journald capped at 1 GiB |
| Updates | no auto-upgrade; flake revision is explicit |
| Secrets | sops-nix at runtime; no plaintext in repo or store |
| Migration | stage at `/home/adrioui.restore`; old home retained |

## 6. Open questions for the operator

These are not blockers for implementation but must be decided before cutover:

1. Tailscale only, or Tailscale plus NetBird? The default is Tailscale only.
2. Does the user want a fingerprint reader enabled? It needs firmware and PAM
   testing; default is off.
3. Which printer/scanner drivers are needed? Default drivers only for now.
4. Which desktop packages beyond the curated set are required on day one?
5. Is the 26.05 stable pin acceptable, or should `t14` follow the shared
   unstable pin after the migration window?

## 7. Candidate comparison matrix

Scores are suitability for this two-host repository, not popularity. `Adopt`
means it is part of the current implementation; `Defer` means it has a
reversible future path; `Reject` means it is wrong for this device or scope.

| Candidate | Version / revision | License | Maintenance | NixOS integration | Security model | Rollback | Cost | Status | Decision |
|---|---|---|---|---|---|---|---|---|---|
| `nixos-hardware` | `04c6b94fa104bc23650983a4513aea196794d321` | CC0-1.0 | active 2026-10-30 | native modules | declarative kernel/module settings | revert input | low | stable enough | **Adopt** T14 + Intel modules |
| `nixos-facter` | active 2026-10-30 | GPL-3.0 | active | generates hardware report | declarative hardware detection | regenerate | medium | young | **Defer**; current generated hardware file works |
| `sops-nix` | `60182817ee048ac94b4c68ea76d5ef2e8aac730d` | MIT | active 2026-10-26 | NixOS + HM modules | age encryption, runtime files | re-encrypt / rollback generation | low | stable | **Adopt** |
| `agenix` | active 2026-10-20 | CC0-1.0 | active | NixOS + HM modules | age/SSH recipients | rekey | low | stable | **Reject** for now; sops-nix already fits |
| `disko` | active 2026-10-29 | MIT | active | declarative partitioning | destructive if applied | reinstall | high | stable | **Defer**; existing ext4 install |
| `impermanence` | active 2026-10-23 | MIT | active | bind-mount persistence | destructive root conversion | reinstall | high | stable | **Defer**; not worth it during migration |
| `lanzaboote` | active 2026-10-26 | GPL-3.0 | active | Secure Boot/UKI | signing keys, boot chain | key rotation/boot menu | high | stable | **Defer**; Secure Boot currently disabled |
| `nixos-anywhere` | 1.13.0 | MIT | active 2026-10-28 | remote install | SSH + disk wipe | reinstall | medium | stable | **Defer**; useful for future reinstall/recovery |
| `colmena` | v0.5.0 | MIT | active 2026-09-22 | remote deploy | SSH/root | previous generation | medium | stable | **Reject** for two hosts; `nixos-rebuild` is enough |
| `deploy-rs` | v1.0.0 | MPL-2.0 | active 2026-10-19 | remote deploy | SSH/root | previous generation | medium | stable | **Reject** for two hosts |
| `nixos-generators` | archived 2026-01-30 | MIT | archived | image builders | n/a | n/a | low | archived | **Reject**; use build-vm/nixos-anywhere |
| `nix-topology` | active 2026-10-20 | MIT | active | diagram generation | read-only | n/a | low | stable | **Defer**; documentation aid, not boot path |
| `devenv` | active 2026-10-30 | Apache-2.0 | active | dev shells | per-project env | delete shell | low | stable | **Defer**; plain devShells are enough |
| `microsandbox` | v0.7.11 | Apache-2.0 | active 2026-10-31 | external runtime | KVM microVM, beta | snapshot/restore | high | **beta** | **Defer**; no boot/login/migration dependency |
| `vulnix` | 1.12.5 | BSD-3-Clause | active 2026-07-31 | CI scanner | CVE lookup | n/a | low | stable | **Defer** to CI follow-up |
| `sbomnix` | v1.9.0 | verify before use | active 2026-10-30 | SBOM generation | supply-chain visibility | n/a | low | stable | **Defer** to release gate |

### 7.1 Why `nixos-hardware` wins over `nixos-facter`

`nixos-hardware` is a reviewed set of quirks with a T14 profile and a generic
Intel CPU/GPU module. `nixos-facter` is promising but would add a generated
hardware report and a newer moving part. The existing
`nixos-generate-config` output already has the correct UUIDs and initrd
modules. Use the generated file plus the maintained T14 profile; revisit
`nixos-facter` only if hardware detection becomes a maintenance problem.

### 7.2 Why `sops-nix` wins over `agenix`

Both are credible. `sops-nix` already has a Home Manager module, supports age
and multiple backends, and the repository already documents the two-secret
proxy design around it. Switching to `agenix` would add work without a
security or operability win. The old age key is compromised and is not reused.

### 7.3 Secrets transport

| Option | Plaintext in store | Plaintext in unit | Plaintext in process env | Complexity | Decision |
|---|---|---|---|---|---|
| sops template + `EnvironmentFile` | no | no | yes, for the proxy process | low | **Adopt now** |
| sops secret + wrapper exports env | no | no | yes | low | acceptable fallback |
| systemd `LoadCredential` + file-reading proxy | no | no | no | medium; proxy change | **Defer** as hardening |
| plaintext `EnvironmentFile` in repo/home | yes | no | yes | lowest | **Reject** |

The current proxy reads environment variables. The sops template is mode
`0400` under the runtime secrets directory, and the unit uses `EnvironmentFile`
with an optional `-` prefix so a missing secret produces `/health` 503 rather
than a crash loop. A future proxy change can read `$CREDENTIALS_DIRECTORY`
directly; that needs its own tests.

## 8. Microsandbox, devenv, and the ghuntley demo

### 8.1 Microsandbox

Primary sources: `superradcompany/microsandbox` README at v0.7.11
(2026-10-24), Apache-2.0, and the repository metadata (active, 8.8k stars,
pushed 2026-10-31). The README states:

- Linux requires **KVM enabled**; macOS requires Apple Silicon; Windows
  requires WHP.
- It is **beta software** with expected breaking changes.
- It runs OCI images in microVMs, supports snapshots/forks, and advertises
  host-side secret substitution and network allowlists.

Decision: **Defer / reject as a dependency**. It is not installed on `t14`,
not in the boot/login path, and not used by the proxy or migration. The
current host has no `/dev/kvm` visible in this environment and KVM availability
must be verified on the real laptop. If adopted later, use a dedicated
unprivileged service, OCI images, an egress allowlist, and no host secrets;
package it declaratively and pin the release. It must never receive the sops
age key or the DeepSeek upstream key.

### 8.2 Devenv

Primary source: `cachix/devenv` (Apache-2.0, active). Devenv is a friendly
layer over Nix for per-project shells. This repository already has
`devShells.default` and Home Manager packages; adding Devenv would duplicate
that layer and add a second environment lifecycle. Decision: **Defer**. Use
plain `devShells`/`nix develop` for project environments. Revisit if project
count grows and per-project services/processes become necessary.

### 8.3 The ghuntley article and `nix-demo`

Primary sources: “a new model for open source: closed to pull requests, open to
remix” (2026-10-14, `https://ghuntley.com/remix`) and
`github.com/ghuntley/nix-demo`.

The useful idea is the **single overlay, many consumers** pattern: define a
patched package once and consume it from a dev shell, a NixOS VM test, and an
OCI image. `nix-demo` demonstrates this with a patched `git` that refuses force
pushes. The article's broader open-source governance argument is not a technical
dependency.

Decision: **Adopt the principle, reject the demo as scope**. This repository
already uses one flake, shared aspects, and one proxy derivation consumed by
tests and both hosts. Do not add a patched `git`, a Docker image, or Devenv
just to imitate the demo. If a package needs a patch, use a single overlay with
a test and an upstream-exit plan.

## 9. Deployment, CI, and supply chain

| Area | Choice | Why |
|---|---|---|
| Darwin deployment | `darwin-rebuild switch --flake .#adri` | existing, reviewed path |
| NixOS deployment | `nixos-rebuild test/switch --flake .#t14` | two hosts; no orchestration overhead |
| Remote install/recovery | `nixos-anywhere` | defer; useful for reinstall, not needed now |
| Multi-host orchestration | none | Colmena/deploy-rs are overkill for two machines |
| VM images | `nixos-rebuild build-vm` / NixOS test framework | `nixos-generators` is archived |
| CI Linux | `ubuntu-24.04` | native x86_64-linux |
| CI Darwin | `macos-14` arm64 | native aarch64-darwin |
| Actions | pinned commit SHAs | supply-chain reproducibility |
| Secret scan | `gitleaks` (or `trufflehog`) | fail closed on committed secrets |
| CVE scan | `vulnix` follow-up | useful, not yet wired |
| SBOM | `sbomnix` follow-up | release-gate evidence, not boot dependency |
| Lock review | `git diff --exit-code -- flake.lock` after Nix commands | catches accidental updates |
| Cache | `cache.numtide.com` for `llm-agents` | explicit trusted key in config; Helium is built/fetched from its pinned input |

The CI matrix is in `docs/design/test-plan.md`. A skipped job is `NotRun`, not
`Pass`.

## 10. Disk, rollback, and Secure Boot

| Decision | Choice | Reason |
|---|---|---|
| Filesystem | keep ext4 | no reinstall; migration risk dominates |
| Partitioning | keep existing layout | `disko` would be a destructive reinstall |
| Impermanence | defer | not worth converting a working ext4 home during migration |
| Boot loader | systemd-boot, `configurationLimit = 10` | keep N-1/N-2 for rollback |
| Secure Boot | defer | currently disabled; `lanzaboote` needs key enrollment and a boot test |
| Root encryption | residual risk | unencrypted root is unchanged; separate future project |
| Backups | read-only external HDD + staged restore | no in-place writes |
| GC during migration | disable/pause | preserve generations and old home |
| Rollback | prior generation + rename homes | rehearsed in VM; live rehearsal in A4 |

`lanzaboote` and `disko` are good projects, but adopting either during this
migration would add an irreversible boot/disk change. They belong in a
separate, explicitly approved project.

## 11. Source ledger

| Source | Revision / date | Used for |
|---|---|---|
| NixOS manual 26.05 | stable 26.05 | stateVersion, users, firewall, modules |
| nixpkgs | `6f06d204d8f2d8761d9da78778745974a3216381` | t14 package set and NixOS modules |
| nixpkgs unstable (root) | `8825bebf6324e0579d012936eff73379af284b6d` | Darwin package set |
| `llm-agents` nixpkgs | `b6c98e9e6633ee64753b594ff4a5febf0367fc00` | AI package input |
| Home Manager stable | `24f2190587513b9c2f73db112a17844ae912d965` | t14 Home Manager module |
| Den | `ba9ee3a5e8ad1f77ba8e0341b224c4a1d5999787` | aspects/classes/batteries |
| sops-nix | `60182817ee048ac94b4c68ea76d5ef2e8aac730d` | secret module and HM behavior |
| nixos-hardware | `04c6b94fa104bc23650983a4513aea196794d321` | T14 and Intel modules |
| Helium flake | `cb5943d09f182b66493d1988ebefe3f504e4fe1d` | Linux and Darwin browser package |
| llm-agents | `06830d044f23ec9bc55cec62771122d2941c634d` | AI CLI packages |
| systemd | 260.5 local man pages | `systemd.exec`, credentials, environment |
| Microsandbox | v0.7.11, `superradcompany/microsandbox` | beta/KVM comparison |
| Devenv | active `cachix/devenv` | dev-shell comparison |
| ghuntley | article 2026-10-14, `ghuntley/nix-demo` | single-overlay pattern |
| nixos-anywhere | 1.13.0 | deployment comparison |
| Colmena | v0.5.0 | deployment comparison |
| deploy-rs | v1.0.0 | deployment comparison |
| nixos-generators | archived 2026-01-30 | rejection evidence |
| nix-topology | active 2026-10-20 | documentation option |
| agenix | active 2026-10-20 | secret-backend comparison |
| nixos-facter | active 2026-10-30 | hardware comparison |
| impermanence | active 2026-10-23 | disk comparison |
| disko | active 2026-10-29 | disk comparison |
| lanzaboote | active 2026-10-26 | Secure Boot comparison |
| vulnix | 1.12.5 | CVE-scanner option |
| sbomnix | v1.9.0 | SBOM option |
