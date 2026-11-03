{ inputs, ... }:
{
  den.aspects.nixosUser.homeManager =
    {
      config,
      lib,
      pkgs,
      ...
    }:
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

        activation.kdeCleanup = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
          run mkdir -p "$HOME/.config/user-disabled/kde"
          for path in \
            .config/gtk-3.0 .config/gtk-4.0 .config/xsettingsd \
            .config/kdeglobals .config/qt5ct .config/qt6ct \
            .config/plasmarc .config/plasmanotifyrc .config/plasmashellrc \
            .config/plasma-localerc .config/plasma-org.kde.plasma.desktop-appletsrc \
            .config/kwinrc .config/kwinoutputconfig.json .config/kscreenlockerrc \
            .config/kwalletrc .config/krunnerrc .config/baloofilerc \
            .config/powerdevilrc .config/kactivitymanagerdrc \
            .config/kactivitymanagerd-statsrc .config/ksmserverrc \
            .config/kded5rc .config/kded6rc .config/kdedefaults \
            .config/khotkeysrc .config/kaccessrc .config/kcminputrc \
            .config/kdeconnect; do
            if [ -e "$HOME/$path" ] && [ ! -e "$HOME/.config/user-disabled/kde/$(basename "$path")" ]; then
              run mv "$HOME/$path" "$HOME/.config/user-disabled/kde/$(basename "$path")"
            fi
          done
          for path in \
            .local/share/plasma .local/share/plasmashell \
            .local/share/kded5 .local/share/kservices5 .local/share/kxmlgui5 \
            .local/share/knotifications5 .local/share/kwalletd; do
            if [ -e "$HOME/$path" ] && [ ! -e "$HOME/.config/user-disabled/kde/$(basename "$path")" ]; then
              run mv "$HOME/$path" "$HOME/.config/user-disabled/kde/$(basename "$path")"
            fi
          done
        '';
      };

      gtk = {
        enable = true;
        theme = {
          name = "Adwaita";
          package = pkgs.gnome-themes-extra;
        };
        iconTheme = {
          name = "Adwaita";
          package = pkgs.adwaita-icon-theme;
        };
        cursorTheme = {
          name = "Adwaita";
          package = pkgs.adwaita-icon-theme;
        };
        font = {
          name = "Adwaita Sans";
          size = 11;
          package = pkgs.adwaita-fonts;
        };
      };

      dconf.settings = {
        "org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
          gtk-theme = "Adwaita";
          icon-theme = "Adwaita";
          cursor-theme = "Adwaita";
          font-name = "Adwaita Sans 11";
          document-font-name = "Adwaita Sans 11";
          monospace-font-name = "Hack 10";
        };
        "org/gnome/desktop/wm/preferences" = {
          button-layout = "appmenu:minimize,maximize,close";
        };
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
