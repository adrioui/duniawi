{
  flake = {
    modules = {
      darwin = {
        legacy = import ../hosts/adri;
        homebrew = import ../homebrew.nix;
      };
      homeManager = {
        legacy = import ../home/adrifadilah;
      };
    };
  };
}
