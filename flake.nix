{
  description = "adri nix-darwin setup";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    llm-agents.url = "github:numtide/llm-agents.nix";

    # Pin to a known-good upstream commit (v2.7.0). Bump intentionally:
    # refresh the source and the npmDeps hash in pkgs/xcodebuildmcp.nix.
    xcodebuildmcp = {
      url = "github:getsentry/XcodeBuildMCP/e6ef59b49b44012c824f0a0de261c96142e37390";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nix-darwin,
      nixpkgs,
      home-manager,
      llm-agents,
      xcodebuildmcp,
    }:
    let
      username = "adrifadilah";
      system = "aarch64-darwin";

      # Keep unfree usage explicit so package creep is visible in reviews.
      unfreePackages = [
        "amp"
        "terraform"
      ];

      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) unfreePackages;
          overlays = [ llm-agents.overlays.shared-nixpkgs ];
        };

      pkgs = pkgsFor system;

      # Resolve the XcodeBuildMCP derivation once here so the flake packages
      # output and the system profile share the same store path.
      xcodebuildmcpPkg = pkgs.callPackage ./pkgs/xcodebuildmcp.nix { src = xcodebuildmcp; };

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
      darwinConfiguration = nix-darwin.lib.darwinSystem {
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
    in
    {
      packages.${system} = {
        inherit xcodebuildmcpPkg;
        default = xcodebuildmcpPkg;
      };

      # Build darwin flake using:
      # $ darwin-rebuild build --flake path:.#adri
      darwinConfigurations.adri = darwinConfiguration;

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.deadnix
          pkgs.flake-checker
          pkgs.nixfmt-tree
          pkgs.statix
        ];
      };

      checks.${system} = {
        # nix flake check does not validate darwinConfigurations by default, so
        # wire the real system and Home Manager activation derivations in here.
        darwin-system = darwinConfiguration.system;
        home-manager-activation =
          darwinConfiguration.config.home-manager.users.${username}.home.activationPackage;

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
