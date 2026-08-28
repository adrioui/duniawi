{
  inputs,
  lib,
  ...
}:
let
  
  
  pluginsLib = import ../dsh-nix-patch/plugins.nix { inherit lib; };
  profilesLib = import ../dsh-nix-patch/profiles.nix { inherit lib; };
  inBoxNames = [
    "@deepseek-ai/dsh-base"
    "@deepseek-ai/dsh-web-app"
    "@deepseek-ai/dsh-headless"
  ];
  dshHomeModule = import "${inputs.dsh-nix}/modules/home-manager/dsh.nix" {
    inherit pluginsLib profilesLib inBoxNames;
    dshSrc = null;
  };
in
{
  den.aspects.adrifadilah.homeManager =
    { pkgs, ... }:
    {
      
      imports = [ dshHomeModule ];

      
      
      home.file = {
        ".dsh/settings.yaml".source = ../dsh/settings.yaml;
        ".dsh/commandcode-models.json".source = ../dsh/commandcode-models.json;
        ".dsh/skills".source = ../dsh/skills;
        ".dsh/.agent-presets".source = ../dsh/agent-presets;
      };

      programs.dsh = {
        enable = true;

        
        package = pkgs.callPackage ../pkgs/dsh.nix { };

        profiles = {
          
          web = {
            plugins = [
              "@deepseek-ai/dsh-base"
              "@deepseek-ai/dsh-web-app"
              ../dsh/plugins/dsh-computer-use
            ];
          };

          
          tui = {
            plugins = [
              "@deepseek-ai/dsh-base"
              "@deepseek-harness-tui/dsh-tui"
              "@deepseek-ai/dsh-llm-retry"
              "dsh-client-auto-continue"
              "dsh-context"
              "dsh-free-search"
              "dsh-gateway-provider"
              "@mars-sea/dsh-commandcode-provider"
              ../dsh/plugins/dsh-herdr
              ../dsh/plugins/dsh-mode-boost
              ../dsh/plugins/dsh-model-autodiscover
              ../dsh/plugins/dsh-tui-mermaid
              ../dsh/plugins/dsh-super-injector
              ../dsh/plugins/dsh-pstack
              ../dsh/plugins/dsh-computer-use
            ];
            
            userPatchesFile = ../dsh/profiles/tui/cordis.patch.yml;
          };
        };
      };
    };
}
