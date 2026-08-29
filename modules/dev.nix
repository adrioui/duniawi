{
  den.aspects.dev.darwin =
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
        pkgs.lazygit
        pkgs.zellij
        pkgs.lazydocker
        pkgs.eslint
        pkgs.curl
        # Development tools for Nix
        pkgs.nixfmt-tree # Formatter for 'nix fmt'
        pkgs.statix # Nix linter
        pkgs.deadnix # Find unused Nix code
        pkgs.nix-tree # Browse Nix dependencies
      ];
    };
}
