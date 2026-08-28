{
  config,
  inputs,
  lib,
  pkgs,
  username,
  self,
  xcodebuildmcpPkg,
  ...
}:

let
  puredataPkg = pkgs.callPackage ../../pkgs/puredata.nix { };
  pdElse = pkgs.callPackage ../../pkgs/pd-else-darwin.nix { };
  nnTilde = pkgs.callPackage ../../pkgs/nn-tilde.nix { };
  raveIsis = pkgs.callPackage ../../pkgs/rave-isis-model.nix { };
  ravePercussion = pkgs.callPackage ../../pkgs/rave-percussion-model.nix { };
  vschaos2 = pkgs.callPackage ../../pkgs/vschaos2-ordinario-1024-model.nix { };
  puredataWithExternals = pkgs.callPackage ../../pkgs/puredata-with-externals.nix {
    puredata = puredataPkg;
    plugins = [
      pdElse
      nnTilde
      raveIsis
      ravePercussion
      vschaos2
    ];
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
    (pkgs.callPackage ../../pkgs/bun-1.3.14.nix { })
    pkgs.lazydocker
    pkgs.qbittorrent

    
    pkgs.neovim
    pkgs.helix

    pkgs.nodejs
    pkgs.podman
    pkgs.rclone
    pkgs.rustup
    pkgs.sshpass
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
    pkgs.yarn
    pkgs.zellij

    
    pkgs.llm-agents.pi
    pkgs.llm-agents.opencode
    pkgs.llm-agents.amp
    pkgs.llm-agents.reasonix
    pkgs.llm-agents.freebuff

    
    pkgs.herdr

    
    xcodebuildmcpPkg

    pkgs.eslint
    pkgs.curl
    pkgs.age
    pkgs.sops
    pkgs.rclone
    pkgs.ffmpeg
    puredataWithExternals

    
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

      
      trusted-users = [
        "root"
        username
      ];
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

  system = {
    
    primaryUser = username;

    
    configurationRevision = self.rev or self.dirtyRev or null;

    
    
    stateVersion = 6;
  };

  
  nixpkgs.hostPlatform = "aarch64-darwin";
}
