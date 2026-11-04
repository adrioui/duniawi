{
  config,
  inputs,
  ...
}:
let
  pkgs = inputs.nixpkgs-stable.legacyPackages.x86_64-linux;
in
{
  flake.checks.x86_64-linux.t14-vm = pkgs.testers.nixosTest {
    name = "t14-vm";

    nodes.machine =
      { lib, pkgs, ... }:
      {
        imports = [ config.den.hosts.x86_64-linux.t14.mainModule ];

        environment = {
          systemPackages = with pkgs; [
            acl
            attr
            rsync
            sqlite
          ];
          etc."migration-fixture.sh".source = ../tests/migration-fixture.sh;
        };

        nixpkgs.pkgs = lib.mkForce (
          import inputs.nixpkgs-stable {
            system = "x86_64-linux";
            config.allowUnfree = true;
          }
        );
        nixpkgs.config = lib.mkForce { };
        assertions = lib.mkForce [ ];

        boot.loader.systemd-boot.enable = lib.mkForce false;
        boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

        services = {
          xserver.enable = lib.mkForce false;
          displayManager.sddm.enable = lib.mkForce false;
          displayManager.gdm.enable = lib.mkForce false;
          desktopManager.plasma6.enable = lib.mkForce false;
          desktopManager.gnome.enable = lib.mkForce false;
          gnome = {
            core-apps.enable = lib.mkForce false;
            core-shell.enable = lib.mkForce false;
            games.enable = lib.mkForce false;
            sushi.enable = lib.mkForce false;
            gnome-keyring.enable = lib.mkForce false;
          };
          printing.enable = lib.mkForce false;
          avahi.enable = lib.mkForce false;
          tlp.enable = lib.mkForce false;
          fwupd.enable = lib.mkForce false;
          power-profiles-daemon.enable = lib.mkForce false;
          tailscale.enable = lib.mkForce false;
          getty.autologinUser = lib.mkForce "adrioui";
        };

        programs.dconf.enable = true;

        virtualisation = {
          podman.enable = lib.mkForce false;
          memorySize = 2048;
          cores = 2;
        };

        hardware = {
          bluetooth.enable = lib.mkForce false;
          enableRedistributableFirmware = lib.mkForce false;
          graphics.enable = lib.mkForce false;
        };

        zramSwap.enable = lib.mkForce false;

        users.users.adrioui = {
          initialPassword = lib.mkForce "test";
          linger = lib.mkForce true;
        };
      };

    testScript = ''
      machine.start(allow_reboot=True)
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-adrioui.service")
      machine.wait_for_unit("user@1000.service")

      machine.succeed("stat -c '%u:%g' /home/adrioui | grep -q '1000:1000'")
      machine.succeed("getent passwd adrioui | grep -q ':1000:1000:'")
      machine.succeed("getent group 1000 | grep -q adrioui")
      machine.succeed("! find /home/adrioui -xdev \\( -nouser -o -nogroup \\) -print | grep -q .")

      machine.succeed(
          "REQUIRE_ACL=1 REQUIRE_FULL_DISK=1 REQUIRE_ROOT=1 "
          "TMPDIR=/tmp bash /etc/migration-fixture.sh"
      )

      machine.succeed("systemctl --failed --no-legend | wc -l | grep -q '^0$'")

      machine.reboot()
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-adrioui.service")
      machine.wait_for_unit("user@1000.service")

      machine.crash()
      machine.start(allow_reboot=True)
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-adrioui.service")
      machine.wait_for_unit("user@1000.service")
      machine.succeed("systemctl --failed --no-legend | wc -l | grep -q '^0$'")
    '';
  };
}
