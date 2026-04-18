{
  pkgs,
  username,
  ...
}:

{
  imports = [
    ./starship.nix
    ./proxychains.nix
  ];

  home = {
    stateVersion = "23.11";
    inherit username;
    homeDirectory = "/Users/${username}";

    # AI tools
    packages = [
      pkgs.llm-agents.agent-browser
      pkgs.yt-dlp
      pkgs.cloudflared
    ];
  };

  # Enable XDG Base Directory support
  xdg.enable = true;

  # Shell configuration with convenient aliases
  programs.zsh = {
    enable = true;
    shellAliases = {
      # Quick rebuild
      dr = "sudo darwin-rebuild switch --flake ~/.config/nix";
      drb = "sudo darwin-rebuild build --flake ~/.config/nix";

      # Update and rebuild
      dru = "cd ~/.config/nix && nix flake update && sudo darwin-rebuild switch --flake .#adri";

      # Preview what will change
      drn = "sudo darwin-rebuild build --flake ~/.config/nix && nix store diff-closures /run/current-system ./result";

      # Edit config
      dre = "cd ~/.config/nix && $EDITOR flake.nix";
    };
  };
}
