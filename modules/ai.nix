{
  den.aspects.ai = {
    darwin =
      { pkgs, ... }:
      {
        environment.systemPackages = [
          pkgs.amp-cli
          pkgs.llm-agents.pi
          pkgs.llm-agents.opencode
          pkgs.llm-agents.cursor-agent
          pkgs.llm-agents.claude-code
          pkgs.herdr
        ];

      };

    homeManager = {
      home.packages = [ ];
    };
  };
}
