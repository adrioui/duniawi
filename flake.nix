{
  description = "adri nix-darwin setup";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    
    
    
    nixpkgs-stable.url = "github:NixOS/nixpkgs/6f06d204d8f2d8761d9da78778745974a3216381";

    darwin.url = "github:nix-darwin/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    home-manager-stable.url = "github:nix-community/home-manager/24f2190587513b9c2f73db112a17844ae912d965";
    home-manager-stable.inputs.nixpkgs.follows = "nixpkgs-stable";

    nixos-hardware.url = "github:NixOS/nixos-hardware/04c6b94fa104bc23650983a4513aea196794d321";
    nixos-hardware.inputs.nixpkgs.follows = "nixpkgs-stable";

    sops-nix.url = "github:Mic92/sops-nix/60182817ee048ac94b4c68ea76d5ef2e8aac730d";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs-stable";

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
