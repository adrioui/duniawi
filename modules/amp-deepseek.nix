_: {
  den.aspects.ampDeepseek.homeManager =
    { config, pkgs, ... }:
    let
      proxy = pkgs.callPackage ../pkgs/amp-deepseek { };

      proxyService = pkgs.writeShellApplication {
        name = "amp-deepseek-proxy-service";
        text = ''
          upstream_key="$(/usr/bin/security find-generic-password -s deepseek-api-key -w 2>/dev/null || true)"
          inbound_key="$(/usr/bin/security find-generic-password -s amp-deepseek-inbound-key -w 2>/dev/null || true)"
          if [ -z "$upstream_key" ]; then
            echo "missing Keychain item deepseek-api-key" >&2
            exit 1
          fi
          if [ -z "$inbound_key" ]; then
            echo "missing Keychain item amp-deepseek-inbound-key" >&2
            exit 1
          fi
          export UPSTREAM_AUTH_KEY="$upstream_key"
          export INBOUND_AUTH_KEY="$inbound_key"
          exec ${proxy}/bin/amp-deepseek-proxy
        '';
      };

      tunnelService = pkgs.writeShellApplication {
        name = "amp-deepseek-tunnel-service";
        runtimeInputs = [ pkgs.cloudflared ];
        text = ''
          token="$(/usr/bin/security find-generic-password -s amp-deepseek-tunnel-token -w 2>/dev/null || true)"
          if [ -z "$token" ]; then
            echo "missing Keychain item amp-deepseek-tunnel-token" >&2
            exit 1
          fi
          export TUNNEL_TOKEN="$token"
          exec cloudflared tunnel --no-autoupdate run
        '';
      };
    in
    {
      home.packages = [
        proxy
        pkgs.cloudflared
      ];

      launchd.agents.amp-deepseek-proxy = {
        enable = true;
        config = {
          ProgramArguments = [ "${proxyService}/bin/amp-deepseek-proxy-service" ];
          RunAtLoad = true;
          KeepAlive = true;
          ThrottleInterval = 30;
          WorkingDirectory = config.home.homeDirectory;
          StandardOutPath = "${config.home.homeDirectory}/Library/Logs/amp-deepseek-proxy.log";
          StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/amp-deepseek-proxy.error.log";
        };
      };

      launchd.agents.amp-deepseek-tunnel = {
        enable = true;
        config = {
          ProgramArguments = [ "${tunnelService}/bin/amp-deepseek-tunnel-service" ];
          RunAtLoad = true;
          KeepAlive = true;
          ThrottleInterval = 30;
          WorkingDirectory = config.home.homeDirectory;
          StandardOutPath = "${config.home.homeDirectory}/Library/Logs/amp-deepseek-tunnel.log";
          StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/amp-deepseek-tunnel.error.log";
        };
      };
    };
}
