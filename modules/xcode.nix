{
  inputs,
  ...
}:
{
  den.aspects.xcode.darwin =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        (pkgs.callPackage ../pkgs/xcodebuildmcp.nix { src = inputs.xcodebuildmcp; })
      ];
    };
}
