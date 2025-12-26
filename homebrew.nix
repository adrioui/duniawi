{ config, lib, pkgs, ... }:

{
  
  
  
  homebrew.enable = true;

  
  homebrew.onActivation = {
    autoUpdate = true;
    cleanup = "zap";
  };

  
  homebrew.casks = [
    "dbeaver-community"
    "discord"
    "font-hack-nerd-font"
    "ghostty"
    "obsidian"
    "orbstack"
    "warp"
    "zed"
  ];

  
  

  
  
}
