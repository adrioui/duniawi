{
  den.aspects.media = {
    darwin =
      { pkgs, ... }:
      {
        environment.systemPackages = [
          pkgs.qbittorrent
          pkgs.ffmpeg
        ];
        homebrew.casks = [ "obs" ];
      };

    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.yt-dlp ];
      };
  };
}
