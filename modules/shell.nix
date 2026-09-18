{
  den.aspects.shell = {
    darwin =
      { pkgs, ... }:
      {
        programs.zsh.enable = true;
        environment.systemPackages = [
          pkgs.alacritty
          pkgs.kitty
        ];
      };

    homeManager =
      { config, ... }:
      {
        xdg.enable = true;

        programs.starship = {
          enable = true;
          enableZshIntegration = true;
          presets = [ "nerd-font-symbols" ];
        };

        home.sessionVariables = {
          MAGNITUDE_USE_LOCAL = "1";
          MAGNITUDE_ENDPOINT = "http://100.87.7.118:8317/api/v1";
        };

        home.sessionPath = [ "$HOME/.npm-global/bin" ];

        programs.zsh = {
          enable = true;
          dotDir = config.home.homeDirectory;
          initContent = ''
            export HCNOTE_API_KEY="$(/usr/bin/security find-generic-password -ws hcnote 2>/dev/null || true)"
            export COMMANDCODE_API_KEY="$(/usr/bin/security find-generic-password -s commandcode-api-key -w 2>/dev/null || true)"
            # OpenCode Zen/Go key for opencode CLI and codex-router (opencode-go).
            # Stored in Keychain as `opencode-api-key`, never in the repo.
            export OPENCODE_API_KEY="$(/usr/bin/security find-generic-password -s opencode-api-key -w 2>/dev/null || true)"
            export OPENCODE_GO_API_KEY="$OPENCODE_API_KEY"
          '';
          shellAliases = {
            dr = "sudo darwin-rebuild switch --flake path:$HOME/.config/nix#adri";
            drb = "sudo darwin-rebuild build --flake path:$HOME/.config/nix#adri";
            dru = "cd ~/.config/nix && nix flake update && sudo darwin-rebuild switch --flake path:$PWD#adri";
            drn = "cd ~/.config/nix && sudo darwin-rebuild build --flake path:$PWD#adri && nix store diff-closures /run/current-system ./result";
            dre = "cd ~/.config/nix && $EDITOR flake.nix";
          };
        };
      };
  };
}
