{
  flake.modules.darwin.ai =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        pkgs.llm-agents.pi
        pkgs.llm-agents.opencode
        pkgs.herdr
      ];
    };

  flake.modules.homeManager.ai =
    { pkgs, ... }:
    {
      home.packages = [ (pkgs.callPackage ../pkgs/dsh.nix { }) ];
    };
}
