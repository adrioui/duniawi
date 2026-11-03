{
  den.aspects.browser.nixos = {
    programs.firefox.enable = true;
  };

  den.aspects.browser.darwin =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.helium ];
    };
}
