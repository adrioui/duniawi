{
  den.aspects.media = {
    darwin =
      { pkgs, ... }:
      {
        environment.systemPackages = [
          pkgs.qbittorrent
          pkgs.ffmpeg
        ];

        # Realtime visuals tools ship official GUI builds; prefer them
        # over nixpkgs, same as OBS.
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
