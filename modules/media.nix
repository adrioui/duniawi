{
  flake.modules.darwin.media =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.qbittorrent pkgs.ffmpeg ];
      homebrew.casks = [ "obs" ];
    };

  flake.modules.homeManager.media =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.yt-dlp ];
    };
}
