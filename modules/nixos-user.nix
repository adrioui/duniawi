{ inputs, ... }:
{
  den.aspects.nixosUser.homeManager =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      helium = inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.default;
    in
    {
      home = {

        stateVersion = "26.05";

        sessionPath = [
          "$HOME/.local/bin"
        ];

        sessionVariables = {
          EDITOR = "nvim";
          VISUAL = "nvim";
          PAGER = "less";
          BROWSER = "helium";
        };

        packages = with pkgs; [
          age
          btop
          bun
          fastfetch
          fd
          ffmpeg
          gcc
          gh
          gnumake
          go
          helium
          jq
          lazydocker
          lazygit
          neovim
          nix-tree
          nixd
          nodejs
          pkg-config
          pnpm
          python3
          qbittorrent
          ripgrep
          rustup
          slack
          sops
          sqlite
          tmux
          tree
          uv
          yq
          zellij

          (pkgs.callPackage ../pkgs/herdr-app.nix { })
        ];
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
        "org/gnome/desktop/session" = {
          idle-delay = lib.hm.gvariant.mkUint32 0;
        };
        "org/gnome/desktop/screensaver" = {
          idle-activation-enabled = false;
        };
        "org/gnome/desktop/wm/preferences" = {
          button-layout = "appmenu:minimize,maximize,close";
        };
        "org/gnome/settings-daemon/plugins/power" = {
          idle-dim = false;
          sleep-inactive-ac-type = "nothing";
          sleep-inactive-battery-type = "nothing";
          power-button-action = "interactive";
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
        gpg.enable = true;
        zoxide = {
          enable = true;
          enableZshIntegration = true;
        };
      };

      services.gpg-agent = {
        enable = true;
        defaultCacheTtl = 34560000;
        maxCacheTtl = 34560000;
        pinentry.package = pkgs.pinentry-curses;
        extraConfig = "allow-preset-passphrase";
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
