{
  pkgs,
  ...
}:

{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    # Load nerd-font-symbols preset for Nerd Font icons
    settings = builtins.fromTOML (
      builtins.readFile "${pkgs.starship}/share/starship/presets/nerd-font-symbols.toml"
    );
  };
}
