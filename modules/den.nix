{
  den,
  inputs,
  lib,
  ...
}:
{
  den = {
    hosts = {
      aarch64-darwin.adri.users.adrifadilah = { };

      x86_64-linux.t14 = {
        hostName = "nixos";
        users.adrioui = { };

        instantiate = inputs.nixpkgs-stable.lib.nixosSystem;
        home-manager.module = inputs.home-manager-stable.nixosModules.home-manager;
      };
    };

    schema.user.classes = lib.mkDefault [ "homeManager" ];

    default.includes = [
      den.batteries.define-user
      den.batteries.primary-user
      den.batteries.hostname
      (den.batteries.unfree [
        "amp-cli"
        "rave-isis-model"
        "rave-percussion-model"
        "rave-water-model"
        "slack"
        "vschaos2-ordinario-1024-model"
      ])
    ];
  };
}
