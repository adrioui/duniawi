{
  config,
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

    
    packages = [
      pkgs.llm-agents.agent-browser
      pkgs.yt-dlp
      pkgs.cloudflared
    ];
  };

  
  xdg.enable = true;

  
  programs.zsh = {
    enable = true;
    dotDir = config.home.homeDirectory;
    shellAliases = {
      
      dr = "sudo darwin-rebuild switch --flake path:$HOME/.config/nix#adri";
      drb = "sudo darwin-rebuild build --flake path:$HOME/.config/nix#adri";

      
      dru = "cd ~/.config/nix && nix flake update && sudo darwin-rebuild switch --flake path:$PWD#adri";

      
      drn = "cd ~/.config/nix && sudo darwin-rebuild build --flake path:$PWD#adri && nix store diff-closures /run/current-system ./result";

      
      dre = "cd ~/.config/nix && $EDITOR flake.nix";
    };
  };
}
