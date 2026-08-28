{
  flake.modules.darwin.editor =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.vim pkgs.neovim pkgs.helix ];
    };
}
