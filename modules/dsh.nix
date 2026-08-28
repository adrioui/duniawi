{
  inputs,
  ...
}:
{
  den.aspects.adrifadilah.homeManager =
    { pkgs, ... }:
    {
      # Import the dsh-nix module for declarative profile management.
      imports = [ inputs.dsh-nix.homeManagerModules.dsh ];

      # Config files that the module does not own: settings, model cache,
      # skills, agent presets.  These are version-controlled symlinks.
      home.file = {
        ".dsh/settings.yaml".source = ../dsh/settings.yaml;
        ".dsh/commandcode-models.json".source = ../dsh/commandcode-models.json;
        ".dsh/skills".source = ../dsh/skills;
        ".dsh/.agent-presets".source = ../dsh/agent-presets;
      };

      programs.dsh = {
        enable = true;

        # Use the local dsh package build (with the HMR fix).
        package = pkgs.callPackage ../pkgs/dsh.nix { };

        profiles = {
          # web profile: in-box bundles + vendored computer-use plugin.
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
