{
  den.aspects.browser.nixos =
    { config, ... }:
    {
      
      
      assertions = [
        {
          assertion = !config.programs.firefox.enable;
          message = "t14 uses Helium, not Firefox, as its browser.";
        }
      ];
    };

  den.aspects.browser.darwin =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.helium ];
    };
}
