{
  den.aspects.ampDeepseekNixos.homeManager =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.ampDeepseekNixos;
      proxy = pkgs.callPackage ../pkgs/amp-deepseek { };
    in
    {
      options.ampDeepseekNixos = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable the repository-owned amp-deepseek proxy.";
        };

        sopsFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = ''
            Encrypted sops file containing the upstream and inbound keys.
            Leave null until the host age key and real credentials are
            provisioned. The service then starts without credentials and
            reports HTTP 503 on /health; it never falls back to plaintext.
          '';
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 4014;
          description = "Loopback port for the proxy.";
        };
      };

      config = lib.mkIf cfg.enable {
        home.packages = [ proxy ];

        
        
        sops = lib.mkIf (cfg.sopsFile != null) {
          secrets = {
            "amp-deepseek/upstream-key" = {
              inherit (cfg) sopsFile;
              mode = "0400";
            };
            "amp-deepseek/inbound-key" = {
              inherit (cfg) sopsFile;
              mode = "0400";
            };
          };

          templates."amp-deepseek.env" = {
            content = ''
              UPSTREAM_AUTH_KEY=${config.sops.placeholder."amp-deepseek/upstream-key"}
              INBOUND_AUTH_KEY=${config.sops.placeholder."amp-deepseek/inbound-key"}
            '';
            mode = "0400";
          };
        };

        systemd.user.services.amp-deepseek-proxy = {
          Unit = {
            Description = "Amp to DeepSeek Anthropic proxy";
            
            
            
            After = lib.optional (cfg.sopsFile != null) "sops-nix.service";
            Wants = lib.optional (cfg.sopsFile != null) "sops-nix.service";
          };

          Service = {
            ExecStart = "${proxy}/bin/amp-deepseek-proxy";

            Environment = [
              "HOST=127.0.0.1"
              "PORT=${toString cfg.port}"
              "UPSTREAM_HOST=api.deepseek.com"
              "UPSTREAM_PATH=/anthropic"
            ];

            
            
            
            EnvironmentFile =
              lib.optional (cfg.sopsFile != null)
                "-${config.sops.templates."amp-deepseek.env".path}";

            Restart = "on-failure";
            RestartSec = 5;

            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectSystem = "strict";
            ProtectHome = "read-only";
            RestrictAddressFamilies = [
              "AF_INET"
              "AF_INET6"
              "AF_UNIX"
            ];
          };

          Install.WantedBy = [ "default.target" ];
        };

        assertions = [
          {
            assertion = cfg.port == 4014;
            message = "amp-deepseek must stay on the documented loopback port 4014.";
          }
          {
            assertion = !(config.systemd.user.services ? amp-deepseek-tunnel);
            message = "Do not add a Cloudflare tunnel for amp-deepseek on NixOS by default.";
          }
        ];
      };
    };
}
