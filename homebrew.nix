_:

{
  homebrew = {
    
    
    
    enable = true;

    
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
    };

    
    casks = [
      "dbeaver-community"
      "discord"
      "firefox"
      "font-hack-nerd-font"
      "ghostty"
      "obsidian"
      "orbstack"
      "warp"
      "zed"
      "yoink"
      "anydesk"
      "typora"
    ];

    brews = [
      "steveyegge/beads/bd"
    ];
  };
}
