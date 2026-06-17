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
  # Keep launchd command wiring declarative instead of depending on the mutable
  # current-system profile path at runtime.
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
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages = [
    # Existing
    pkgs.fastfetch
    pkgs.vim

    # GUI apps managed by Nix
    pkgs.alacritty
    pkgs.kitty

    # CLI tools (migrated from Homebrew)
    pkgs.btop
    pkgs.coreutils
    pkgs.direnv
    pkgs.gh
    pkgs.go
    pkgs.bun
    pkgs.lazydocker

    # Editors
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

    # AI coding agents
    # pkgs.llm-agents.codex
    pkgs.llm-agents.pi
    pkgs.llm-agents.opencode

    pkgs.eslint
    pkgs.proxychains-ng
    pkgs.curl
    pkgs.age
    pkgs.sops
    pkgs.rclone

    # Development tools for Nix
    pkgs.nixfmt-tree # Formatter for 'nix fmt'
    pkgs.statix # Nix linter
    pkgs.deadnix # Find unused Nix code
    pkgs.nix-tree # Browse Nix dependencies
  ];

  nix = {
    # This repo is flake-first. Keep imperative CLI commands aligned with the
    # same pinned nixpkgs revision instead of falling back to mutable channels.
    channel.enable = false;
    registry.nixpkgs.flake = inputs.nixpkgs;
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

    settings = {
      # Necessary for modern flake-based workflows.
      experimental-features = "nix-command flakes";

      # Surface richer evaluation and build failure context during local
      # rebuilds so humans and agents do not have to reproduce failures just to
      # get a trace.
      show-trace = true;
      log-lines = 50;

      # Keep cache configuration declarative here instead of in a drifting
      # standalone nix.conf.
      extra-substituters = [ "https://ibis.cachix.org" ];
      extra-trusted-public-keys = [
        "ibis.cachix.org-1:tKNWCdKmBXJFK1JE/SnA41z7U7XPFOnB7Nw0vLKXaLA="
      ];

      # Allow user to manage binary caches (needed for devenv cachix).
      trusted-users = [ "root" username ];
    };

    gc = {
      automatic = true;
      options = "--delete-older-than 14d";
    };

    # Prefer periodic optimisation over per-build hardlinking so rebuilds stay
    # snappy during local iteration.
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

  # Enable alternative shell support in nix-darwin.
  programs.zsh.enable = true;

  # Tailscale client daemon (package + launchd service managed by nix-darwin)
  services.tailscale.enable = true;

  # NetBird VPN daemon service
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
    # Required for homebrew and other user-specific features
    primaryUser = username;

    # Set Git commit hash for darwin-version.
    configurationRevision = self.rev or self.dirtyRev or null;

    # Used for backwards compatibility, please read the changelog before changing.
    # $ darwin-rebuild changelog
    stateVersion = 6;
  };

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";
}
