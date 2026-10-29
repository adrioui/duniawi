{
  description = "adri nix-darwin setup";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    darwin.url = "github:nix-darwin/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    llm-agents.url = "github:numtide/llm-agents.nix";

    xcodebuildmcp = {
      url = "github:getsentry/XcodeBuildMCP/e6ef59b49b44012c824f0a0de261c96142e37390";
      flake = false;
    };

    flake-parts.url = "github:hercules-ci/flake-parts";

    import-tree.url = "github:vic/import-tree";

    den.url = "github:denful/den";

    helium = {
      url = "github:schembriaiden/helium-browser-nix-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
