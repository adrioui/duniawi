# Nix Settings and Flake-First Policy

## Status

The system is flake-first. Legacy channels are disabled, the nixpkgs registry points at the flake input, and assertions fail the build if any of those invariants are broken.

## Core settings

`modules/base.nix` sets:

```nix
nix = {
  channel.enable = false;
  registry.nixpkgs.flake = inputs.nixpkgs;
  nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

  settings = {
    experimental-features = "nix-command flakes";
    show-trace = true;
    log-lines = 50;
    extra-substituters = [ "https://ibis.cachix.org" ];
    extra-trusted-public-keys = [
      "ibis.cachix.org-1:tKNWCdKmBXJFK1JE/SnA41z7U7XPFOnB7Nw0vLKXaLA="
    ];
    trusted-users = [ "root" "adrifadilah" ];
  };

  gc = {
    automatic = true;
    options = "--delete-older-than 14d";
  };

  optimise.automatic = true;
};
```

## Assertions

The build fails if:

* `nix.channel.enable` is not `false`.
* `nix.registry.nixpkgs` is missing.
* `nix.registry.nixpkgs` is not the exact `nixpkgs` flake entry.
* `nix.nixPath` does not contain `nixpkgs=${config.nix.registry.nixpkgs.flake}`.
* `experimental-features` does not include both `nix-command` and `flakes`.

These assertions are the contract for the flake-first workflow. Do not weaken them to make a command work; fix the command instead.

## Platform and identity

```nix
system = {
  primaryUser = "adrifadilah";
  configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
  stateVersion = 6;
};

nixpkgs.hostPlatform = "aarch64-darwin";
```

Home Manager uses its own `home.stateVersion = "23.11"` in the `base` aspect.

## Overlays

`nixpkgs.overlays` contains:

| Overlay | Purpose |
|---|---|
| `inputs.llm-agents.overlays.shared-nixpkgs` | AI CLI packages under `pkgs.llm-agents` |
| `inputs.helium.overlays.default` | Helium browser |
| local Helium override | finds `Helium.app` in the nested DMG layout and wraps it with update-disabling flags |

The Helium override exists because the upstream package install phase assumes a different archive layout. It is a workaround, not a preference. If upstream fixes the layout, remove the override.

## Unfree packages

Unfree packages are allowed narrowly through `den.batteries.unfree` in `modules/den.nix`:

```nix
(den.batteries.unfree [
  "amp-cli"
  "rave-isis-model"
  "rave-percussion-model"
  "rave-water-model"
  "vschaos2-ordinario-1024-model"
])
```

Add a package name only when the package is required. Do not enable global unfree packages.

## Validation

```bash
nix fmt --no-write-lock-file --no-update-lock-file
nix flake check --no-write-lock-file --no-update-lock-file
darwin-rebuild build --flake path:$PWD#adri
```

`nix flake check` covers:

* `nixfmt`
* `deadnix`
* `statix`
* `flake.lock` freshness
* the real darwin system derivation
* the home-manager activation derivation
* the Amp DeepSeek proxy tests

Treat `flake.lock` as read-only during validation. Use `nix flake update` only when intentionally updating inputs.

## Local rebuilds

Use `path:` references for local rebuilds so `sudo` does not fight Git ownership:

```bash
darwin-rebuild build --flake path:$PWD#adri
sudo darwin-rebuild switch --flake path:$PWD#adri
```

`path:` includes ignored and untracked files. Keep the working tree clean, or the system derivation will include a different `dirtyRev` and a different store path. The `result` symlink is ignored by `.gitignore` but still exists on disk; remove it before a reproducible switch if it is not needed.

## Garbage collection

```nix
nix.gc.automatic = true;
nix.gc.options = "--delete-older-than 14d";
nix.optimise.automatic = true;
```

Manual cleanup:

```bash
nix-collect-garbage --delete-older-than 14d
sudo nix-collect-garbage --delete-older-than 14d
```

## Troubleshooting

| Symptom | Check |
|---|---|
| `nix: command not found` | `nix.settings.experimental-features` must include `nix-command flakes` |
| `<nixpkgs>` resolves to an old channel | `nix.registry.nixpkgs` and `nix.nixPath` must match the flake input |
| `path:` rebuild differs from `nix build` | clean untracked files and remove `result` |
| unfree package rejected | add its name to the narrow unfree allowlist |
| Helium build fails | inspect the override's `find Helium.app` step and the upstream archive layout |
| lockfile check fails | run `nix flake update` intentionally, not during validation |
