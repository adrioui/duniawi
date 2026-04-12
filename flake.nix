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

      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ llm-agents.overlays.default ];
        };

      pkgs = pkgsFor system;

      srcForChecks = pkgs.lib.cleanSourceWith {
        src = self;
        filter =
          path: _:
          let
            root = "${toString self}/";
            fullPath = toString path;
            relativePath = pkgs.lib.removePrefix root fullPath;
          in
          !(
            relativePath == "result"
            || pkgs.lib.hasPrefix "result-" relativePath
            || pkgs.lib.hasPrefix ".git/" relativePath
            || pkgs.lib.hasPrefix "thoughts/" relativePath
          );
      };
    in
    {
      # Build darwin flake using:
      # $ darwin-rebuild build --flake .#adri
      darwinConfigurations.adri = nix-darwin.lib.darwinSystem {
        inherit pkgs system;

        specialArgs = { inherit username self; };

        modules = [
          ./hosts/adri
          ./homebrew.nix
          home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "backup";
              users.${username} = import ./home/${username};
              extraSpecialArgs = { inherit inputs username; };
            };
          }
        ];
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.deadnix
          pkgs.nixfmt-tree
          pkgs.statix
        ];
      };

      checks.${system} = {
        deadnix = pkgs.runCommand "deadnix-check" { src = srcForChecks; } ''
          ${pkgs.deadnix}/bin/deadnix "$src"
          touch "$out"
        '';

        nixfmt = pkgs.runCommand "nixfmt-check" { src = srcForChecks; } ''
          work="$TMPDIR/src"
          mkdir -p "$work"
          cp -R "$src"/. "$work"/
          chmod -R u+w "$work"
          cd "$work"
          ${pkgs.nixfmt-tree}/bin/treefmt --ci --tree-root "$work" --walk filesystem
          touch "$out"
        '';

        statix = pkgs.runCommand "statix-check" { src = srcForChecks; } ''
          ${pkgs.statix}/bin/statix check "$src"
          touch "$out"
        '';
      };

      formatter.${system} = pkgs.nixfmt-tree;
    };
}
