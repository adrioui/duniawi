{
  flake.modules.darwin.audio =
    { pkgs, ... }:
    let
      puredataPkg = pkgs.callPackage ../pkgs/puredata.nix { };
      pdElse = pkgs.callPackage ../pkgs/pd-else-darwin.nix { };
      nnTilde = pkgs.callPackage ../pkgs/nn-tilde.nix { };
      raveIsis = pkgs.callPackage ../pkgs/rave-isis-model.nix { };
      ravePercussion = pkgs.callPackage ../pkgs/rave-percussion-model.nix { };
      vschaos2 = pkgs.callPackage ../pkgs/vschaos2-ordinario-1024-model.nix { };
      puredataWithExternals = pkgs.callPackage ../pkgs/puredata-with-externals.nix {
        puredata = puredataPkg;
        plugins = [
          pdElse
          nnTilde
          raveIsis
          ravePercussion
          vschaos2
        ];
      };
    in
    {
      environment.systemPackages = [ puredataWithExternals ];
      homebrew.casks = [ "plugdata" ];
    };
}
