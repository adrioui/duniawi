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

        # codex-router is installed from source (see ~/.local/share/codex-router).
        # Homebrew formula v0.6.0 is broken upstream (poetry-core build
        # failure under python@3.14), so do not declare it here until fixed.
        # Source installer needs Node 24 + uv/python + git (from dev aspect).
      };

    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ (pkgs.callPackage ../pkgs/dsh.nix { }) ];
      };
  };
}
