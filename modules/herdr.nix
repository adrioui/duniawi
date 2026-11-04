{
  den.aspects.herdr = {
    darwin =
      { pkgs, ... }:
      {
        environment.systemPackages = [
          (pkgs.callPackage ../pkgs/herdr-app.nix { })
          (pkgs.callPackage ../pkgs/herdr-core.nix { })
        ];
      };
  };
}
