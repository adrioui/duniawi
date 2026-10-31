{ inputs, ... }:
{
  den.aspects.nixosUser.homeManager =
    { config, pkgs, ... }:
    let
      llm = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
      helium = inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.default;
    in
    {
      home = {
        
        
        stateVersion = "26.05";

        sessionPath = [
          "$HOME/.local/bin"
          "$HOME/.npm-global/bin"
        ];

        sessionVariables = {
          EDITOR = "nvim";
          VISUAL = "nvim";
          PAGER = "less";
          BROWSER = "helium";
        };

        packages = with pkgs; [
          age
          bat
          btop
          bun
          curl
          direnv
          eza
          fastfetch
          fd
          ffmpeg
          fzf
          gcc
          gh
          git
          gnumake
          go
          helium
          helix
          jq
          lazydocker
          lazygit
          less
          neovim
          nix-tree
          nixd
          nodejs
          openssh
          pkg-config
          pnpm
          python3
          qbittorrent
          ripgrep
          rustup
          sops
          sqlite
          tmux
          tree
          unzip
          uv
          vim
          wget
          which
          yq
          yt-dlp
          zellij
          zip
          zoxide
          zsh

          (pkgs.callPackage ../pkgs/amp-cli.nix { })
          llm.claude-code
          llm.cursor-agent
          llm.herdr
          llm.opencode
          llm.pi
        ];
      };

      xdg.mimeApps = {
        enable = true;
        defaultApplications = {
          "text/html" = "helium.desktop";
          "application/xhtml+xml" = "helium.desktop";
          "x-scheme-handler/http" = "helium.desktop";
          "x-scheme-handler/https" = "helium.desktop";
        };
      };

      programs = {
        bat.enable = true;
        direnv = {
          enable = true;
          nix-direnv.enable = true;
        };
        eza.enable = true;
        fzf = {
          enable = true;
          enableZshIntegration = true;
        };
        zoxide = {
          enable = true;
          enableZshIntegration = true;
        };
      };

      assertions = [
        {
          assertion = config.home.username == "adrioui";
          message = "The NixOS home must belong to the adrioui account.";
        }
        {
          assertion = config.home.stateVersion == "26.05";
          message = "The NixOS home stateVersion is 26.05, not the Darwin 23.11 value.";
        }
      ];
    };
}
