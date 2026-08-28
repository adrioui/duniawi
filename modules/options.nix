{
  lib,
  flake-parts-lib,
  ...
}:
{
  options.flake = flake-parts-lib.mkSubmoduleOptions {
    darwinConfigurations = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
      default = { };
    };
    username = lib.mkOption {
      type = lib.types.str;
    };
    system = lib.mkOption {
      type = lib.types.str;
    };
    unfreePackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
    };
    xcodebuildmcpPkg = lib.mkOption {
      type = lib.types.package;
    };
  };
}
