_:

{
  home.file.".config/proxychains/proxychains.conf".source = ./proxychains.conf;

  programs.zsh.shellAliases = {
    pc = "proxychains4";
    pct = "proxychains4 -f ~/.config/proxychains/proxychains.conf";
    pc-test = "proxychains4 curl -s https://check.torproject.org/api/ip";
    pc-ip = "proxychains4 curl -s https://api.ipify.org";
  };
}
