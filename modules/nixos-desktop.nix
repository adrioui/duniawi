{
  den.aspects.nixosDesktop.nixos =
    { config, pkgs, ... }:
    {
      boot = {
        loader.systemd-boot = {
          enable = true;

          configurationLimit = 10;
        };
        loader.efi.canTouchEfiVariables = true;
        tmp.cleanOnBoot = true;
      };

      networking = {
        networkmanager.enable = true;
        firewall.enable = true;
      };

      time.timeZone = "Asia/Jakarta";
      i18n.defaultLocale = "en_US.UTF-8";
      console.keyMap = "us";

      hardware = {
        enableRedistributableFirmware = true;
        bluetooth.enable = true;
        graphics.enable = true;
      };

      services = {
        displayManager.gdm.enable = true;
        desktopManager.gnome.enable = true;

        libinput.enable = true;
        upower.enable = true;
        printing.enable = true;
        avahi = {
          enable = true;
          nssmdns4 = true;
        };

        pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
        };

        fstrim.enable = true;
        fwupd.enable = true;
        tlp.enable = true;
        power-profiles-daemon.enable = false;

        journald.extraConfig = "SystemMaxUse=1G";
      };

      security.rtkit.enable = true;

      zramSwap.enable = true;

      programs.zsh.enable = true;
      programs.dconf.enable = true;

      fonts.packages = [ pkgs.nerd-fonts.hack ];

      environment = {
        shells = [ pkgs.zsh ];

        sessionVariables = {
          NIXOS_OZONE_WL = "1";
          MOZ_ENABLE_WAYLAND = "1";
          EDITOR = "nvim";
          BROWSER = "helium";
        };

        systemPackages = with pkgs; [
          curl
          dconf-editor
          file
          git
          gnome-tweaks
          htop
          lsof
          nano
          pciutils
          unzip
          usbutils
          vim
          wget
          zip
        ];
      };

      services.openssh.enable = false;
      system.autoUpgrade.enable = false;

      assertions = [
        {
          assertion = config.networking.firewall.enable;
          message = "t14 must keep the NixOS firewall enabled; no proxy or service may open a public port.";
        }
        {
          assertion = !config.services.openssh.enable;
          message = "t14 must not enable an SSH daemon by default; use Tailscale or an explicit approval.";
        }
        {
          assertion = !config.services.power-profiles-daemon.enable;
          message = "Use TLP on this ThinkPad; power-profiles-daemon conflicts with it.";
        }
        {
          assertion = config.services.tlp.enable;
          message = "Keep TLP enabled for the ThinkPad power profile.";
        }
        {
          assertion = config.boot.loader.systemd-boot.enable;
          message = "t14 boots via systemd-boot; keep the rollback menu available.";
        }
      ];
    };
}
