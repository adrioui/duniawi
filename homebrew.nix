_:

{
  homebrew = {
    
    
    
    enable = true;

    
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
    };

    
    casks = [
      "anydesk"
      "dbeaver-community"
      "discord"
      "firefox"
      "font-hack-nerd-font"
      "ghostty"
      "obsidian"
      "orbstack"
      "typora"
      "warp"
      "yoink"
      "zed"
    ];

    brews = [
      "steveyegge/beads/bd"
    ];
  };
}
