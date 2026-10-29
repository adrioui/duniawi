{
  den.aspects.media = {
    darwin =
      { pkgs, ... }:
      {
        environment.systemPackages = [
          pkgs.qbittorrent
          pkgs.ffmpeg
        ];

        homebrew.casks = [
          "obs"
          "touchdesigner"
        ];
      };

    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.yt-dlp ];
      };
  };
}
