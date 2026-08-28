{
  den.aspects.editor.darwin =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        pkgs.vim
        pkgs.neovim
        pkgs.helix
      ];
    };
}
