{
  description = "adri nix-darwin setup";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    llm-agents.url = "github:numtide/llm-agents.nix";
  };

  outputs =
    inputs@{
      self,
      nix-darwin,
      nixpkgs,
      home-manager,
      llm-agents,
    }:
    let
      username = "adrifadilah";
      system = "aarch64-darwin";
    in
    {
      
      
      darwinConfigurations."adri" = nix-darwin.lib.darwinSystem {
        inherit system;
        pkgs = import nixpkgs { 
          inherit system; 
          config.allowUnfree = true;
          overlays = [ llm-agents.overlays.default ];
        };

        specialArgs = { inherit username self; };

        modules = [
          ./hosts/adri
          ./homebrew.nix
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.users.${username} = import ./home/${username};
            home-manager.extraSpecialArgs = { inherit inputs username; };
          }
        ];
      };

      
      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt-tree;
    };
}
