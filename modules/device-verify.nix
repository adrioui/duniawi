_: {
  den.aspects.deviceVerify.nixos =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.duniawi.deviceVerify;
      gate = pkgs.callPackage ../pkgs/device-verify.nix {
        inherit (cfg) rescueIsoSha256;
      };
    in
    {
      options.duniawi.deviceVerify = {
        enable = lib.mkEnableOption "the t14 device acceptance gate";

        package = lib.mkOption {
          type = lib.types.package;
          default = gate;
          description = "Package that provides the device-verify command.";
        };

        rescueIsoSha256 = lib.mkOption {
          type = lib.types.str;
          default = "94c957e84187d6818f4d20b88a086d7f7017e7dd640a91f44575d35d22c8de15";
          description = "Allowed rescue ISO sha256 for the rescue-media attestation.";
        };
      };

      config = lib.mkIf cfg.enable {

        environment.systemPackages = [ cfg.package ];

        environment.etc."duniawi/device-verify.sh".source = lib.getExe cfg.package;

        systemd.tmpfiles.rules = [
          "d /var/lib/duniawi 0750 root root -"
          "d /var/lib/duniawi/evidence 0750 root root -"
        ];
      };
    };
}
