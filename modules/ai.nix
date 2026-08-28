{
  den.aspects.ai = {
    darwin =
      { pkgs, ... }:
      {
        environment.systemPackages = [
          pkgs.llm-agents.pi
          pkgs.llm-agents.opencode
          pkgs.herdr
        ];
      };

    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ (pkgs.callPackage ../pkgs/dsh.nix { }) ];
      };
  };
}
