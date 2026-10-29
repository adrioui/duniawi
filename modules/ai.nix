{
  den.aspects.ai = {
    darwin =
      { pkgs, ... }:
      {
        environment.systemPackages = [
          pkgs.llm-agents.pi
          pkgs.llm-agents.opencode
          pkgs.llm-agents.cursor-agent
          pkgs.llm-agents.claude-code
          pkgs.herdr
        ];

        # cua-driver (computer-use) is installed imperatively via
        # https://cua.ai/driver/install.sh --no-modify-path: binary at
        # ~/.local/bin/cua-driver, app at /Applications/CuaDriver.app
        # (not brew-managed, so zap ignores it). Registered as a Codex
        # MCP server (`codex mcp add cua-driver -- .../.local/bin/cua-driver mcp`)
        # with skill pack linked at ~/.agents/skills/cua-driver.
        # Needs Accessibility + Screen Recording (cua-driver permissions grant).
        # Homebrew formula v0.6.0 is broken upstream (poetry-core build
        # failure under python@3.14), so do not declare it here until fixed.
        # Source installer needs Node 24 + uv/python + git (from dev aspect).
      };

    homeManager = {
      home.packages = [ ];
    };
  };
}
