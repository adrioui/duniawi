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
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages = [
    # Existing
    pkgs.neofetch
    pkgs.vim
    pkgs.llm-agents.opencode
    humanlayer

    # GUI apps managed by Nix
    pkgs.alacritty
    pkgs.kitty

    # CLI tools (migrated from Homebrew)
    pkgs.btop
    pkgs.coreutils
    pkgs.direnv
    pkgs.gh
    # go
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
    pkgs.llm-agents.claude-code
    pkgs.llm-agents.amp
    pkgs.eslint

    # Development tools for Nix
    pkgs.nixfmt-tree # Formatter for 'nix fmt'
    pkgs.statix # Nix linter
    pkgs.deadnix # Find unused Nix code
    pkgs.nix-tree # Browse Nix dependencies
  ];

  # Necessary for using flakes on this system.
  nix.settings.experimental-features = "nix-command flakes";

  # Allow user to manage binary caches (needed for devenv cachix)
  nix.settings.trusted-users = [
    "root"
    username
  ];

  users.users.${username} = {
    home = "/Users/${username}";
  };

  # Enable alternative shell support in nix-darwin.
  programs.zsh.enable = true;

  # NetBird VPN daemon service
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
