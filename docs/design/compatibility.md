# Aspect and host compatibility matrix

Status: **Gate 2 implemented; Gate 3 VM proof passing**

Legend: `Reuse` = shared code unchanged; `NixOSVariant` = add a `.nixos`
class block or Linux package path; `DarwinOnly` = intentionally not included on
NixOS; `Retired` = not carried forward; `New` = new aspect.

## 1. Aspect matrix

| Aspect | Current Darwin behavior | Proposed NixOS behavior | Shared code | Disposition | Risk | Verification |
|---|---|---|---|---|---|---|
| `base` | nix settings, registry, GC, optimise, `system.primaryUser`, stateVersion 6, hostPlatform, overlays | nix settings, registry, GC, optimise, stateVersion 26.05, hostPlatform | Nix settings and assertions; class blocks remain separate | Reuse + NixOSVariant | medium: overlays are Darwin-only; do not import them on NixOS | `nix eval` both hosts; Darwin values compared |
| `adri` host aspect | includes base, homebrew, vpn, audio, max, ai, ampDeepseek, shell, shellDarwin, editor, dev, media, xcode, browser | not applicable | none | Reuse | low | Darwin eval/build |
| `t14` host aspect | not applicable | includes base, nixosHardware, nixosDesktop, vpn, browser, dev, shell, media | aspect pattern only | New | medium: first NixOS host | `nix eval .#nixosConfigurations.t14`; build |
| `adrifadilah` user aspect | includes base, vpn, ai, ampDeepseek, shell, shellDarwin, media, max | not applicable | none | Reuse | low | Darwin eval/build |
| `adrioui` user aspect | not applicable | includes base, ampDeepseekNixos, shell, media, nixosUser; `.nixos` sets uid/gid/group/shell | home settings | New | medium: HM conflicts, secrets | VM login, HM activation, ownership assertions |
| `adrioui@t14` host-qualified user | not applicable | not used; `adrioui` exists only on `t14`, so the numeric mapping lives in `adrioui.nixos` | none | Retired | none | `getent`, `stat` in VM |
| `nixosHardware` | not applicable | generated T14 hardware config + `nixos-hardware` T14/Intel modules | none | New | high: wrong UUID/boot loader bricks boot | VM boot; compare UUIDs |
| `nixosDesktop` | not applicable | Plasma 6, SDDM, PipeWire, Bluetooth, printing, TLP, zram, fwupd, fonts, firewall | none | New | medium: hardware/desktop regressions | build; hardware acceptance |
| `nixosUser` | not applicable | curated HM packages, Helium, XDG MIME default, shell/tooling | none | New | medium: package/build failures | HM activation; build |
| `flake-parts` | `systems = [ "aarch64-darwin" ]` | add `"x86_64-linux"` | module | Reuse + NixOSVariant | low | `nix flake show --all-systems` |
| `den` | one Darwin host/user | add `t14`/`adrioui`; schema metadata; batteries | module | Reuse + NixOSVariant | medium: Den API conformance | pinned Den source check; eval |
| `per-system` | Darwin packages/checks, formatter, lint, amp-deepseek tests | add Linux checks; guard Darwin-only outputs | checks | Reuse + NixOSVariant | medium: `perSystem` runs for both systems | `nix flake check` both systems |
| `homebrew` | casks/brews, assertions | not included | none | DarwinOnly | none | not evaluated on NixOS |
| `vpn` | tailscale + launchd netbird + casks; cloudflared home package | Tailscale native module only; NetBird deferred; no tunnel | none | Reuse + NixOSVariant | low: no tunnel/SSH exposure | VM boot, `systemctl is-enabled tailscaled` |
| `audio` | Pure Data + externals + plugdata cask | not included | none | DarwinOnly | none | not evaluated on NixOS |
| `max` | Cycling '74 Max cask + nn_tilde home file | not included | none | DarwinOnly | none | not evaluated on NixOS |
| `ai` | amp-cli, llm-agents, herdr | Linux subset supplied through `nixosUser.home.packages`; use the cross-platform `pkgs/amp-cli.nix` | none | Reuse + NixOSVariant | high: package availability | VM build; `command -v amp` |
| `ampDeepseek` | launchd agents + Keychain + logs in `~/Library/Logs` | not included; Darwin-only tunnel/proxy lifecycle | proxy derivation, official-modes activation | DarwinOnly | none on NixOS | Darwin eval/build |
| `ampDeepseekNixos` | not applicable | systemd user unit for `amp-deepseek-proxy` + sops secrets; no tunnel | proxy derivation, health endpoint, Node runtime | New | high: secret injection and service lifecycle | VM proxy health, 401/503 checks, no external listen |
| `shell` | zsh/starship + Keychain exports; alacritty/kitty | zsh/starship only; no Keychain calls | zsh/starship/sessionPath | Reuse + NixOSVariant | low | VM login; `zsh -lic true` |
| `shellDarwin` | Keychain exports + Magnitude endpoint | not included | none | DarwinOnly | none | Darwin eval/build |
| `editor` | vim/neovim/helix | vim/neovim/helix | package list | Reuse + NixOSVariant | low | `nix eval`/build |
| `dev` | full dev toolchain incl. custom bun | Podman module + nix-ld; packages in `nixosUser`, `pkgs.bun` | none | Reuse + NixOSVariant | medium: package availability | VM build; Podman enabled |
| `media` | qbittorrent, ffmpeg, casks; yt-dlp home | qbittorrent, ffmpeg, yt-dlp in HM; no casks | yt-dlp HM | Reuse + NixOSVariant | low | build; `yt-dlp --version` |
| `xcode` | xcodebuildmcp | not included | none | DarwinOnly | none | not evaluated on NixOS |
| `browser` | Helium | Helium from pinned input; XDG default; no Firefox | package concept | Reuse + NixOSVariant | medium: desktop integration/version skew | VM build; `helium --version` |
| `secrets` | not applicable | sops-nix + age; HM secret template; optional file | sops file | New | high: secret leak / activation failure | VM test env; mode/owner checks |
| `services` | not applicable | no copied proxy units; native modules for Tailscale/Podman; only amp-deepseek custom user unit | none | Retired | none | VM boot; `systemctl --failed`; `ss -ltnp` |

**Proxy policy:** the old Fedora AI proxy stack is explicitly out of scope
for NixOS. No old proxy unit, script, tunnel token, or provider key is copied
from the external HDD into the repository or restored into the live home. The
one exception is the repo-owned `amp-deepseek` proxy: `ampDeepseekNixos`
reimplements its NixOS lifecycle as a systemd user unit with new sops-managed
credentials. It does not copy anything from the backup. The Darwin
`ampDeepseek` aspect stays exactly as it is on `adri`; the Cloudflare tunnel is
not ported by default. The old units and their data stay in the read-only
backup as archive evidence. See `docs/design/services.md`.

## 2. Host matrix

| Host | System | Class | User | Home manager | Output | Status |
|---|---|---|---|---|---|---|
| `adri` | `aarch64-darwin` | `darwin` | `adrifadilah` | yes | `darwinConfigurations.adri` | baseline evaluates; build pending macOS/remote builder |
| `t14` | `x86_64-linux` | `nixos` | `adrioui` | yes | `nixosConfigurations.t14` | evaluates and builds; VM test passes (boot/login/HM/proxy/reboot) |

## 3. Class routing

| Class | Darwin host | NixOS host | Notes |
|---|---|---|---|
| `darwin` | applied | not applied | `modules/base.nix`, `vpn.nix`, etc. |
| `nixos` | not applied | applied | new `base.nixos`, `nixosHardware.nixos`, NixOS modules |
| `homeManager` | `home-manager.users.adrifadilah` | `home-manager.users.adrioui` | routed by the Den home-manager battery |
| custom | none | none | no custom class is introduced |

## 4. Schema metadata

| Kind | Option | Type | Default | Set on |
|---|---|---|---|---|
| host | `timeZone` | `str` | `"Asia/Jakarta"` | `t14` (and default for `adri`) |
| host | `role` | `enum [ "laptop" "desktop" "server" ]` | `"laptop"` | `t14`, `adri` |
| user | `uid` | `nullOr int` | `null` | `adrioui = 1000` |
| user | `gid` | `nullOr int` | `null` | `adrioui = 1000` |
| user | `role` | `enum [ "primary" "secondary" ]` | `"secondary"` | `adrifadilah`, `adrioui` = `primary` |

These are metadata, not aspects. Aspects read them through the entity context
(`host.timeZone`, `user.uid`, `user.gid`, `user.role`). The types are enforced
at evaluation time; a missing `uid`/`gid` on the NixOS user must fail rather
than silently produce an unowned home.

## 5. Darwin non-regression gate

The Darwin baseline is:

- `darwinConfigurations.adri.config.system.build.toplevel.drvPath`
  ` /nix/store/0asmm5isa43s60wxxdmi0y03wmywap8h-darwin-system-26.11.4cff07d.drv`
- `system.primaryUser = "adrifadilah"`
- `nixpkgs.hostPlatform.system = "aarch64-darwin"`
- `system.stateVersion = 6`
- `flake.lock` SHA-256
  `441170412b5e5a05dde94f9c18c5351c85828e2f6753a6a9bd54615163ce45da`

At Gate 2, any change to the Darwin drv path must be explained by an
intentional shared-code refactor. An unexplained change is `DarwinRegression`
and the change is reverted. The NixOS work must not add Darwin-only packages,
overlays, or launchd units to the Linux host.
