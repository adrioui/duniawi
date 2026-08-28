{
  inputs,
  ...
}:
{
  den.aspects.adrifadilah.homeManager =
    { pkgs, ... }:
    {
      
      imports = [ inputs.dsh-nix.homeManagerModules.dsh ];

      
      
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

        };
      };
    };
}
