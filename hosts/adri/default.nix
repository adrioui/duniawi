{ pkgs, lib, username, self, ... }:

{
  
  
  environment.systemPackages = with pkgs; [ 
    
    neofetch 
    vim 
    opencode

    
    btop
    coreutils
    direnv
    gh
    go
    lazydocker
    neovim
    netbird
    nodejs
    podman
    rustup

    
    statix        
    nixpkgs-fmt   
    deadnix       
    nix-tree      
  ];

  
  nix.settings.experimental-features = "nix-command flakes";

  users.users.${username} = {
    home = "/Users/${username}";
  };

  
  system.primaryUser = username;

  
  programs.zsh.enable = true;

  
  launchd.daemons.netbird = {
    serviceConfig = {
      Label = "io.netbird.client";
      ProgramArguments = [
        "/bin/sh"
        "-c"
        "/bin/wait4path /nix/store && /bin/mkdir -p /var/run/netbird && exec /run/current-system/sw/bin/netbird service run"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/var/log/netbird/client.log";
      StandardErrorPath = "/var/log/netbird/client.error.log";
    };
  };

  
  system.configurationRevision = self.rev or self.dirtyRev or null;

  
  
  system.stateVersion = 6;

  
  nixpkgs.hostPlatform = "aarch64-darwin";
}
