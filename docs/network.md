# Network and VPN

## Status

Network access is provided by Tailscale, Netbird, and optional commercial VPN clients. `cloudflared` is installed for outbound tunnel workflows.

## Components

`modules/vpn.nix` declares:

| Component | Role | Class |
|---|---|---|
| Tailscale | mesh VPN | `darwin` |
| Netbird | mesh VPN service | `darwin` |
| ProtonVPN | commercial VPN client | Homebrew cask |
| Cloudflare WARP | commercial VPN client | Homebrew cask |
| `cloudflared` | tunnel client | `homeManager` package |

The Amp DeepSeek tunnel is a separate feature documented in `docs/amp-deepseek.md`.

## Tailscale

```nix
services.tailscale.enable = true;
```

Tailscale is managed by nix-darwin. Authentication and tailnet policy are external to Nix; the machine must be signed in and authorized before it can reach the tailnet.

## Netbird

Netbird runs as a system launchd daemon:

```nix
launchd.daemons.netbird = {
  serviceConfig = {
    Label = "io.netbird.client";
    ProgramArguments = [ (pkgs.lib.getExe netbirdService) ];
    RunAtLoad = true;
    KeepAlive = true;
    StandardOutPath = "/var/log/netbird/client.log";
    StandardErrorPath = "/var/log/netbird/client.error.log";
  };
};
```

The wrapper waits for `/nix/store`, creates `/var/run/netbird`, then runs `netbird service run`.

## Cloudflared

`cloudflared` is in `home.packages`. It is used explicitly by tunnel features, not as a background service by default. The Amp DeepSeek tunnel is the only declared tunnel in this repository.

## Verification

```bash
tailscale status
netbird status
cloudflared --version
launchctl print system/io.netbird.client
```

`launchctl print` may require `sudo`.

## Security

* No VPN credentials or enrollment keys are stored in this repository.
* Tailscale and Netbird authentication is external.
* Homebrew VPN clients may auto-update; that is accepted for GUI clients.
* `cloudflared` tokens must come from Keychain at runtime, never from Nix or a plist.

## Troubleshooting

| Symptom | Check |
|---|---|
| Tailscale not connected | `tailscale status`; sign in or approve the machine |
| Netbird not running | `launchctl print system/io.netbird.client` and `/var/log/netbird/client.error.log` |
| Netbird cannot create runtime dir | confirm `/var/run/netbird` is created by the wrapper |
| `cloudflared` missing | `home.packages` must include `pkgs.cloudflared` |
| tunnel cannot resolve local service | check the tunnel ingress and the origin listener |
| DNS changes by a VPN break other services | inspect `scutil --dns` and the VPN split-tunnel settings |
