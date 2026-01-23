{
  pkgs,
  lib,
  username,
  self,
  ...
}:

let
  humanlayer = pkgs.callPackage ../../pkgs/humanlayer.nix { };
in
{
  
  
  environment.systemPackages = with pkgs; [
    
    neofetch
    vim
    opencode
    humanlayer

    
    btop
    coreutils
    direnv
    gh
    
    bun
    lazydocker
    neovim
    netbird
    nodejs
    podman
    rclone
    rustup
    sshpass
    freetds
    ripgrep
    uv
    mkdocs
    pnpm
    graphviz
    lazygit
    emscripten
    javaPackages.compiler.openjdk11
    gradle_9
    duckdb
    trufflehog
    checkov
    terraform
    tflint
    trivy
    tfsec
    yarn
    codebuff
    zellij
    amp-cli
    eslint

    
    statix 
    nixpkgs-fmt 
    deadnix 
    nix-tree 
  ];

  
  nix.settings.experimental-features = "nix-command flakes";

  
  nix.settings.trusted-users = [ "root" username ];

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
