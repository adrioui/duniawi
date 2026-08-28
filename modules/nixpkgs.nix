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
        
        "rave-isis-model"
        
        "rave-percussion-model"
        
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
