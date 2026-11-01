{
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  den.aspects.homeMigration.nixos =
    { config, ... }:
    {
      systemd.tmpfiles.rules = [
        "d /var/home 0755 root root -"
        "L /var/home/adrifadilah - - - - /home/adrioui"
      ];

      assertions = [
        {
          assertion = config.users.users.adrioui.home == "/home/adrioui";
          message = ''
            The /var/home/adrifadilah compatibility link points at
            /home/adrioui. If the home moves, change the link in
            modules/home-migration.nix in the same commit.
          '';
        }
        {
          assertion = config.users.groups ? adrioui;
          message = ''
            Restored files keep numeric ownership 1000:1000. The group
            "adrioui" must exist with gid 1000, otherwise every restored file
            is reported by find -nogroup and new files get a different gid.
          '';
        }
      ];
    };
}
