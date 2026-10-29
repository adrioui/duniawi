{
  den.aspects.homebrew.darwin =
    { config, ... }:
    {
      homebrew = {
        enable = true;

        enableZshIntegration = true;

        onActivation = {
          autoUpdate = false;
          cleanup = "zap";
          upgrade = false;
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
          "steam"
          "typora"
          "warp"
          "yoink"
          "zen"
          "zed"
          "raycast"
          "codex"
        ];
        brews = [ "beads" ];
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
    };
}
