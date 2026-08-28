{ config, ... }:

{
  homebrew = {
    
    
    
    enable = true;

    
    
    
    onActivation = {
      autoUpdate = false;
      cleanup = "zap";
      upgrade = false;
    };

    
    casks = [
      "anydesk"
      "discord"
      "firefox"
      "font-hack-nerd-font"
      "ghostty"
      "obsidian"
      "orbstack"
      "typora"
      "warp"
      "yoink"
      "zen"
      "zed"
      "raycast"
      
      
    ];
    brews = [
      "steveyegge/beads/bd"
    ];
  };

  assertions = [
    {
      assertion = !config.homebrew.enable || !config.homebrew.onActivation.autoUpdate;
      message = "Keep Homebrew activation idempotent: set homebrew.onActivation.autoUpdate = false and update Brew metadata explicitly.";
    }
    {
      assertion = !config.homebrew.enable || !config.homebrew.onActivation.upgrade;
      message = "Keep Homebrew activation deterministic: set homebrew.onActivation.upgrade = false and upgrade formulae explicitly.";
    }
  ];
}
