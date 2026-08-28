{
  config,
  inputs,
  lib,
  username,
  self,
  ...
}:
{
  nix = {
    
    
    channel.enable = false;
    registry.nixpkgs.flake = inputs.nixpkgs;
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

    settings = {
      
      experimental-features = "nix-command flakes";

      
      
      
      show-trace = true;
      log-lines = 50;

      
      
      extra-substituters = [ "https://ibis.cachix.org" ];
      extra-trusted-public-keys = [
        "ibis.cachix.org-1:tKNWCdKmBXJFK1JE/SnA41z7U7XPFOnB7Nw0vLKXaLA="
      ];

      
      trusted-users = [
        "root"
        username
      ];
    };

    gc = {
      automatic = true;
      options = "--delete-older-than 14d";
    };

    
    
    optimise.automatic = true;
  };

  assertions = [
    {
      assertion = !config.nix.channel.enable;
      message = "Keep this repo flake-first: set nix.channel.enable = false.";
    }
    {
      assertion = config.nix.registry ? nixpkgs;
      message = "Keep a system nix.registry.nixpkgs entry so flake CLI commands resolve through the pinned nixpkgs input.";
    }
    {
      assertion =
        (config.nix.registry.nixpkgs.from.id or null) == "nixpkgs"
        && (config.nix.registry.nixpkgs.exact or false);
      message = "Keep nix.registry.nixpkgs as an exact system registry entry for the flake-first workflow.";
    }
    {
      assertion = builtins.elem "nixpkgs=${config.nix.registry.nixpkgs.flake}" config.nix.nixPath;
      message = "Keep nix.nixPath aligned with nix.registry.nixpkgs for legacy <nixpkgs> consumers.";
    }
    {
      assertion =
        let
          features = lib.splitString " " config.nix.settings.experimental-features;
        in
        builtins.all (feature: builtins.elem feature features) [
          "nix-command"
          "flakes"
        ];
      message = "Keep modern flake workflows enabled: nix.settings.experimental-features must include nix-command and flakes.";
    }
  ];

  users.users.${username} = {
    home = "/Users/${username}";
  };

  system = {
    
    primaryUser = username;

    
    configurationRevision = self.rev or self.dirtyRev or null;

    
    
    stateVersion = 6;
  };

  
  nixpkgs.hostPlatform = "aarch64-darwin";
}
