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

    # GUI applications only - CLI tools go in environment.systemPackages
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
