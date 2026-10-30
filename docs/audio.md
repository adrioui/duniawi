# Audio: Pure Data, Max, and RAVE

## Status

Audio tooling is split by host:

* Pure Data and its externals are installed as Nix packages.
* Max/MSP is installed as a Homebrew cask.
* `nn_tilde` and the RAVE/vschaos2 models are linked into Max's package directory.

## Pure Data

`modules/audio.nix` builds `puredata-with-externals` from:

| Package | Purpose |
|---|---|
| `puredata` | base Pure Data, with `-Wno-error=unguarded-availability` |
| `pd-else` | EL Locus Solus externals |
| `pd-gem` | graphics environment for multimedia |
| `pd-zexy` | zexy externals, including `repeat` |
| `pd-flucoma` | FluCoMa machine-listening externals |
| `pdida` | `rr_*` algorithmic composition abstractions |
| `nn-tilde` | `nn~` external for TorchScript audio models |
| `rave-isis-model` | RAVE vocal model |
| `rave-percussion-model` | RAVE percussion model |
| `rave-water-model` | RAVE water model |
| `vschaos2-ordinario-1024-model` | vSchaos2 model |

`pkgs/puredata-with-externals.nix` uses `symlinkJoin` and wraps `pd` with a `-path` flag for every plugin:

```nix
wrapProgram $out/bin/pd \
  --add-flags "${toString (map (x: "-path ${x}/") plugins)}"
```

This keeps the externals discoverable without editing Pd's global preferences.

## Max/MSP

`modules/max.nix`:

* adds the `cycling74-max` Homebrew cask;
* links `nn_tilde` into `~/Documents/Max 9/Packages/nn_tilde`.

`pkgs/nn-tilde-max.nix` unpacks the Max external and copies three models into `models/`:

| File | Source |
|---|---|
| `isis.ts` | `rave-isis-model` |
| `percussion.ts` | `rave-percussion-model` |
| `ordinario_1024.ts` | `vschaos2-ordinario-1024-model` |

## Custom packages

The audio packages are prebuilt macOS binaries. They have no nixpkgs equivalents, so each is a fixed-output derivation with a pinned SRI hash.

FluCoMa is pinned to the stable `1.0.10` release. The previous nightly URL re-uploaded under the same path and broke builds with a hash mismatch. Do not move it back to the rolling `nightly` tag.

`pd-else`, `pd-gem`, and `pd-zexy` are Deken/upstream archives. `pdida` is pinned to a GitHub revision. The RAVE/vschaos2 models are downloaded from IRCAM or Hugging Face and are unfree.

## Verification

Build the system:

```bash
nix flake check --no-write-lock-file --no-update-lock-file
nix build .#darwinConfigurations.adri.system --print-out-paths
```

Check Pure Data:

```bash
pd -version
pd -help 2>&1 | grep -- '-path'
```

Check Max packages:

```bash
ls "$HOME/Documents/Max 9/Packages/nn_tilde"
ls "$HOME/Documents/Max 9/Packages/nn_tilde/models"
```

## Security

* Every fetched archive is pinned by SRI hash.
* No mutable nightly URLs.
* RAVE/vschaos2 models are unfree and explicitly allowlisted in `modules/den.nix`.
* The packages run upstream binaries; review new upstream releases before bumping hashes.

## Troubleshooting

| Symptom | Check |
|---|---|
| hash mismatch | upstream re-uploaded the archive; pin a new version and hash |
| `FluCoMa-PD-Mac.dmg` not found | check the `1.0.10` release URL |
| Pd cannot find an external | inspect the wrapper's `-path` flags |
| Max cannot load `nn_tilde` | check the `Documents/Max 9/Packages/nn_tilde` link |
| model missing | confirm the model package is in `nativeBuildInputs` and copied to `models/` |
| unfree model rejected | add its name to the narrow unfree allowlist |
