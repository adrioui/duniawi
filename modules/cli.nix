{ inputs, ... }:
{
  den.aspects.cli.homeManager =
    { lib, pkgs, ... }:
    let
      # t14 runs nixpkgs-stable; the shared CLI tools come from the pinned
      # nixpkgs-cli input so both hosts get the same current releases.
      cliPkgs = import inputs.nixpkgs-cli {
        system = pkgs.stdenv.hostPlatform.system;
        config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "amp-cli" ];
      };
    in
    {
      home.packages = [
        (cliPkgs.callPackage ../pkgs/amp-cli.nix { })
        cliPkgs.pi-coding-agent
        (cliPkgs.callPackage ../pkgs/opencode2.nix { })
        inputs.bend.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];

      home.activation.ampOfficialModes = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        target="$HOME/.config/amp/plugins/official-modes"
        source="${../pkgs/amp-official-modes}"
        rm -rf "$target"
        mkdir -p "$target"
        cp -R "$source"/. "$target"/
        chmod -R u+w "$target"
      '';
    };
}
