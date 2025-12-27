{ config, lib, pkgs, username, ... }:

{
  imports = [
    ./opencode.nix
  ];

  home.stateVersion = "23.11";
  home.username = username;
  home.homeDirectory = "/Users/${username}";

  
  xdg.enable = true;

  
  programs.zsh = {
    enable = true;
    shellAliases = {
      
      dr = "darwin-rebuild switch --flake ~/.config/nix";
      drb = "darwin-rebuild build --flake ~/.config/nix";
      
      
      dru = "cd ~/.config/nix && nix flake update && darwin-rebuild switch --flake .";
      
      
      drn = "darwin-rebuild build --flake ~/.config/nix && nix store diff-closures /run/current-system ./result";
      
      
      dre = "cd ~/.config/nix && $EDITOR flake.nix";
    };
  };
}
