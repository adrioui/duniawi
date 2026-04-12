_:

{
  homebrew = {
    # Enable Homebrew integration
    # NOTE: Homebrew must be installed manually first:
    # /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    enable = true;

    # Declarative cleanup - removes anything not declared here
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
    };

    # GUI applications that are still better managed through Homebrew
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
