{
  den,
  lib,
  ...
}:
{
  den = {
    hosts.aarch64-darwin.adri.users.adrifadilah = { };

    # Enable home-manager for all users by default.
    schema.user.classes = lib.mkDefault [ "homeManager" ];

    # Batteries that apply everywhere.
    default.includes = [
      den.batteries.define-user
      den.batteries.primary-user
      den.batteries.hostname
      (den.batteries.unfree [
        "amp"
        "rave-isis-model"
        "rave-percussion-model"
        "vschaos2-ordinario-1024-model"
      ])
    ];
  };
}
