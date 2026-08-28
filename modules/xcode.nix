{ config, ... }:
{
  flake.modules.darwin.xcode = {
    environment.systemPackages = [ config.flake.xcodebuildmcpPkg ];
  };
}
