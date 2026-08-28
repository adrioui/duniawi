{
  flake.modules.darwin.max = {
    homebrew.casks = [ "cycling74-max" ];
  };

  flake.modules.homeManager.max =
    { pkgs, ... }:
    {
      home.file."Documents/Max 9/Packages/nn_tilde".source = pkgs.callPackage ../pkgs/nn-tilde-max.nix {
        raveIsisModel = pkgs.callPackage ../pkgs/rave-isis-model.nix { };
        ravePercussionModel = pkgs.callPackage ../pkgs/rave-percussion-model.nix { };
        vschaos2Model = pkgs.callPackage ../pkgs/vschaos2-ordinario-1024-model.nix { };
      };
    };
}
