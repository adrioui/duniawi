{
  den.aspects.media = {
    darwin =
      { pkgs, ... }:
      {
        environment.systemPackages = [
          pkgs.qbittorrent
          pkgs.ffmpeg
        ];
      };

    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.yt-dlp ];
      };
  };
}
