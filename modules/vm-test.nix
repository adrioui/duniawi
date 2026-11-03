{
  config,
  inputs,
  ...
}:
let
  pkgs = inputs.nixpkgs-stable.legacyPackages.x86_64-linux;
  proxy = pkgs.callPackage ../pkgs/amp-deepseek { };
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

        home-manager.users.adrioui.systemd.user.services.amp-deepseek-proxy.Service.Environment =
          lib.mkForce
            [
              "HOST=127.0.0.1"
              "PORT=4014"
              "UPSTREAM_HOST=api.deepseek.com"
              "UPSTREAM_PATH=/anthropic"
              "UPSTREAM_AUTH_KEY=test-upstream"
              "INBOUND_AUTH_KEY=test-inbound"
            ];
      };

    testScript = ''
      machine.start(allow_reboot=True)
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-adrioui.service")
      machine.wait_for_unit("user@1000.service")
      machine.wait_for_open_port(4014)

      machine.succeed("stat -c '%u:%g' /home/adrioui | grep -q '1000:1000'")
      machine.succeed("getent passwd adrioui | grep -q ':1000:1000:'")
      machine.succeed("getent group 1000 | grep -q adrioui")
      machine.succeed("! find /home/adrioui -xdev \\( -nouser -o -nogroup \\) -print | grep -q .")

      machine.succeed(
          "REQUIRE_ACL=1 REQUIRE_FULL_DISK=1 REQUIRE_ROOT=1 "
          "TMPDIR=/tmp bash /etc/migration-fixture.sh"
      )

      machine.succeed("curl -fsS http://127.0.0.1:4014/health | grep -q '\"ok\":true'")
      machine.succeed("ss -ltnp | grep -q '127.0.0.1:4014'")
      machine.fail("ss -ltnp | grep -q '0.0.0.0:4014'")

      machine.succeed(
          "curl -s -o /dev/null -w '%{http_code}' "
          "-X POST http://127.0.0.1:4014/v1/messages "
          "-H 'x-api-key: wrong' -H 'content-type: application/json' -d '{}' "
          "| grep -q 401"
      )

      machine.succeed("su - adrioui -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user is-active amp-deepseek-proxy.service'")
      machine.succeed("su - adrioui -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user list-unit-files --state=enabled' | grep -q amp-deepseek-proxy")
      machine.fail("su - adrioui -c 'XDG_RUNTIME_DIR=/run/user/1000 systemctl --user list-unit-files --state=enabled' | grep -Eq 'commandcode|litellm|bifrost|cline|qoder|collie|dsh-web|sprint69|gpg-preset'")
      machine.succeed("systemctl --failed --no-legend | wc -l | grep -q '^0$'")
      machine.fail("journalctl --no-pager | grep -E 'test-upstream|test-inbound'")

      machine.succeed(
          "su - adrioui -c 'XDG_RUNTIME_DIR=/run/user/1000 "
          "systemctl --user show -p MainPID --value amp-deepseek-proxy.service' "
          "> /tmp/amp-deepseek-main.pid"
      )
      pid = machine.succeed("cat /tmp/amp-deepseek-main.pid").strip()
      machine.succeed(f"test '{pid}' -gt 1")
      machine.succeed(f"kill -9 '{pid}'")
      machine.wait_until_succeeds(
          "curl -fsS http://127.0.0.1:4014/health | grep -q '\"ok\":true'", timeout=60
      )
      machine.succeed(
          "su - adrioui -c 'XDG_RUNTIME_DIR=/run/user/1000 "
          "systemctl --user is-active amp-deepseek-proxy.service' | grep -q active"
      )
      machine.succeed("systemctl --failed --no-legend | wc -l | grep -q '^0$'")
      machine.succeed(
          "su - adrioui -c 'XDG_RUNTIME_DIR=/run/user/1000 "
          "systemctl --user --failed --no-legend' | wc -l | grep -q '^0$'"
      )

      machine.succeed(
          "su - adrioui -c 'XDG_RUNTIME_DIR=/run/user/1000 "
          "HOST=127.0.0.1 PORT=4015 UPSTREAM_AUTH_KEY= INBOUND_AUTH_KEY= "
          "${proxy}/bin/amp-deepseek-proxy >/tmp/amp-deepseek-nosecrets.log 2>&1 & echo $! >/tmp/amp-deepseek-nosecrets.pid'"
      )
      machine.wait_for_open_port(4015)
      machine.succeed("curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:4015/health | grep -q 503")
      machine.succeed("kill $(cat /tmp/amp-deepseek-nosecrets.pid)")

      machine.reboot()
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-adrioui.service")
      machine.wait_for_unit("user@1000.service")
      machine.wait_for_open_port(4014)
      machine.succeed("curl -fsS http://127.0.0.1:4014/health | grep -q '\"ok\":true'")

      machine.crash()
      machine.start(allow_reboot=True)
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-adrioui.service")
      machine.wait_for_unit("user@1000.service")
      machine.wait_for_open_port(4014)
      machine.succeed("curl -fsS http://127.0.0.1:4014/health | grep -q '\"ok\":true'")
      machine.succeed("systemctl --failed --no-legend | wc -l | grep -q '^0$'")
    '';
  };
}
