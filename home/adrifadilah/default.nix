{
  pkgs,
  username,
  ...
}:

{
  imports = [
    ./opencode.nix
    ./starship.nix
  ];

  home = {
    stateVersion = "23.11";
    inherit username;
    homeDirectory = "/Users/${username}";

    
    packages = [
      pkgs.llm-agents.agent-browser
    ];
  };

  
  xdg.enable = true;

  
  programs.zsh = {
    enable = true;
    shellAliases = {
      
      dr = "darwin-rebuild switch --flake ~/.config/nix";
      drb = "darwin-rebuild build --flake ~/.config/nix";

      
      dru = "cd ~/.config/nix && nix flake update && darwin-rebuild switch --flake .";

      
      drn = "darwin-rebuild build --flake ~/.config/nix && nix store diff-closures /run/current-system ./result";

      
      dre = "cd ~/.config/nix && $EDITOR flake.nix";
    };
  };
}
