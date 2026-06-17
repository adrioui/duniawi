{ config, ... }:

{
  homebrew = {
    # Enable Homebrew integration
    # NOTE: Homebrew must be installed manually first:
    # /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    enable = true;

    # Declarative cleanup - removes anything not declared here
    # Keep rebuilds idempotent. Update Homebrew metadata explicitly instead of
    # turning every darwin-rebuild into an imperative brew update.
    onActivation = {
      autoUpdate = false;
      cleanup = "zap";
      upgrade = false;
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
      "zen"
      "zed"
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


