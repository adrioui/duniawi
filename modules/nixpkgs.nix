{
  config,
  inputs,
  ...
}:
let
  pkgsFor =
    system: unfree:
    import inputs.nixpkgs {
      inherit system;
      config.allowUnfreePredicate = pkg: builtins.elem (inputs.nixpkgs.lib.getName pkg) unfree;
      overlays = [ inputs.llm-agents.overlays.shared-nixpkgs ];
    };
in
{
  config = {
    flake = {
      username = "adrifadilah";
      system = "aarch64-darwin";
      unfreePackages = [
        "amp"
        "terraform"
        # IRCAM ISiS RAVE model; provenance/license is not nixpkgs-reviewed.
        "rave-isis-model"
        # IRCAM RAVE percussion model; same provenance/license caveat.
        "rave-percussion-model"
        # IRCAM vSchaos2 ordinario_1024 model; same provenance/license caveat.
        "vschaos2-ordinario-1024-model"
      ];
      xcodebuildmcpPkg =
        (pkgsFor config.flake.system config.flake.unfreePackages).callPackage ../pkgs/xcodebuildmcp.nix
          {
            src = inputs.xcodebuildmcp;
          };
    };
  };
}
