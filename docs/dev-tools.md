# Development Toolchain

## Status

The development toolchain is system-wide. It covers language runtimes, containers, Git tooling, terminal utilities, and the Nix lint/format stack.

## Packages

`modules/dev.nix` installs:

| Category | Packages |
|---|---|
| utilities | `fastfetch`, `btop`, `coreutils`, `curl`, `ripgrep` |
| Git and GitHub | `gh`, `lazygit` |
| environment | `direnv`, `zellij` |
| containers | `podman`, `lazydocker` |
| languages | `go`, `rustup`, `nodejs`, `pnpm`, `uv` |
| JavaScript | `bun` from `pkgs/bun-1.3.14.nix`, `eslint` |
| sync | `rclone` |
| docs | `mkdocs` |
| Nix | `nixfmt-tree`, `statix`, `deadnix`, `nix-tree` |

## Bun pin

`pkgs/bun-1.3.14.nix` pins Bun to a specific release. This is intentional: a newer Bun can change lockfile and runtime behavior. Remove the pin only after testing the affected projects.

## Nix tooling

| Tool | Use |
|---|---|
| `nixfmt-tree` | `nix fmt` |
| `statix` | Nix lint |
| `deadnix` | unused Nix code |
| `nix-tree` | closure inspection |

The per-system dev shell also includes `deadnix`, `flake-checker`, `nixfmt-tree`, and `statix`.

## Verification

```bash
nix develop
go version
rustc --version
node --version
pnpm --version
bun --version
podman --version
direnv --version
nix fmt --check
deadnix --fail
statix check .
```

## Security

* No language runtime credentials are stored in the repository.
* `direnv` can load project-local `.envrc`; review a repository before allowing it.
* `podman` runs containers; do not mount the Nix store or home directory into untrusted images.
* Bun and language toolchains are fetched from nixpkgs or pinned upstream releases with hashes.

## Troubleshooting

| Symptom | Check |
|---|---|
| `bun` version differs from projects | inspect `pkgs/bun-1.3.14.nix` |
| `nix fmt` missing | `nixfmt-tree` is in the dev shell or system packages |
| `direnv` does not load | shell hook and `direnv allow` |
| `podman` cannot start | check the Podman machine and virtualization settings |
| `go`/`rust` toolchain mismatch | use the project's own toolchain file before changing the system package |
| `nix-tree` missing | it is in `modules/dev.nix` only |
