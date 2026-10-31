{
  inputs,
  ...
}:
{
  perSystem =
    { pkgs, ... }:
    let
      inherit (pkgs) lib;
      isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
      isLinux = pkgs.stdenv.hostPlatform.isLinux;

      darwinConfig = inputs.self.darwinConfigurations.adri.config;

      srcForChecks = lib.cleanSourceWith {
        src = inputs.self;
        filter =
          path: _:
          let
            root = "${toString inputs.self}/";
            fullPath = toString path;
            relativePath = lib.removePrefix root fullPath;
          in
          !(
            relativePath == "result"
            || lib.hasPrefix "result-" relativePath
            || lib.hasPrefix ".git/" relativePath
            || lib.hasPrefix "thoughts/" relativePath
          );
      };

      proxy = pkgs.callPackage ../pkgs/amp-deepseek { };
    in
    {
      packages = {
        amp-deepseek-proxy = proxy;
      }
      // lib.optionalAttrs isDarwin {
        xcodebuildmcp = pkgs.callPackage ../pkgs/xcodebuildmcp.nix { src = inputs.xcodebuildmcp; };
        default = pkgs.callPackage ../pkgs/xcodebuildmcp.nix { src = inputs.xcodebuildmcp; };
      }
      // lib.optionalAttrs isLinux {
        default = proxy;
      };

      devShells.default = pkgs.mkShell {
        packages = [
          pkgs.deadnix
          pkgs.flake-checker
          pkgs.nixfmt-tree
          pkgs.statix
        ];
      };

      checks = {
        nixfmt = pkgs.runCommand "nixfmt-check" { src = srcForChecks; } ''
          ${pkgs.nixfmt}/bin/nixfmt --check $(find "$src" -name '*.nix' -type f)
          touch "$out"
        '';

        deadnix = pkgs.runCommand "deadnix-check" { src = srcForChecks; } ''
          ${pkgs.deadnix}/bin/deadnix --fail "$src"
          touch "$out"
        '';

        statix = pkgs.runCommand "statix-check" { src = srcForChecks; } ''
          ${pkgs.statix}/bin/statix check "$src"
          touch "$out"
        '';

        lockfile = pkgs.runCommand "flake-lock-check" { src = ../flake.lock; } ''
          ${pkgs.flake-checker}/bin/flake-checker "$src"
          touch "$out"
        '';

        amp-deepseek =
          pkgs.runCommand "amp-deepseek-tests"
            {
              src = ../pkgs/amp-deepseek;
              nativeBuildInputs = [ pkgs.nodejs ];
            }
            ''
              cp -r "$src" "$TMPDIR/amp-deepseek"
              cd "$TMPDIR/amp-deepseek"
              node --test test/*.test.mjs
              touch "$out"
            '';
      }
      // lib.optionalAttrs isDarwin {
        darwin-system = inputs.self.darwinConfigurations.adri.system;
        home-manager-activation =
          darwinConfig.home-manager.users.${darwinConfig.system.primaryUser}.home.activationPackage;
      }
      // lib.optionalAttrs isLinux {
        nixos-system = inputs.self.nixosConfigurations.t14.config.system.build.toplevel;
        nixos-home-manager-activation =
          inputs.self.nixosConfigurations.t14.config.home-manager.users.adrioui.home.activationPackage;

        migration-fixture =
          pkgs.runCommand "migration-fixture"
            {
              src = ../tests/migration-fixture.sh;
              nativeBuildInputs = [
                pkgs.acl
                pkgs.attr
                pkgs.rsync
                pkgs.sqlite
              ];
            }
            ''
              ${pkgs.bash}/bin/bash "$src"
              touch "$out"
            '';
      };

      formatter = pkgs.nixfmt-tree;
    };
}
