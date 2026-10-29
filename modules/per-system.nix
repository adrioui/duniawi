{
  inputs,
  ...
}:
{
  perSystem =
    { pkgs, ... }:
    let
      darwinConfig = inputs.self.darwinConfigurations.adri.config;
      username = darwinConfig.system.primaryUser;
      srcForChecks = pkgs.lib.cleanSourceWith {
        src = inputs.self;
        filter =
          path: _:
          let
            root = "${toString inputs.self}/";
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
      packages = {
        xcodebuildmcp = pkgs.callPackage ../pkgs/xcodebuildmcp.nix { src = inputs.xcodebuildmcp; };
        default = pkgs.callPackage ../pkgs/xcodebuildmcp.nix { src = inputs.xcodebuildmcp; };
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
        darwin-system = inputs.self.darwinConfigurations.adri.system;
        home-manager-activation = darwinConfig.home-manager.users.${username}.home.activationPackage;

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
      };

      formatter = pkgs.nixfmt-tree;
    };
}
