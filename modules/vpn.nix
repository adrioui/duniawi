{
  den.aspects.vpn = {
    darwin =
      { pkgs, ... }:
      let
        # Keep launchd command wiring declarative instead of depending on the mutable
        # current-system profile path at runtime.
        netbirdService = pkgs.writeShellApplication {
          name = "netbird-service";
          text = ''
            /bin/wait4path /nix/store
            /bin/mkdir -p /var/run/netbird
            exec ${pkgs.lib.getExe pkgs.netbird} service run
          '';
        };
      in
      {
        environment.systemPackages = [ pkgs.netbird ];

        services.tailscale.enable = true;

        launchd.daemons.netbird = {
          serviceConfig = {
            Label = "io.netbird.client";
            ProgramArguments = [ (pkgs.lib.getExe netbirdService) ];
            RunAtLoad = true;
            KeepAlive = true;
            StandardOutPath = "/var/log/netbird/client.log";
            StandardErrorPath = "/var/log/netbird/client.error.log";
          };
        };

        homebrew.casks = [
          "protonvpn"
          "cloudflare-warp"
        ];
      };

    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.cloudflared ];
      };
  };
}
