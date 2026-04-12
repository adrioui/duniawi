{
  pkgs,
  username,
  self,
  ...
}:

let
  humanlayer = pkgs.callPackage ../../pkgs/humanlayer.nix { };
in
{
  
  
  environment.systemPackages = [
    
    pkgs.fastfetch
    pkgs.vim
    pkgs.llm-agents.opencode
    humanlayer

    
    pkgs.alacritty
    pkgs.kitty

    
    pkgs.btop
    pkgs.coreutils
    pkgs.direnv
    pkgs.gh
    pkgs.go
    pkgs.bun
    pkgs.lazydocker
    pkgs.neovim
    pkgs.netbird
    pkgs.nodejs
    pkgs.podman
    pkgs.rclone
    pkgs.rustup
    pkgs.sshpass
    pkgs.freetds
    pkgs.ripgrep
    pkgs.uv
    pkgs.mkdocs
    pkgs.pnpm
    pkgs.graphviz
    pkgs.lazygit
    pkgs.emscripten
    pkgs.javaPackages.compiler.openjdk11
    pkgs.gradle_9
    pkgs.groovy
    pkgs.duckdb
    pkgs.trufflehog
    pkgs.checkov
    pkgs.terraform
    pkgs.tflint
    pkgs.trivy
    pkgs.tfsec
    pkgs.yarn
    pkgs.codebuff
    pkgs.zellij
    pkgs.llm-agents.codex
    pkgs.claude-code
    pkgs.llm-agents.amp
    pkgs.llm-agents.pi
    pkgs.eslint
    pkgs.age
    pkgs.sops

    
    pkgs.nixfmt-tree 
    pkgs.statix 
    pkgs.deadnix 
    pkgs.nix-tree 
  ];

  
  nix.settings.experimental-features = "nix-command flakes";

  
  nix.settings.trusted-users = [
    "root"
    username
  ];

  users.users.${username} = {
    home = "/Users/${username}";
  };

  
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

  system = {
    
    primaryUser = username;

    
    configurationRevision = self.rev or self.dirtyRev or null;

    
    
    stateVersion = 6;
  };

  
  nixpkgs.hostPlatform = "aarch64-darwin";
}
