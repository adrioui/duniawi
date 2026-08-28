{ username, ... }:
{
  home = {
    stateVersion = "23.11";
    inherit username;
    homeDirectory = "/Users/${username}";
  };
}
