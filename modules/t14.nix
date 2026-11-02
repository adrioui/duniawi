{
  den,
  inputs,
  ...
}:
{
  den.aspects = {
    t14 = {
      includes = [
        den.aspects.base
        den.aspects.nixosHardware
        den.aspects.nixosDesktop
        den.aspects.homeMigration
        den.aspects.vpn
        den.aspects.browser
        den.aspects.dev
        den.aspects.shell
        den.aspects.media
        den.aspects.deviceVerify
      ];

      nixos =
        { config, ... }:
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            
            
            backupFileExtension = "hm-backup";
            sharedModules = [ inputs.sops-nix.homeManagerModules.sops ];
          };

          duniawi.deviceVerify.enable = true;

          assertions = [
            {
              assertion = config.home-manager.useGlobalPkgs;
              message = "Use the host nixpkgs for Home Manager on t14.";
            }
            {
              assertion = config.home-manager.useUserPackages;
              message = "Install Home Manager packages through the NixOS user profile on t14.";
            }
            {
              assertion = config.system.stateVersion == "26.05";
              message = "t14 was installed on NixOS 26.05; do not change stateVersion during the migration.";
            }
            {
              assertion = config.nixpkgs.hostPlatform.system == "x86_64-linux";
              message = "t14 must evaluate for x86_64-linux.";
            }
            {
              assertion = config.networking.hostName == "nixos";
              message = "Keep the network hostname nixos during the migration.";
            }
            {
              assertion =
                !(config.home-manager.users.adrioui.ampDeepseekNixos.enable or false)
                || (config.home-manager.users.adrioui.systemd.user.services ? amp-deepseek-proxy);
              message = "ampDeepseekNixos must define the amp-deepseek-proxy user service.";
            }
          ];
        };
    };

    adrioui = {
      includes = [
        den.aspects.base
        den.aspects.ampDeepseekNixos
        den.aspects.shell
        den.aspects.media
        den.aspects.nixosUser
      ];

      
      
      
      nixos =
        { pkgs, ... }:
        {
          users.groups.adrioui.gid = 1000;

          users.users.adrioui = {
            uid = 1000;
            group = "adrioui";
            description = "Adri Fadilah";
            extraGroups = [
              "podman"
              "video"
              "render"
            ];
            shell = pkgs.zsh;
          };
        };
    };
  };
}
