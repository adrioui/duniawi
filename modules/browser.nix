{
  den.aspects.browser.darwin =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.helium ];
    };
}
