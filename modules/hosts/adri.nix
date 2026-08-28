{
  config,
  inputs,
  ...
}:
let
  username = config.flake.username;
  system = config.flake.system;
  inherit (inputs) self;
  xcodebuildmcpPkg = config.flake.xcodebuildmcpPkg;
  pkgs = import inputs.nixpkgs {
    inherit system;
    config.allowUnfreePredicate =
      pkg: builtins.elem (inputs.nixpkgs.lib.getName pkg) config.flake.unfreePackages;
    overlays = [ inputs.llm-agents.overlays.shared-nixpkgs ];
  };
in
{
  flake.darwinConfigurations.adri = inputs.nix-darwin.lib.darwinSystem {
    inherit pkgs system;

    specialArgs = {
      inherit
        inputs
        username
        self
        xcodebuildmcpPkg
        ;
    };

    modules = [
      config.flake.modules.darwin.legacy
      config.flake.modules.darwin.homebrew
      inputs.home-manager.darwinModules.home-manager
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "backup";
          users.${username}.imports = [ config.flake.modules.homeManager.legacy ];
          extraSpecialArgs = { inherit inputs username; };
        };
      }
    ];
  };
}
