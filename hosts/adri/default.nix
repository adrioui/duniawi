{
  config,
  inputs,
  lib,
  pkgs,
  username,
  self,
  ...
}:

let
  
  
  netbirdService = pkgs.writeShellApplication {
    name = "netbird-service";
    text = ''
      /bin/wait4path /nix/store
      /bin/mkdir -p /var/run/netbird
      exec ${lib.getExe pkgs.netbird} service run
    '';
  };
in
{
  
  
  environment.systemPackages = [
    
    pkgs.fastfetch
    pkgs.vim

    
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
    pkgs.helix

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
    pkgs.terraform
    pkgs.tflint
    pkgs.trivy
    pkgs.tfsec
    pkgs.yarn
    pkgs.codebuff
    pkgs.zellij

    
    
    pkgs.llm-agents.pi
    pkgs.llm-agents.opencode

    pkgs.eslint
    pkgs.proxychains-ng
    pkgs.curl
    pkgs.age
    pkgs.sops
    pkgs.rclone

    
    pkgs.nixfmt-tree 
    pkgs.statix 
    pkgs.deadnix 
    pkgs.nix-tree 
  ];

  nix = {
    
    
    channel.enable = false;
    registry.nixpkgs.flake = inputs.nixpkgs;
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

    settings = {
      
      experimental-features = "nix-command flakes";

      
      
      
      show-trace = true;
      log-lines = 50;

      
      
      extra-substituters = [ "https://ibis.cachix.org" ];
      extra-trusted-public-keys = [
        "ibis.cachix.org-1:tKNWCdKmBXJFK1JE/SnA41z7U7XPFOnB7Nw0vLKXaLA="
      ];

      
      trusted-users = [ "root" username ];
    };

    gc = {
      automatic = true;
      options = "--delete-older-than 14d";
    };

    
    
    optimise.automatic = true;
  };

  assertions = [
    {
      assertion = !config.nix.channel.enable;
      message = "Keep this repo flake-first: set nix.channel.enable = false.";
    }
    {
      assertion = config.nix.registry ? nixpkgs;
      message = "Keep a system nix.registry.nixpkgs entry so flake CLI commands resolve through the pinned nixpkgs input.";
    }
    {
      assertion =
        (config.nix.registry.nixpkgs.from.id or null) == "nixpkgs"
        && (config.nix.registry.nixpkgs.exact or false);
      message = "Keep nix.registry.nixpkgs as an exact system registry entry for the flake-first workflow.";
    }
    {
      assertion = builtins.elem "nixpkgs=${config.nix.registry.nixpkgs.flake}" config.nix.nixPath;
      message = "Keep nix.nixPath aligned with nix.registry.nixpkgs for legacy <nixpkgs> consumers.";
    }
    {
      assertion =
        let
          features = lib.splitString " " config.nix.settings.experimental-features;
        in
        builtins.all (feature: builtins.elem feature features) [
          "nix-command"
          "flakes"
        ];
      message = "Keep modern flake workflows enabled: nix.settings.experimental-features must include nix-command and flakes.";
    }
  ];

  users.users.${username} = {
    home = "/Users/${username}";
  };

  
  programs.zsh.enable = true;

  
  services.tailscale.enable = true;

  
  launchd.daemons.netbird = {
    serviceConfig = {
      Label = "io.netbird.client";
      ProgramArguments = [ (lib.getExe netbirdService) ];
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
