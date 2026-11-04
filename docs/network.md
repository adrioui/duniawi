# Network and VPN

## Status

Network access is provided by Tailscale, Netbird, and optional commercial VPN clients. The previous `cloudflared` tunnel and Amp DeepSeek proxy are removed.

## Components

`modules/vpn.nix` declares:

| Component | Role | Class |
|---|---|---|
| Tailscale | mesh VPN | `darwin` |
| Netbird | mesh VPN service | `darwin` |
| ProtonVPN | commercial VPN client | Homebrew cask |
| Cloudflare WARP | commercial VPN client | Homebrew cask |

The Amp DeepSeek tunnel and `cloudflared` package are removed.

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

## Cloudflared removed

`cloudflared` is no longer installed. The Amp DeepSeek tunnel and proxy were
removed with it; Amp now uses its configured provider directly.

## Verification

```bash
tailscale status
netbird status
launchctl print system/io.netbird.client
```

`launchctl print` may require `sudo`.

## Security

* No VPN credentials or enrollment keys are stored in this repository.
* Tailscale and Netbird authentication is external.
* Homebrew VPN clients may auto-update; that is accepted for GUI clients.

## Troubleshooting

| Symptom | Check |
|---|---|
| Tailscale not connected | `tailscale status`; sign in or approve the machine |
| Netbird not running | `launchctl print system/io.netbird.client` and `/var/log/netbird/client.error.log` |
| Netbird cannot create runtime dir | confirm `/var/run/netbird` is created by the wrapper |
| DNS changes by a VPN break other services | inspect `scutil --dns` and the VPN split-tunnel settings |
