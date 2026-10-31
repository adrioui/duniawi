# Package portability table

Status: **Gate 2 — implemented; versions below are evaluated and the NixOS
toplevel builds**

Pinned sources used for this table:

| Input | Revision / hash |
|---|---|
| `nixpkgs` (Darwin root) | `8825bebf6324e0579d012936eff73379af284b6d` |
| `llm-agents` nixpkgs | `b6c98e9e6633ee64753b594ff4a5febf0367fc00` (`sha256-QpXotokGh5eeMG1Njiuh27oP0rK6t5+cMp7ymXSs7mc=`) |
| `nixpkgs-stable` (t14) | `6f06d204d8f2d8761d9da78778745974a3216381` |
| `home-manager` (Darwin) | current lock (`31729ca8…`) |
| `home-manager-stable` (t14) | `24f2190587513b9c2f73db112a17844ae912d965` |
| `nixos-hardware` | `04c6b94fa104bc23650983a4513aea196794d321` |
| `sops-nix` | `60182817ee048ac94b4c68ea76d5ef2e8aac730d` |
| `helium` | `cb5943d09f182b66493d1988ebefe3f504e4fe1d` |
| `llm-agents` | `06830d044f23ec9bc55cec62771122d2941c634d` |
| `den` | `ba9ee3a5e8ad1f77ba8e0341b224c4a1d5999787` |

All versions below were read with `nix eval` against the pinned inputs. No
`--impure`, channel, or unpinned lookup was used. A version being present is
not a build proof; the `t14` toplevel and the Linux static checks were built.

## 0. Actual NixOS 26.05 package versions on `t14`

| Package | Version | Source |
|---|---|---|
| kernel | 6.18.59 | `nixpkgs-stable` |
| Plasma Desktop | 6.6.6 | `nixpkgs-stable` |
| Node.js | 24.22.1 | `nixpkgs-stable` |
| qBittorrent | 5.2.2 | `nixpkgs-stable` |
| FFmpeg | 8.1.3 | `nixpkgs-stable` |
| Helix | 25.07.1 | `nixpkgs-stable` |
| Neovim | 0.12.4 | `nixpkgs-stable` |
| Go | 1.26.10 | `nixpkgs-stable` |
| Rustup | 1.29.2 | `nixpkgs-stable` |
| Podman | 5.8.9 | `nixpkgs-stable` |
| Tailscale | 1.98.10 | `nixpkgs-stable` |
| Bun | 1.3.13 | `nixpkgs-stable` |
| Helium | 0.17.2.1 | `helium` input |
| Amp CLI | 0.0.1793462430-g2650be | `pkgs/amp-cli.nix` |
| Claude Code | 2.1.280 | `llm-agents` |
| Cursor Agent | 2026.09.18-9a7762bc | `llm-agents` |
| OpenCode | 1.18.32 | `llm-agents` |
| Pi | 0.87.1 | `llm-agents` |
| Herdr | 0.9.1 | `llm-agents` |
| amp-deepseek-proxy | 1.0.0 | repository |

Darwin's Helium is `0.17.2.2`; Linux is `0.17.2.1` because both come from the
same pinned `helium` revision. This version skew is documented and is not a
fallback to Firefox.

Legend: `Reuse` = same attribute and behavior on both hosts; `NixOSVariant` =
different Linux attribute or lifecycle; `DarwinOnly` = not referenced on
NixOS; `New` = introduced by this change; `Retired` = removed from the active
set.

## 1. Shared CLI and desktop packages

This table was captured against the Darwin/unstable pin. The actual `t14`
26.05 versions are in section 0; where they differ, section 0 is authoritative.

These are referenced by `dev`, `editor`, `media`, `shell`, or `vpn` and are
available from the same pinned nixpkgs attribute on Linux.

| Package | Attr | Linux version | Used by | Disposition | Notes |
|---|---|---|---|---|---|
| fastfetch | `pkgs.fastfetch` | 2.68.1 | dev | Reuse | terminal info |
| btop | `pkgs.btop` | 1.4.7 | dev | Reuse | resource monitor |
| coreutils | `pkgs.coreutils` | 9.11 | dev | Reuse | GNU coreutils |
| direnv | `pkgs.direnv` | 2.37.1 | dev | Reuse | shell hook |
| gh | `pkgs.gh` | 2.101.0 | dev | Reuse | GitHub CLI; auth is a secret |
| go | `pkgs.go` | 1.26.7 | dev | Reuse | toolchain |
| nodejs | `pkgs.nodejs` | 24.20.0 | dev, amp-deepseek | Reuse | proxy runtime; Node 24 is required by the tests |
| podman | `pkgs.podman` | 5.8.7 | dev | NixOSVariant | enable `virtualisation.podman`; do not copy the old user unit |
| rclone | `pkgs.rclone` | 1.75.1 | dev | Reuse | remotes are secrets/config |
| rustup | `pkgs.rustup` | 1.29.1 | dev | Reuse | toolchain |
| ripgrep | `pkgs.ripgrep` | 15.2.0 | dev | Reuse | search |
| uv | `pkgs.uv` | 0.12.17 | dev | Reuse | Python tooling |
| mkdocs | `pkgs.mkdocs` | 1.6.1 | dev | Reuse | docs |
| pnpm | `pkgs.pnpm` | 12.3.4 | dev | Reuse | JS package manager |
| lazygit | `pkgs.lazygit` | 0.65.1 | dev | Reuse | git TUI |
| zellij | `pkgs.zellij` | 0.45.1 | dev | Reuse | terminal multiplexer |
| lazydocker | `pkgs.lazydocker` | 0.25.2 | dev | Reuse | container TUI |
| eslint | `pkgs.eslint` | 10.10.0 | dev | Reuse | JS lint |
| curl | `pkgs.curl` | 8.22.0 | dev | Reuse | HTTP client |
| nixfmt-tree | `pkgs.nixfmt-tree` | 2.6.0 | dev, formatter | Reuse | formatter |
| statix | `pkgs.statix` | 0.5.8-unstable-2026-07-17 | dev | Reuse | Nix lint |
| deadnix | `pkgs.deadnix` | 1.3.2 | dev | Reuse | dead-code lint |
| nix-tree | `pkgs.nix-tree` | 0.8.0 | dev | Reuse | store browser |
| vim | `pkgs.vim` | 9.2.1001 | editor | Reuse | editor |
| neovim | `pkgs.neovim` | 0.12.5 | editor | Reuse | editor |
| helix | `pkgs.helix` | 25.07.1 | editor | Reuse | editor |
| qbittorrent | `pkgs.qbittorrent` | 5.2.3 | media | Reuse | GUI torrent client |
| ffmpeg | `pkgs.ffmpeg` | 9.0.1 | media | Reuse | media tooling |
| yt-dlp | `pkgs.yt-dlp` | 2026.08.19 | media (HM) | Reuse | downloader |
| alacritty | `pkgs.alacritty` | 0.17.0 | shell | Reuse | terminal |
| kitty | `pkgs.kitty` | 0.48.2 | shell | Reuse | terminal |
| tailscale | `pkgs.tailscale` | 1.102.4 | vpn | NixOSVariant | enable `services.tailscale`; no launchd |
| netbird | `pkgs.netbird` | 0.79.0 | vpn | Deferred | not enabled by default; two VPN clients overlap. Enable `services.netbird` only after a routing decision |
| cloudflared | `pkgs.cloudflared` | 2026.9.1 | vpn (HM) | Reuse | package only; tunnel token is a secret |

## 2. AI tools

The Darwin host uses a custom `amp-cli` derivation and a custom Bun 1.3.14
derivation. `pkgs/amp-cli.nix` now supports both `aarch64-darwin` and
`x86_64-linux`; the custom Bun derivation remains Darwin-only.

| Tool | Darwin | Linux | Disposition | Notes |
|---|---|---|---|---|
| Amp CLI | `pkgs/amp-cli` 0.0.1793462430-g2650be (custom) | same derivation, x86_64-linux | Reuse | Linux binary is patched with `autoPatchelfHook`; both hosts pin the same upstream release |
| Pi | `pkgs.llm-agents.pi` | `llm-agents` 0.87.1 | Reuse | MIT |
| OpenCode | `pkgs.llm-agents.opencode` | `llm-agents` 1.18.32 | Reuse | MIT; nixpkgs has 1.18.31, use llm-agents for parity |
| Cursor Agent | `pkgs.llm-agents.cursor-agent` | `llm-agents` 2026.09.18-9a7762bc | Reuse | unfree; add to unfree predicate |
| Claude Code | `pkgs.llm-agents.claude-code` | `llm-agents` 2.1.280 | Reuse | unfree; add to unfree predicate; nixpkgs has 2.1.278 |
| Herdr | `pkgs.herdr` | `pkgs.herdr` 0.9.1 | Reuse | Apache-2.0; `llm-agents.herdr` also 0.9.1 |
| Bun | `pkgs/bun-1.3.14.nix` 1.3.14 (custom, arm64) | `pkgs.bun` 1.4.2 | NixOSVariant | Linux uses nixpkgs Bun; do not import the Darwin derivation |
| Amp DeepSeek proxy | `pkgs/amp-deepseek` 1.0.0 | same derivation, Node 24 | Reuse | MIT; repo-owned, tested; NixOS lifecycle is new (`ampDeepseekNixos`) |
| `pkgs.amp` | not used | 0.7.1 | Retired | this is a different package; do not substitute it for `llm-agents.amp` |

### Unfree predicate

`den.batteries.unfree` matches `lib.getName pkg`. The NixOS host needs at
least:

```nix
(den.batteries.unfree [
  "amp"
  "cursor-agent"
  "claude-code"
])
```

The Darwin list already contains `amp-cli` and the RAVE/VSChaos model
packages. Gate 2 must evaluate the predicate for each package actually
referenced and add any additional unfree names; do not set a global
`allowUnfree = true`.

## 3. Darwin-only packages and assets

These are intentionally not evaluated or built for `x86_64-linux`.

| Package / asset | Version | Reason | Disposition |
|---|---|---|---|
| `bun-1.3.14` custom derivation | 1.3.14 | downloads `bun-darwin-aarch64.zip` | DarwinOnly |
| `xcodebuildmcp` | 2.7.0 | Xcode/macOS tool | DarwinOnly |
| `helium` | `0.17.2.2` Darwin / `0.17.2.1` Linux | pinned `helium` input; default browser on both hosts | Reuse |
| `puredata` + externals | repo derivations | Darwin PD externals | DarwinOnly |
| `nn-tilde`, `nn-tilde-max` | 1.6.0 | Max/MSP package | DarwinOnly |
| `rave-isis-model` | 1.0 | RAVE model | DarwinOnly |
| `rave-percussion-model` | 1.0 | RAVE model | DarwinOnly |
| `rave-water-model` | 1.0 | RAVE model | DarwinOnly |
| `vschaos2-ordinario-1024-model` | 1.0 | RAVE model | DarwinOnly |
| `pd-else`, `pd-flucoma`, `pd-gem`, `pd-zexy`, `pdida` | repo derivations | PD externals | DarwinOnly |
| Homebrew casks/brews | n/a | macOS package manager | DarwinOnly |

Homebrew casks in the current configuration are not Nix packages:
`anydesk`, `dbeaver-community`, `discord`, `firefox`, `font-hack-nerd-font`,
`ghostty`, `obsidian`, `orbstack`, `steam`, `typora`, `warp`, `yoink`, `zen`,
`zed`, `raycast`, `codex`, `protonvpn`, `cloudflare-warp`, `obs`,
`touchdesigner`, `cycling74-max`, `plugdata`, and the `beads` brew. NixOS
replaces the desktop/browser roles with native NixOS options or the pinned
Helium package; it does not install Homebrew. Firefox is not installed on
`t14`.

## 4. New NixOS packages and inputs

| Item | Source | Version | Purpose | Disposition |
|---|---|---|---|---|
| `sops` | `pkgs.sops` | 3.13.3 | decrypt secrets at activation | New |
| `age` | `pkgs.age` | 1.3.2 | per-host key material | New |
| `sops-nix` | `60182817…` | pinned | NixOS/HM secret module | New |
| `nixos-hardware` | `04c6b94…` | pinned | T14/Intel hardware profile | New |
| `nixpkgs-stable` | `6f06d204…` | pinned | t14 OS release | New |
| `home-manager-stable` | `24f21905…` | pinned | t14 Home Manager | New |
| `helium` | `cb5943d0…` | 0.17.2.1 Linux | default browser | New on NixOS |
| `amp-deepseek-proxy` | `pkgs/amp-deepseek` | 1.0.0 | local Anthropic-compatible proxy on `127.0.0.1:4014` | New on NixOS |
| `nodejs` | `pkgs.nodejs` | 24.22.1 | proxy runtime and tests | Reuse |

The intentional `flake.lock` changes are the pinned inputs above:
`nixpkgs-stable`, `home-manager-stable`, `nixos-hardware`, `sops-nix`, and the
existing `helium` input's Linux support. No existing input was casually
updated, and no channel or `--impure` path is used.

## 5. Verification plan

| Check | Command | Expected |
|---|---|---|
| Linux attr exists | `nix eval --raw .#nixosConfigurations.t14.pkgs.<attr>.version` | version string, no eval error |
| Darwin attr unchanged | `nix eval --raw .#darwinConfigurations.adri.pkgs.<attr>.version` | baseline version |
| Platform metadata | `nix eval --json .#nixosConfigurations.t14.pkgs.<attr>.meta.platforms` | includes `x86_64-linux` |
| Unfree predicate | `nix eval .#nixosConfigurations.t14.config.nixpkgs.config.allowUnfreePredicate` on each package | `true` only for approved names |
| Proxy tests | `nix build .#checks.x86_64-linux.amp-deepseek` (and Darwin equivalent) | test suite passes |
| Proxy derivation | `nix build .#nixosConfigurations.t14.config.home-manager.users.adrioui.home.packages` or the HM activation package | builds |
| No Darwin-only import | `nix eval .#nixosConfigurations.t14.config.system.build.toplevel.drvPath` | evaluates without `bun-1.3.14`, Xcode, PD, Max |
| Lock delta | `sha256sum flake.lock`; `git diff -- flake.lock` | only the documented pinned inputs |

## 6. Known package risks

1. `llm-agents` overlay builds against the consumer's `final`; its binary cache
   only hits when the nixpkgs revision matches. Gate 2 must build, not just
   evaluate.
2. Custom Bun is Darwin-only by construction. `amp-cli` is cross-platform and
   uses `autoPatchelfHook` on Linux.
3. `cursor-agent` and `claude-code` are unfree; a global `allowUnfree = true`
   is forbidden.
4. `pkgs.amp` (0.7.1) is not the Amp Code CLI. Using it by mistake would
   silently change behavior.
5. The proxy is a network service; it must bind `127.0.0.1` only and must not
   be exposed by the firewall or a tunnel in the default NixOS profile.
6. `sops-nix` must not be added as an unpinned `builtins.fetchTarball` or
   channel import.
