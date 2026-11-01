






{
  name = "migration-rehearsal";

  nodes.machine =
    { pkgs, ... }:
    {
      
      
      users.groups.adrioui.gid = 1000;
      users.users.adrioui = {
        isNormalUser = true;
        uid = 1000;
        group = "adrioui";
        extraGroups = [ "wheel" ];
      };

      
      systemd.tmpfiles.rules = [
        "d /var/home 0755 root root -"
        "L /var/home/adrifadilah - - - - /home/adrioui"
      ];

      environment = {
        systemPackages = with pkgs; [
          rsync
          git
          sqlite
          acl
          attr
          libcap
          python3
          gawk
          findutils
        ];

        
        etc = {
          "restore-home.sh".source = ../scripts/restore-home.sh;
          "verify-home.sh".source = ../scripts/verify-home.sh;
          "rsync-filter.rules".source = ../scripts/rsync-filter.rules;
        };
      };

      virtualisation = {
        memorySize = 2048;
        cores = 4;
        diskSize = 8192;
      };
    };

  testScript = builtins.readFile ./migration-rehearsal.py;
}
