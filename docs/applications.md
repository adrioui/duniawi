# Applications: Editors, Browser, Media, and Xcode

## Status

Desktop applications are declared either as Nix packages, Homebrew casks, or home-manager files. GUI apps are kept in Homebrew when they need vendor installers or auto-updates.

## Editors

`modules/editor.nix` installs:

| Editor | Package |
|---|---|
| Vim | `pkgs.vim` |
| Neovim | `pkgs.neovim` |
| Helix | `pkgs.helix` |

No editor configuration is managed here; the tools are available system-wide.

## Browser

`modules/browser.nix` installs `pkgs.helium`. The Helium overlay in `modules/base.nix` handles the nested DMG layout and disables component updates and background networking.

Other browsers are Homebrew casks: Firefox, Zen, and Raycast is a launcher.

## Media

`modules/media.nix`:

| Tool | Source |
|---|---|
| qBittorrent | Nix package |
| FFmpeg | Nix package |
| yt-dlp | home-manager package |
| OBS | Homebrew cask |
| TouchDesigner | Homebrew cask |

## Xcode

`modules/xcode.nix` installs XcodeBuildMCP:

```nix
(pkgs.callPackage ../pkgs/xcodebuildmcp.nix {
  src = inputs.xcodebuildmcp;
})
```

`pkgs/xcodebuildmcp.nix` builds from a pinned GitHub source with `buildNpmPackage`:

| Field | Value |
|---|---|
| Version | `2.7.0` |
| Source | `getsentry/XcodeBuildMCP` at `e6ef59b49b44012c824f0a0de261c96142e37390` |
| NPM deps hash | `sha256-PWvpblzfn0yM6hRmdJXzcqyegsytBRZGr0vJQYWdcuA=` |
| Build script | `build:tsup` |

The source pin and `npmDepsHash` must move together. Bumping one without the other breaks the build.

## Verification

```bash
vim --version | head -n 1
nvim --version | head -n 1
hx --version
helium --version
ffmpeg -version | head -n 1
yt-dlp --version
xcodebuildmcp --help
```

`xcodebuildmcp` is also exposed as the flake's default package and `packages.xcodebuildmcp`.

## Security

* Editors can execute project-local plugins; review workspaces before trusting them.
* Helium is wrapped to disable update checks and background networking.
* XcodeBuildMCP is a pinned upstream source with an npm dependency hash.
* Homebrew casks run vendor installers; review new casks before adding them.

## Troubleshooting

| Symptom | Check |
|---|---|
| Helium fails to build | inspect the `Helium.app` search in the overlay |
| Helium updates anyway | confirm the wrapper flags in `modules/base.nix` |
| XcodeBuildMCP build fails | bump source `rev` and `npmDepsHash` together |
| `xcodebuildmcp` not on PATH | rebuild; it is a system package |
| OBS/TouchDesigner missing | check the Homebrew cask is declared |
| `yt-dlp` outdated | update the flake input or use its own updater |
