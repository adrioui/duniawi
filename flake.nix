{
  description = "adri nix-darwin setup";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager }:
  let
    username = "adrifadilah";

    configuration = { pkgs, ... }: {
      
      
      environment.systemPackages = with pkgs; [ 
        
        neofetch 
        vim 
        opencode

        
        btop
        coreutils
        direnv
        gh
        go
        lazydocker
        neovim
        netbird
        nodejs
        podman
        rustup
      ];

      
      nix.settings.experimental-features = "nix-command flakes";

      users.users.${username} = {
        home = "/Users/${username}";
      };

      
      system.primaryUser = username;

      
      programs.zsh.enable = true;

      
      launchd.daemons.netbird = {
        serviceConfig = {
          Label = "io.netbird.client";
          ProgramArguments = [
            "/bin/sh"
            "-c"
            "/bin/wait4path /nix/store && /bin/mkdir -p /var/run/netbird && exec /run/current-system/sw/bin/netbird service run"
          ];
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = "/var/log/netbird/client.log";
          StandardErrorPath = "/var/log/netbird/client.error.log";
        };
      };

      
      system.configurationRevision = self.rev or self.dirtyRev or null;

      
      
      system.stateVersion = 6;

      
      nixpkgs.hostPlatform = "aarch64-darwin";
    };

    homeConfiguration = { pkgs, ... }: {
      home.stateVersion = "23.11";
      home.username = username;
      home.homeDirectory = "/Users/${username}";

      
      xdg.enable = true;

      
      
      
      xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
        "$schema" = "https://opencode.ai/config.json";
        plugin = [ "opencode-google-antigravity-auth" ];
        provider = {
          google = {
            npm = "@ai-sdk/google";
            models = {
              
              "gemini-3-pro-preview" = {
                id = "gemini-3-pro-preview";
                name = "Gemini 3 Pro Preview";
                release_date = "2025-11-18";
                reasoning = true;
                limit = { context = 1000000; output = 64000; };
                cost = { input = 2; output = 12; cache_read = 0.2; };
                modalities = {
                  input = [ "text" "image" "video" "audio" "pdf" ];
                  output = [ "text" ];
                };
              };
              "gemini-3-pro-high" = {
                id = "gemini-3-pro-preview";
                name = "Gemini 3 Pro Preview (High Thinking)";
                options.thinkingConfig = { thinkingLevel = "high"; includeThoughts = true; };
              };
              "gemini-3-pro-medium" = {
                id = "gemini-3-pro-preview";
                name = "Gemini 3 Pro Preview (Medium Thinking)";
                options.thinkingConfig = { thinkingLevel = "medium"; includeThoughts = true; };
              };
              "gemini-3-pro-low" = {
                id = "gemini-3-pro-preview";
                name = "Gemini 3 Pro Preview (Low Thinking)";
                options.thinkingConfig = { thinkingLevel = "low"; includeThoughts = true; };
              };

              
              "gemini-3-flash" = {
                id = "gemini-3-flash";
                name = "Gemini 3 Flash";
                release_date = "2025-12-17";
                reasoning = true;
                limit = { context = 1048576; output = 65536; };
                cost = { input = 0.5; output = 3; cache_read = 0.05; };
                modalities = {
                  input = [ "text" "image" "video" "audio" "pdf" ];
                  output = [ "text" ];
                };
              };
              "gemini-3-flash-high" = {
                id = "gemini-3-flash";
                name = "Gemini 3 Flash (High Thinking)";
                options.thinkingConfig = { thinkingLevel = "high"; includeThoughts = true; };
              };
              "gemini-3-flash-medium" = {
                id = "gemini-3-flash";
                name = "Gemini 3 Flash (Medium Thinking)";
                options.thinkingConfig = { thinkingLevel = "medium"; includeThoughts = true; };
              };
              "gemini-3-flash-low" = {
                id = "gemini-3-flash";
                name = "Gemini 3 Flash (Low Thinking)";
                options.thinkingConfig = { thinkingLevel = "low"; includeThoughts = true; };
              };

              
              "gemini-2.5-flash" = {
                id = "gemini-2.5-flash";
                name = "Gemini 2.5 Flash";
                release_date = "2025-03-20";
                reasoning = true;
                limit = { context = 1048576; output = 65536; };
                cost = { input = 0.3; output = 2.5; cache_read = 0.075; };
                modalities = {
                  input = [ "text" "image" "audio" "video" "pdf" ];
                  output = [ "text" ];
                };
              };
              "gemini-2.5-flash-lite" = {
                id = "gemini-2.5-flash-lite";
                name = "Gemini 2.5 Flash Lite";
                release_date = "2025-06-17";
                reasoning = true;
                limit = { context = 1048576; output = 65536; };
                cost = { input = 0.1; output = 0.4; cache_read = 0.025; };
                modalities = {
                  input = [ "text" "image" "audio" "video" "pdf" ];
                  output = [ "text" ];
                };
              };

              
              "gemini-claude-sonnet-4-5-thinking-high" = {
                id = "gemini-claude-sonnet-4-5-thinking";
                name = "Claude Sonnet 4.5 (High Thinking)";
                release_date = "2025-11-18";
                reasoning = true;
                limit = { context = 200000; output = 64000; };
                cost = { input = 3; output = 15; cache_read = 0.3; };
                modalities = {
                  input = [ "text" "image" "pdf" ];
                  output = [ "text" ];
                };
                options.thinkingConfig = { thinkingBudget = 32000; includeThoughts = true; };
              };
              "gemini-claude-sonnet-4-5-thinking-medium" = {
                id = "gemini-claude-sonnet-4-5-thinking";
                name = "Claude Sonnet 4.5 (Medium Thinking)";
                release_date = "2025-11-18";
                reasoning = true;
                limit = { context = 200000; output = 64000; };
                cost = { input = 3; output = 15; cache_read = 0.3; };
                modalities = {
                  input = [ "text" "image" "pdf" ];
                  output = [ "text" ];
                };
                options.thinkingConfig = { thinkingBudget = 16000; includeThoughts = true; };
              };
              "gemini-claude-sonnet-4-5-thinking-low" = {
                id = "gemini-claude-sonnet-4-5-thinking";
                name = "Claude Sonnet 4.5 (Low Thinking)";
                release_date = "2025-11-18";
                reasoning = true;
                limit = { context = 200000; output = 64000; };
                cost = { input = 3; output = 15; cache_read = 0.3; };
                modalities = {
                  input = [ "text" "image" "pdf" ];
                  output = [ "text" ];
                };
                options.thinkingConfig = { thinkingBudget = 4000; includeThoughts = true; };
              };

              
              "gemini-claude-opus-4-5-thinking-high" = {
                id = "gemini-claude-opus-4-5-thinking";
                name = "Claude Opus 4.5 (High Thinking)";
                release_date = "2025-11-24";
                reasoning = true;
                limit = { context = 200000; output = 64000; };
                cost = { input = 5; output = 25; cache_read = 0.5; };
                modalities = {
                  input = [ "text" "image" "pdf" ];
                  output = [ "text" ];
                };
                options.thinkingConfig = { thinkingBudget = 32000; includeThoughts = true; };
              };
              "gemini-claude-opus-4-5-thinking-medium" = {
                id = "gemini-claude-opus-4-5-thinking";
                name = "Claude Opus 4.5 (Medium Thinking)";
                release_date = "2025-11-24";
                reasoning = true;
                limit = { context = 200000; output = 64000; };
                cost = { input = 5; output = 25; cache_read = 0.5; };
                modalities = {
                  input = [ "text" "image" "pdf" ];
                  output = [ "text" ];
                };
                options.thinkingConfig = { thinkingBudget = 16000; includeThoughts = true; };
              };
              "gemini-claude-opus-4-5-thinking-low" = {
                id = "gemini-claude-opus-4-5-thinking";
                name = "Claude Opus 4.5 (Low Thinking)";
                release_date = "2025-11-24";
                reasoning = true;
                limit = { context = 200000; output = 64000; };
                cost = { input = 5; output = 25; cache_read = 0.5; };
                modalities = {
                  input = [ "text" "image" "pdf" ];
                  output = [ "text" ];
                };
                options.thinkingConfig = { thinkingBudget = 4000; includeThoughts = true; };
              };
            };
          };
        };
      };
    };
  in
  {
    
    
    darwinConfigurations."adri" = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      pkgs = import nixpkgs {
        system = "aarch64-darwin";
      };

      modules = [ 
        configuration 
        ./homebrew.nix
        home-manager.darwinModules.home-manager {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.users.${username} = homeConfiguration;
       }
      ];
    };
  };
}
