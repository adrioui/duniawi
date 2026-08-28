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
        # IRCAM ISiS RAVE model; provenance/license is not nixpkgs-reviewed.
        "rave-isis-model"
        # IRCAM RAVE percussion model; same provenance/license caveat.
        "rave-percussion-model"
        # IRCAM vSchaos2 ordinario_1024 model; same provenance/license caveat.
        "vschaos2-ordinario-1024-model"
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

        # Lint Nix files with the formatter's check mode; fail on any diff.
        nixfmt = pkgs.runCommand "nixfmt-check" { src = srcForChecks; } ''
          ${pkgs.nixfmt}/bin/nixfmt --check $(find "$src" -name '*.nix' -type f)
          touch "$out"
        '';

        # Dead code in .nix files.
        deadnix = pkgs.runCommand "deadnix-check" { src = srcForChecks; } ''
          ${pkgs.deadnix}/bin/deadnix --fail "$src"
          touch "$out"
        '';

        # Statix lints: explicit, no hidden .gitignore surprises.
        statix = pkgs.runCommand "statix-check" { src = srcForChecks; } ''
          ${pkgs.statix}/bin/statix check "$src"
          touch "$out"
        '';

        # flake.lock freshness/support.
        lockfile = pkgs.runCommand "flake-lock-check" { src = ./flake.lock; } ''
          ${pkgs.flake-checker}/bin/flake-checker "$src"
          touch "$out"
        '';
      };

      formatter.${system} = pkgs.nixfmt-tree;
    };
}
