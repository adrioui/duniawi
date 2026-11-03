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

      time.timeZone = "Asia/Jakarta";

      hardware.graphics.enable = true;

      services = {
        displayManager.gdm.enable = true;
        desktopManager.gnome.enable = true;

        printing.enable = true;
        avahi.nssmdns4 = true;

        pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
        };

        fwupd.enable = true;
        power-profiles-daemon.enable = false;

        journald.extraConfig = "SystemMaxUse=1G";
      };

      zramSwap.enable = true;

      programs.zsh.enable = true;

      fonts.packages = [ pkgs.nerd-fonts.hack ];

      environment = {
        sessionVariables = {
          NIXOS_OZONE_WL = "1";
          MOZ_ENABLE_WAYLAND = "1";
        };

        systemPackages = with pkgs; [
          dconf-editor
          file
          git
          gnome-tweaks
          htop
          lsof
          pciutils
          unzip
          usbutils
          vim
          wget
          zip
          (pkgs.callPackage ../pkgs/herdr-core.nix { })
        ];
      };

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
          assertion = config.services.tlp.enable;
          message = "Keep TLP enabled for the ThinkPad power profile.";
        }
      ];
    };
}
