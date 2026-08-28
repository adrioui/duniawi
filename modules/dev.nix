{
  flake.modules.darwin.dev =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        pkgs.fastfetch
        pkgs.btop
        pkgs.coreutils
        pkgs.direnv
        pkgs.gh
        pkgs.go
        (pkgs.callPackage ../pkgs/bun-1.3.14.nix { })
        pkgs.nodejs
        pkgs.podman
        pkgs.rclone
        pkgs.rustup
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
        pkgs.lazydocker
        pkgs.eslint
        pkgs.curl
        pkgs.age
        pkgs.sops
        pkgs.sshpass
        # Development tools for Nix
        pkgs.nixfmt-tree # Formatter for 'nix fmt'
        pkgs.statix # Nix linter
        pkgs.deadnix # Find unused Nix code
        pkgs.nix-tree # Browse Nix dependencies
      ];
    };
}
