{
  config,
  pkgs,
  username,
  ...
}:
{
  imports = [
    ./starship.nix
  ];

  home = {
    stateVersion = "23.11";
    inherit username;
    homeDirectory = "/Users/${username}";

    packages = [
      (pkgs.callPackage ../../pkgs/dsh.nix { })
      pkgs.yt-dlp
    ];
  };

  # Enable XDG Base Directory support
  xdg.enable = true;

  # Environment variables
  home.sessionVariables = {
    MAGNITUDE_USE_LOCAL = "1";
    MAGNITUDE_ENDPOINT = "http://100.87.7.118:8317/api/v1";
  };

  # Add user-level npm global bin to PATH
  home.sessionPath = [
    "$HOME/.npm-global/bin"
  ];

  # Shell configuration with convenient aliases
  programs.zsh = {
    enable = true;
    dotDir = config.home.homeDirectory;
    initContent = ''
      export HCNOTE_API_KEY="$(/usr/bin/security find-generic-password -ws hcnote 2>/dev/null || true)"
      export COMMANDCODE_API_KEY="$(/usr/bin/security find-generic-password -s commandcode-api-key -w 2>/dev/null || true)"
    '';
    shellAliases = {
      # Quick rebuild
      dr = "sudo darwin-rebuild switch --flake path:$HOME/.config/nix#adri";
      drb = "sudo darwin-rebuild build --flake path:$HOME/.config/nix#adri";

      # Update and rebuild
      dru = "cd ~/.config/nix && nix flake update && sudo darwin-rebuild switch --flake path:$PWD#adri";

      # Preview what will change
      drn = "cd ~/.config/nix && sudo darwin-rebuild build --flake path:$PWD#adri && nix store diff-closures /run/current-system ./result";

      # Edit config
      dre = "cd ~/.config/nix && $EDITOR flake.nix";
    };
  };
}
