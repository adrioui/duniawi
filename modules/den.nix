{
  den,
  lib,
  ...
}:
{
  den = {
    hosts.aarch64-darwin.adri.users.adrifadilah = { };

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
        "vschaos2-ordinario-1024-model"
      ])
    ];
  };
}
