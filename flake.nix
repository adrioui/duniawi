{
  description = "adri nix-darwin setup";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    llm-agents.url = "github:numtide/llm-agents.nix";

    # Pin to a known-good upstream commit (v2.7.0). Bump intentionally:
    # refresh the source and the npmDeps hash in pkgs/xcodebuildmcp.nix.
    xcodebuildmcp = {
      url = "github:getsentry/XcodeBuildMCP/e6ef59b49b44012c824f0a0de261c96142e37390";
      flake = false;
    };

    flake-parts.url = "github:hercules-ci/flake-parts";

    import-tree.url = "github:vic/import-tree";
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
