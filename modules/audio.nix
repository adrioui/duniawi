{
  den.aspects.audio.darwin =
    { pkgs, ... }:
    let
      puredataPkg = pkgs.callPackage ../pkgs/puredata.nix { };
      pdElse = pkgs.callPackage ../pkgs/pd-else-darwin.nix { };
      pdGem = pkgs.callPackage ../pkgs/pd-gem-darwin.nix { };
      pdZexy = pkgs.callPackage ../pkgs/pd-zexy-darwin.nix { };
      pdFlucoma = pkgs.callPackage ../pkgs/pd-flucoma-darwin.nix { };
      pdida = pkgs.callPackage ../pkgs/pdida.nix { };
      nnTilde = pkgs.callPackage ../pkgs/nn-tilde.nix { };
      raveIsis = pkgs.callPackage ../pkgs/rave-isis-model.nix { };
      ravePercussion = pkgs.callPackage ../pkgs/rave-percussion-model.nix { };
      raveWater = pkgs.callPackage ../pkgs/rave-water-model.nix { };
      vschaos2 = pkgs.callPackage ../pkgs/vschaos2-ordinario-1024-model.nix { };
      puredataWithExternals = pkgs.callPackage ../pkgs/puredata-with-externals.nix {
        puredata = puredataPkg;
        plugins = [
          pdElse
          pdGem
          pdZexy
          pdFlucoma
          pdida
          nnTilde
          raveIsis
          ravePercussion
          raveWater
          vschaos2
        ];
      };
    in
    {
      environment.systemPackages = [ puredataWithExternals ];
      homebrew.casks = [ "plugdata" ];
    };
}
