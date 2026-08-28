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
      config.flake.modules.darwin.base
      config.flake.modules.darwin.homebrew
      config.flake.modules.darwin.vpn
      config.flake.modules.darwin.audio
      config.flake.modules.darwin.ai
      config.flake.modules.darwin.shell
      config.flake.modules.darwin.editor
      config.flake.modules.darwin.dev
      config.flake.modules.darwin.media
      config.flake.modules.darwin.xcode
      inputs.home-manager.darwinModules.home-manager
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "backup";
          users.${username}.imports = [
            config.flake.modules.homeManager.base
            config.flake.modules.homeManager.vpn
            config.flake.modules.homeManager.ai
            config.flake.modules.homeManager.shell
            config.flake.modules.homeManager.media
          ];
          extraSpecialArgs = { inherit inputs username; };
        };
      }
    ];
  };
}
