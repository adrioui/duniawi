{
  inputs,
  ...
}:
let

  common =
    { config, lib, ... }:
    {
      nix = {
        settings = {
          show-trace = true;
          log-lines = 50;
        };

        gc = {
          automatic = true;
          options = "--delete-older-than 14d";
        };

        optimise.automatic = true;
      };

      system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

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
              features =
                if builtins.isList config.nix.settings.experimental-features then
                  config.nix.settings.experimental-features
                else
                  lib.splitString " " config.nix.settings.experimental-features;
            in
            builtins.all (feature: builtins.elem feature features) [
              "nix-command"
              "flakes"
            ];
          message = "Keep modern flake workflows enabled: nix.settings.experimental-features must include nix-command and flakes.";
        }
        {
          assertion = config.system.configurationRevision != null;
          message = ''
            Build from a git checkout so the running system records its revision.
            t14: /var/lib/duniawi-src. Darwin: its own checkout.
          '';
        }
      ];
    };
in
{
  den.aspects.base = {
    darwin = _: {
      imports = [ common ];

      nix = {
        channel.enable = false;
        registry.nixpkgs.flake = inputs.nixpkgs;
        nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

        settings = {
          experimental-features = "nix-command flakes";

          extra-substituters = [ "https://ibis.cachix.org" ];
          extra-trusted-public-keys = [
            "ibis.cachix.org-1:tKNWCdKmBXJFK1JE/SnA41z7U7XPFOnB7Nw0vLKXaLA="
          ];

          trusted-users = [
            "root"
            "adrifadilah"
          ];
        };
      };

      system = {
        primaryUser = "adrifadilah";
        stateVersion = 6;
      };

      nixpkgs = {
        hostPlatform = "aarch64-darwin";
        overlays = [
          inputs.llm-agents.overlays.shared-nixpkgs
          inputs.helium.overlays.default
          (_final: prev: {
            helium = prev.helium.overrideAttrs (_old: {
              installPhase = ''
                runHook preInstall
                appSrc=$(find . -maxdepth 4 -name "Helium.app" -type d | head -n 1)
                if [ -z "$appSrc" ]; then
                  echo "Helium.app not found, contents:"
                  find . -maxdepth 3 -print
                  exit 1
                fi
                echo "Using Helium.app at $appSrc"
                mkdir -p $out/Applications
                cp -R "$appSrc" $out/Applications/Helium.app
                mkdir -p $out/bin
                makeWrapper $out/Applications/Helium.app/Contents/MacOS/Helium $out/bin/helium \
                  --add-flags "--disable-component-update" \
                  --add-flags "--simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT'" \
                  --add-flags "--check-for-update-interval=0" \
                  --add-flags "--disable-background-networking"
                runHook postInstall
              '';
            });
          })
        ];
      };
    };

    nixos =
      { lib, ... }:
      {
        imports = [ common ];

        nix = {
          channel.enable = false;
          registry.nixpkgs.flake = inputs.nixpkgs-stable;
          nixPath = [ "nixpkgs=${inputs.nixpkgs-stable}" ];

          settings = {
            experimental-features = [
              "nix-command"
              "flakes"
            ];

            extra-substituters = [ "https://cache.numtide.com" ];
            extra-trusted-public-keys = [
              "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
            ];

            trusted-users = [
              "root"
              "adrioui"
            ];
          };
        };

        system.stateVersion = "26.05";

        nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      };

    homeManager = { lib, ... }: {

      home.stateVersion = lib.mkDefault "23.11";
    };
  };
}
